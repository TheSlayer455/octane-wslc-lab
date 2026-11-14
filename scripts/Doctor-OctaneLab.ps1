[CmdletBinding()]
param(
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Wslc',
    [string]$WslDistro,
    [ValidateRange(1024,65535)][int]$Port = 3001,
    [switch]$Deep,
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Runtime.ps1')

$started = [DateTime]::UtcNow
$checks = [Collections.Generic.List[object]]::new()
function Add-Check([string]$Name,[string]$Status,[string]$Detail,[Nullable[int64]]$DurationMs=$null) {
    $entry = [ordered]@{name=$Name;status=$Status;detail=$Detail}
    if ($null -ne $DurationMs) { $entry.durationMs = [int64]$DurationMs }
    $checks.Add([pscustomobject]$entry)
}
function Invoke-Check([string]$Name,[scriptblock]$Action) {
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $detail = & $Action
        $watch.Stop()
        Add-Check $Name 'PASS' (($detail | Out-String).Trim()) $watch.ElapsedMilliseconds
        return $true
    } catch {
        Add-Check $Name 'FAIL' $_.Exception.Message
        return $false
    }
}

$runtimeVersion = $null
$runtimeContext = if ($Engine -eq 'Wslc') { 'wslc:windows' } elseif ($IsWindows) { "docker:wsl:$WslDistro" } else { 'docker:local' }
$probeContainer = $null
$probeFile = Join-Path ([IO.Path]::GetTempPath()) ('octane-doctor-'+[Guid]::NewGuid().ToString('N')+'.txt')

try {
    if ($PSVersionTable.PSVersion.Major -ge 7) { Add-Check 'powershell' 'PASS' $PSVersionTable.PSVersion.ToString() } else { Add-Check 'powershell' 'FAIL' 'PowerShell 7 or later is required.' }

    $serverOk = Invoke-Check 'runtimeServer' {
        if ($Engine -eq 'Wslc') {
            $result = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('version') -TimeoutSeconds 30
            $script:runtimeVersion = $result.StdOut.Trim()
            $health = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','ls','-a') -TimeoutSeconds 60
            return "$($script:runtimeVersion); utility session responsive in $($health.DurationMs) ms"
        }
        $versionResult = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('version','--format','{{json .}}') -TimeoutSeconds 30
        $version = $versionResult.StdOut | ConvertFrom-Json
        $script:runtimeVersion = $version.Server.Version
        return "Docker client $($version.Client.Version); server $($version.Server.Version)"
    }

    if ($serverOk) {
        Invoke-Check 'runtimeContext' {
            if ($Engine -eq 'Wslc') { return 'WSLC Windows utility VM' }
            $context = (Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('context','show') -TimeoutSeconds 30).StdOut.Trim()
            $info = (Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('info','--format','{{json .}}') -TimeoutSeconds 30).StdOut | ConvertFrom-Json
            if ($info.OSType -ne 'linux') { throw "Expected Linux containers; server reported $($info.OSType)." }
            if ($info.Architecture -notin @('x86_64','amd64')) { throw "Expected amd64; server reported $($info.Architecture)." }
            $rootless = @($info.SecurityOptions) -contains 'name=rootless'
            $script:runtimeContext = "docker:wsl:${WslDistro}:$context"
            return "context=$context; os=$($info.OperatingSystem); arch=$($info.Architecture); rootless=$rootless; storage=$($info.Driver); memory=$([math]::Round($info.MemTotal/1GB,1)) GiB"
        } | Out-Null
    } else {
        Add-Check 'runtimeContext' 'BLOCKED' 'Runtime server check failed.'
    }

    if (Test-OctanePortAvailable -Port $Port) { Add-Check 'hostPort' 'PASS' "127.0.0.1:$Port is available." } else { Add-Check 'hostPort' 'FAIL' "127.0.0.1:$Port is already in use." }

    if ($Deep -and $serverOk) {
        $probeContainer = 'octane-doctor-' + [Guid]::NewGuid().ToString('N').Substring(0,10)
        $deepOk = Invoke-Check 'runCopyCleanup' {
            $run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('run','-d','--name',$probeContainer,'--label','com.octanelab.doctor=true','alpine:3.22','sh','-c','printf octane-doctor >/tmp/octane-probe.txt; sleep 120') -TimeoutSeconds 180
            $runtimeFile = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $probeFile
            Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',"${probeContainer}:/tmp/octane-probe.txt",$runtimeFile) -TimeoutSeconds 60 | Out-Null
            if ((Get-Content -LiteralPath $probeFile -Raw) -ne 'octane-doctor') { throw 'Copy-out probe contents did not match.' }
            return "container run and copy-out passed in $($run.DurationMs) ms"
        }
        if (-not $deepOk) { }
    } elseif ($Deep) {
        Add-Check 'runCopyCleanup' 'BLOCKED' 'Runtime server check failed.'
    } else {
        Add-Check 'runCopyCleanup' 'NOT_RUN' 'Use -Deep to verify run, copy-out, and managed cleanup.'
    }
} finally {
    if ($probeContainer) {
        $remove = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('rm','-f','-v',$probeContainer) -TimeoutSeconds 60 -AllowFailure
        if ($remove.ExitCode -ne 0) { Add-Check 'doctorCleanup' 'FAIL' $remove.StdErr.Trim() } else { Add-Check 'doctorCleanup' 'PASS' 'Doctor probe container and anonymous volumes removed.' $remove.DurationMs }
    }
    if (Test-Path -LiteralPath $probeFile) { Remove-Item -LiteralPath $probeFile -Force }
}

$failed = @($checks | Where-Object {$_.status -eq 'FAIL'}).Count
$record = [ordered]@{
    schemaVersion = 1
    engine = $Engine
    context = $runtimeContext
    wslDistro = if ($WslDistro) { $WslDistro } else { $null }
    runtimeVersion = $runtimeVersion
    startedAtUtc = $started.ToString('o')
    completedAtUtc = [DateTime]::UtcNow.ToString('o')
    status = if ($failed -eq 0) { 'PASS' } else { 'FAIL' }
    checks = $checks
}
$json = $record | ConvertTo-Json -Depth 10
if ($OutputPath) {
    $parent = Split-Path $OutputPath -Parent
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $json | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
$json
if ($failed -ne 0) { throw "Octane doctor failed $failed check(s)." }
