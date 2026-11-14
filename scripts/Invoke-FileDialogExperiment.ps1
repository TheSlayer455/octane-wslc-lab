[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Docker',
    [string]$WslDistro,
    [ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$ExperimentId = ('dialog-'+[Guid]::NewGuid().ToString('N')),
    [ValidateSet('CleanPrefix','PostInstall')][string]$Phase = 'CleanPrefix',
    [ValidateSet('AppMatch','Modern','Legacy','Full')][string]$Suite = 'AppMatch',
    [string[]]$Cases,
    [ValidatePattern('^[A-Za-z0-9,+_-]+$')][string]$WineDebug
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')

Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro | Out-Null
$metadataPath = Join-Path $root "runs/$Container.json"
if (-not (Test-Path -LiteralPath $metadataPath)) { throw "Run metadata not found: $metadataPath" }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$profile = Get-OctaneWineProfile -WineProfile $metadata.wineProfile -BaseImage $metadata.baseImage
$phaseValue = if ($Phase -eq 'PostInstall') { 'post-install' } else { 'clean-prefix' }
$suiteValue = switch ($Suite) {
    'AppMatch' { 'app-match' }
    default { $Suite.ToLowerInvariant() }
}
$arguments = [Collections.Generic.List[string]]::new()
foreach ($argument in @('exec','-u',$profile.ExecUser,'-e',"OCTANE_DIALOG_EXPERIMENT_ID=$ExperimentId",'-e',"OCTANE_DIALOG_PHASE=$phaseValue",'-e',"OCTANE_DIALOG_SUITE=$suiteValue")) {
    $arguments.Add($argument)
}
if ($Cases) {
    foreach ($case in $Cases) {
        if ($case -notmatch '^[a-z0-9-]+$') { throw "Invalid dialog case: $case" }
    }
    foreach ($argument in @('-e',"OCTANE_DIALOG_CASES=$($Cases -join ',')")) { $arguments.Add($argument) }
}
if ($WineDebug) {
    foreach ($argument in @('-e',"OCTANE_DIALOG_WINEDEBUG=$WineDebug")) { $arguments.Add($argument) }
}
foreach ($argument in @($Container,'octane-file-dialog-experiment')) { $arguments.Add($argument) }
$run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $arguments.ToArray() -TimeoutSeconds 900 -AllowFailure

$localDirectory = Join-Path $root "evidence/$($metadata.runId)/dialogs/$ExperimentId"
New-Item -ItemType Directory -Path $localDirectory -Force | Out-Null
$runtimeDirectory = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $localDirectory
$source = "$Container`:$($profile.EvidenceDirectory)/dialogs/$ExperimentId/."
$copy = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',$source,$runtimeDirectory) -TimeoutSeconds 180 -AllowFailure
if ($copy.ExitCode -ne 0 -or $copy.TimedOut) { throw "Dialog experiment exited $($run.ExitCode), and evidence copy failed. $($copy.StdErr.Trim())" }

$suitePath = Join-Path $localDirectory 'dialog-suite.json'
if (-not (Test-Path -LiteralPath $suitePath)) { throw "Dialog experiment did not produce dialog-suite.json. Evidence: $localDirectory" }
$result = Get-Content -LiteralPath $suitePath -Raw | ConvertFrom-Json
$detail = "experiment=$ExperimentId; phase=$phaseValue; suite=$suiteValue; pass=$($result.counts.passed)/$($result.counts.planned); standalone probe only"
$status = if ($result.overallStatus -eq 'PASS' -and $run.ExitCode -eq 0 -and -not $run.TimedOut) { 'PASS' } else { 'FAIL' }
Update-OctaneRunStage -Path $metadataPath -Stage dialogDiagnostic -Status $status -Detail $detail -DurationMs $run.DurationMs
Set-OctaneRunMetadata -Path $metadataPath -Values @{lastDialogExperimentId=$ExperimentId;lastDialogEvidence=$localDirectory}
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $localDirectory | Out-Null
Update-OctaneEvidenceChecksums -Directory $localDirectory
Write-Output "Dialog experiment: $ExperimentId"
Write-Output "Evidence: $localDirectory"
Write-Output $detail
if ($status -ne 'PASS') { throw "Dialog experiment failed. Evidence was retained at $localDirectory" }
