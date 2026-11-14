[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine='Docker',
    [string]$WslDistro,
    [ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$ExperimentId=('app-'+[Guid]::NewGuid().ToString('N'))
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')

Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro | Out-Null
$metadataPath=Join-Path $root "runs/$Container.json"
if(-not (Test-Path -LiteralPath $metadataPath)){throw "Run metadata not found: $metadataPath"}
$metadata=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$profile=Get-OctaneWineProfile -WineProfile $metadata.wineProfile -BaseImage $metadata.baseImage
$arguments=@('exec','-u',$profile.ExecUser,'-e',"OCTANE_APPLICATION_EXPERIMENT_ID=$ExperimentId",$Container,'octane-lab','application-experiment')
$run=Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $arguments -TimeoutSeconds 240 -AllowFailure

$localDirectory=Join-Path $root "evidence/$($metadata.runId)/applications/$ExperimentId"
New-Item -ItemType Directory -Path $localDirectory -Force | Out-Null
$runtimeDirectory=ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $localDirectory
$source="$Container`:$($profile.EvidenceDirectory)/applications/$ExperimentId/."
$copy=Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',$source,$runtimeDirectory) -TimeoutSeconds 180 -AllowFailure
if($copy.ExitCode -ne 0 -or $copy.TimedOut){throw "Application experiment exited $($run.ExitCode), and evidence copy failed. $($copy.StdErr.Trim())"}

$scenarioPath=Join-Path $localDirectory 'scenario.json'
if(-not (Test-Path -LiteralPath $scenarioPath)){throw "Application experiment exited $($run.ExitCode) without scenario.json. Evidence retained at $localDirectory"}
$scenario=Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
$reportPath=Join-Path $localDirectory 'report.json'
if(Test-Path -LiteralPath $reportPath){
    & (Join-Path $PSScriptRoot 'Validate-OctaneReport.ps1') -ReportPath $reportPath -FixtureDirectory (Join-Path $root 'fixtures') -OutputPath (Join-Path $localDirectory 'report-validation.json') | Out-Null
}
Set-OctaneRunMetadata -Path $metadataPath -Values @{lastApplicationExperimentId=$ExperimentId;lastApplicationEvidence=$localDirectory}
$detail="experiment=$ExperimentId; exit=$($run.ExitCode); nativeWindow=$($scenario.observations.nativeWindow); visibleRepaint=$($scenario.observations.focusRepaintPixelChange); repaintNudge=$($scenario.observations.repaintNudge); repaintAttempts=$($scenario.observations.repaintNudgeAttempts); repaintNudgeMs=$($scenario.observations.repaintNudgeDurationMs); clientColors=$($scenario.observations.clientColorCount); workload=$($scenario.observations.workload); dialogs=$($scenario.observations.nativeDialogs); export=$($scenario.observations.export); overwriteDecline=$($scenario.observations.overwriteDecline); visualReview=NOT_RUN"
Update-OctaneRunStage -Path $metadataPath -Stage application -Status NOT_RUN -Detail $detail -DurationMs $run.DurationMs
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $localDirectory | Out-Null
Update-OctaneEvidenceChecksums -Directory $localDirectory
Write-Output "Application experiment: $ExperimentId"
Write-Output "Evidence: $localDirectory"
Write-Output $detail
if($run.ExitCode -ne 0){throw "Application experiment returned exit code $($run.ExitCode). Evidence was retained."}

