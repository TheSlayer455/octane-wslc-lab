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
$hostFacts = [ordered]@{
    windowsVersion = $null
    wslVersion = $null
    wslDistribution = if ($WslDistro) { $WslDistro } else { $null }
    linuxRelease = $null
    linuxKernel = $null
    architecture = $null
    memoryGiB = $null
    dockerContext = $null
    dockerEndpoint = $null
    dockerServerName = $null
    dockerRootDirectory = $null
    dockerRootFreeGiB = $null
}
$probeContainer = $null
$probeFile = Join-Path ([IO.Path]::GetTempPath()) ('octane-doctor-'+[Guid]::NewGuid().ToString('N')+'.txt')

try {
    if ($PSVersionTable.PSVersion.Major -ge 7) { Add-Check 'powershell' 'PASS' $PSVersionTable.PSVersion.ToString() } else { Add-Check 'powershell' 'FAIL' 'PowerShell 7 or later is required.' }

    if ($IsWindows) {
        Invoke-Check 'windowsHost' {
            $script:hostFacts.windowsVersion = [Environment]::OSVersion.VersionString
            $wslVersionResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('--version') -TimeoutSeconds 30
            if ($wslVersionResult.TimedOut -or $wslVersionResult.ExitCode -ne 0) { throw 'wsl.exe --version failed.' }
            $script:hostFacts.wslVersion = ($wslVersionResult.StdOut -replace "`0", '').Trim()
            if (-not $script:hostFacts.wslVersion) { throw 'wsl.exe --version returned no version data.' }
            return "$($script:hostFacts.windowsVersion); $($script:hostFacts.wslVersion -replace "`r?`n", '; ')"
        } | Out-Null
    } else {
        Add-Check 'windowsHost' 'NOT_RUN' 'The controller is running on Linux; Windows/WSL host facts are not available here.'
    }

    if ($Engine -eq 'Docker') {
        Invoke-Check 'linuxHost' {
            if ($IsWindows) {
                if (-not $WslDistro) { throw 'Docker on Windows requires an explicit -WslDistro.' }
                $prefix = @('-d',$WslDistro,'--exec')
                $kernelResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @($prefix + @('uname','-r')) -TimeoutSeconds 30
                $archResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @($prefix + @('uname','-m')) -TimeoutSeconds 30
                $releaseResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @($prefix + @('sh','-c','. /etc/os-release; printf "%s" "$PRETTY_NAME"')) -TimeoutSeconds 30
                $memoryResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @($prefix + @('sh','-c','awk ''/MemTotal:/ {printf "%.2f", $2/1024/1024}'' /proc/meminfo')) -TimeoutSeconds 30
                foreach ($result in @($kernelResult,$archResult,$releaseResult,$memoryResult)) {
                    if ($result.TimedOut -or $result.ExitCode -ne 0) { throw 'Unable to read the selected WSL distribution facts.' }
                }
                $script:hostFacts.linuxKernel = $kernelResult.StdOut.Trim()
                $script:hostFacts.architecture = $archResult.StdOut.Trim()
                $script:hostFacts.linuxRelease = $releaseResult.StdOut.Trim()
                $script:hostFacts.memoryGiB = [double]::Parse($memoryResult.StdOut.Trim(), [Globalization.CultureInfo]::InvariantCulture)
                if ($script:hostFacts.linuxKernel -notmatch 'WSL2') { throw "Selected distribution does not report a WSL2 kernel: $($script:hostFacts.linuxKernel)" }
            } else {
                $script:hostFacts.linuxKernel = (& uname -r).Trim()
                $script:hostFacts.architecture = (& uname -m).Trim()
                $script:hostFacts.linuxRelease = (& sh -c '. /etc/os-release; printf "%s" "$PRETTY_NAME"').Trim()
                $memoryText = (& sh -c 'awk ''/MemTotal:/ {printf "%.2f", $2/1024/1024}'' /proc/meminfo').Trim()
                $script:hostFacts.memoryGiB = [double]::Parse($memoryText, [Globalization.CultureInfo]::InvariantCulture)
            }
            return "distro=$($script:hostFacts.wslDistribution); release=$($script:hostFacts.linuxRelease); kernel=$($script:hostFacts.linuxKernel); arch=$($script:hostFacts.architecture); memory=$($script:hostFacts.memoryGiB) GiB"
        } | Out-Null
    } else {
        Add-Check 'linuxHost' 'NOT_RUN' 'WSLC owns its utility VM; no Docker WSL distribution was selected.'
    }

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
            $contextInfo = (Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('context','inspect',$context) -TimeoutSeconds 30).StdOut | ConvertFrom-Json
            $info = (Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('info','--format','{{json .}}') -TimeoutSeconds 30).StdOut | ConvertFrom-Json
            if ($info.OSType -ne 'linux') { throw "Expected Linux containers; server reported $($info.OSType)." }
            if ($info.Architecture -notin @('x86_64','amd64')) { throw "Expected amd64; server reported $($info.Architecture)." }
            $endpoint = [string]@($contextInfo)[0].Endpoints.docker.Host
            if ($IsWindows -and $endpoint -notmatch '^unix://') { throw "Selected Docker context is not a local Linux socket: $endpoint" }
            if ([string]$info.OperatingSystem -match 'Docker Desktop' -or [string]$info.Name -match '^docker-desktop') {
                throw "The selected server appears to be Docker Desktop ($($info.Name); $($info.OperatingSystem)), not Docker Engine inside $WslDistro."
            }
            $rootless = @($info.SecurityOptions) -contains 'name=rootless'
            $script:runtimeContext = "docker:wsl:${WslDistro}:$context"
            $script:hostFacts.dockerContext = $context
            $script:hostFacts.dockerEndpoint = $endpoint
            $script:hostFacts.dockerServerName = [string]$info.Name
            $script:hostFacts.dockerRootDirectory = [string]$info.DockerRootDir
            if ($IsWindows -and $script:hostFacts.dockerRootDirectory) {
                $disk = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('-d',$WslDistro,'--exec','df','-Pk',$script:hostFacts.dockerRootDirectory) -TimeoutSeconds 30
                if ($disk.ExitCode -eq 0 -and -not $disk.TimedOut) {
                    $last = @($disk.StdOut.Trim() -split "`r?`n")[-1] -split '\s+'
                    if ($last.Count -ge 4) { $script:hostFacts.dockerRootFreeGiB = [math]::Round(([double]$last[3] * 1KB / 1GB),2) }
                }
            }
            return "context=$context; endpoint=$endpoint; server=$($info.Name); os=$($info.OperatingSystem); arch=$($info.Architecture); rootless=$rootless; storage=$($info.Driver); root=$($info.DockerRootDir); free=$($script:hostFacts.dockerRootFreeGiB) GiB; memory=$([math]::Round($info.MemTotal/1GB,1)) GiB"
        } | Out-Null

        Invoke-Check 'buildCapability' {
            if ($Engine -eq 'Wslc') { return 'WSLC build availability is exercised by the project image build.' }
            $buildx = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('buildx','version') -TimeoutSeconds 30
            return $buildx.StdOut.Trim()
        } | Out-Null
    } else {
        Add-Check 'runtimeContext' 'BLOCKED' 'Runtime server check failed.'
        Add-Check 'buildCapability' 'BLOCKED' 'Runtime server check failed.'
    }

    if (Test-OctanePortAvailable -Port $Port) { Add-Check 'hostPort' 'PASS' "127.0.0.1:$Port is available." } else { Add-Check 'hostPort' 'FAIL' "127.0.0.1:$Port is already in use." }

    if ($Deep -and $serverOk) {
        $probeContainer = 'octane-doctor-' + [Guid]::NewGuid().ToString('N').Substring(0,10)
        $deepOk = Invoke-Check 'runCopyCleanup' {
            $server = 'mkdir -p /www; printf octane-doctor >/tmp/octane-probe.txt; while true; do printf "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\noctane-doctor" | nc -l -p 8080; done'
            $run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('run','-d','--name',$probeContainer,'--label','com.octanelab.doctor=true','-p',"127.0.0.1:${Port}:8080",'alpine:3.22','sh','-c',$server) -TimeoutSeconds 180
            $runtimeFile = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $probeFile
            Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',"${probeContainer}:/tmp/octane-probe.txt",$runtimeFile) -TimeoutSeconds 60 | Out-Null
            if ((Get-Content -LiteralPath $probeFile -Raw) -ne 'octane-doctor') { throw 'Copy-out probe contents did not match.' }
            $endpointDeadline = [DateTime]::UtcNow.AddSeconds(30)
            $body = $null
            while ([DateTime]::UtcNow -lt $endpointDeadline) {
                try {
                    $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port" -TimeoutSec 3
                    $body = if ($response.Content -is [byte[]]) {
                        [Text.Encoding]::UTF8.GetString($response.Content)
                    } else {
                        [string]$response.Content
                    }
                    if ($body -eq 'octane-doctor') { break }
                } catch { Start-Sleep -Milliseconds 500 }
            }
            if ($body -ne 'octane-doctor') { throw 'Published loopback endpoint was not reachable from the controller host.' }
            return "container run, copy-out, and controller-to-loopback endpoint passed in $($run.DurationMs) ms"
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
    schemaVersion = 2
    engine = $Engine
    context = $runtimeContext
    wslDistro = if ($WslDistro) { $WslDistro } else { $null }
    runtimeVersion = $runtimeVersion
    host = $hostFacts
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
