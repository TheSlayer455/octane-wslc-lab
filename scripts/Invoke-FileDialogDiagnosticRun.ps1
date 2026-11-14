[CmdletBinding()]
param(
    [string]$WslDistro = 'Ubuntu-24.04',
    [ValidateSet('CleanPrefix','PostInstall')][string]$Phase = 'CleanPrefix',
    [ValidateSet('AppMatch','Modern','Legacy','Full')][string]$Suite = 'Full',
    [string[]]$Cases,
    [ValidateRange(1024,65535)][int]$Port = 3394,
    [ValidatePattern('^[A-Za-z0-9,+_-]+$')][string]$WineDebug,
    [switch]$KeepFailedContainer
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'RdpSession.ps1')

$container = $null
$metadataPath = $null
$dialogEvidence = $null
$rdp = $null
$succeeded = $false
try {
    $startOutput = @(& (Join-Path $PSScriptRoot 'Start-OctaneLab.ps1') -Engine Docker -WslDistro $WslDistro `
        -WineProfile DockerWineStaging1121VisRgn -Port $Port)
    $containerLine = @($startOutput | Where-Object { $_ -match '^Container: octane-[a-f0-9]{10}$' }) | Select-Object -First 1
    $passwordLine = @($startOutput | Where-Object { $_ -match '^Password: .+$' }) | Select-Object -First 1
    if (-not $containerLine -or -not $passwordLine) { throw 'Start-OctaneLab did not return the expected container identity and one-time credential.' }
    $container = ($containerLine -replace '^Container:\s*','').Trim()
    $password = ($passwordLine -replace '^Password:\s*','').Trim()
    $metadataPath = Join-Path $root "runs/$container.json"
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $rdp = Start-OctaneRdpClient -WslDistro $WslDistro -Port $Port -Username $metadata.desktopUsername -Password $password
    $password = $null

    $displayReady = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $probe = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @(
            'exec','-u','wineuser',$container,'bash','-lc',
            'for s in /tmp/.X11-unix/X*; do [ -S "$s" ] || continue; d=:${s##*X}; DISPLAY=$d XAUTHORITY=$HOME/.Xauthority xdpyinfo >/dev/null 2>&1 && exit 0; done; exit 1'
        ) -TimeoutSeconds 15 -AllowFailure
        if ($probe.ExitCode -eq 0) { $displayReady = $true; break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $displayReady) { throw 'The unattended RDP client did not create a usable Xorgxrdp display.' }

    $environment = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$container,'octane-lab','environment') -TimeoutSeconds 120
    if ($Phase -eq 'PostInstall') {
        $install = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$container,'octane-lab','install-silent') -TimeoutSeconds 300 -AllowFailure
        if ($install.ExitCode -ne 0 -or $install.TimedOut) {
            Update-OctaneRunStage -Path $metadataPath -Stage installer -Status FAIL -Detail "Silent installer exit=$($install.ExitCode); timeout=$($install.TimedOut)" -DurationMs $install.DurationMs
            throw 'Post-install dialog diagnostic could not complete NSIS installation.'
        }
        Update-OctaneRunStage -Path $metadataPath -Stage installer -Status PASS -Detail 'Fresh prefix; retained NSIS installer completed before standalone dialog diagnostics.' -DurationMs $install.DurationMs
    }

    $experimentId = "dialog-$($metadata.runId)-$($Phase.ToLowerInvariant())"
    $dialogArguments = @{
        Container=$container;Engine='Docker';WslDistro=$WslDistro;ExperimentId=$experimentId;Phase=$Phase;Suite=$Suite
    }
    if ($Cases) { $dialogArguments.Cases = $Cases }
    if ($WineDebug) { $dialogArguments.WineDebug = $WineDebug }
    & (Join-Path $PSScriptRoot 'Invoke-FileDialogExperiment.ps1') @dialogArguments
    $dialogEvidence = Join-Path $root "evidence/$($metadata.runId)/dialogs/$experimentId"
    Stop-OctaneRdpClient -Session $rdp -OutputDirectory (Join-Path $dialogEvidence 'logs/rdp-client')
    $rdp = $null
    Update-OctaneEvidenceChecksums -Directory $dialogEvidence
    & (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Container $container -Engine Docker -WslDistro $WslDistro | Out-Null
    $succeeded = $true
    Write-Output "Container: $container"
    Write-Output "Dialog evidence: $dialogEvidence"
} finally {
    if ($rdp) {
        $fallback = if ($dialogEvidence) { Join-Path $dialogEvidence 'logs/rdp-client' } else { $null }
        Stop-OctaneRdpClient -Session $rdp -OutputDirectory $fallback
    }
    if ($container -and ($succeeded -or -not $KeepFailedContainer)) {
        try { & (Join-Path $PSScriptRoot 'Stop-OctaneLab.ps1') -Container $container -Engine Docker -WslDistro $WslDistro -RemoveImage | Out-Null } catch { Write-Warning $_.Exception.Message }
    }
}
