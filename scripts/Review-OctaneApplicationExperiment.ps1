[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$ExperimentId,
    [Parameter(Mandatory=$true)][ValidateSet('PASS','FAIL')][string]$Status,
    [Parameter(Mandatory=$true)][string]$Detail
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'RunState.ps1')
$metadataPath=Join-Path $root "runs/$Container.json"
if(-not (Test-Path -LiteralPath $metadataPath)){throw "Run metadata not found: $metadataPath"}
$metadata=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$directory=Join-Path $root "evidence/$($metadata.runId)/applications/$ExperimentId"
$scenarioPath=Join-Path $directory 'scenario.json'
if(-not (Test-Path -LiteralPath $scenarioPath)){throw "Scenario not found: $scenarioPath"}
$scenario=Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
$visibleAutomationPass=$scenario.observations.nativeWindow -eq 'PASS' -and $scenario.observations.focusRepaintPixelChange -eq 'PASS'
if($Status -eq 'PASS' -and -not $visibleAutomationPass){throw 'Visual review cannot pass when the automated native-window or repaint gate failed.'}

$scenario.observations.visualReview=$Status
$scenario.qualification='Native-window screenshots were reviewed; the result applies only to this run/profile/artifact identity.'
$scenario | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $scenarioPath -Encoding utf8
[ordered]@{schemaVersion=1;status=$Status;reviewedAtUtc=[DateTime]::UtcNow.ToString('o');detail=$Detail} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $directory 'visual-review.json') -Encoding utf8

if($Status -eq 'PASS'){
    Update-OctaneRunStage -Path $metadataPath -Stage application -Status PASS -Detail "experiment=$ExperimentId; visible native Octane client repainted and remained responsive; repaintNudge=$($scenario.observations.repaintNudge); repaintAttempts=$($scenario.observations.repaintNudgeAttempts); repaintNudgeMs=$($scenario.observations.repaintNudgeDurationMs); clientColors=$($scenario.observations.clientColorCount); $Detail"
    if($scenario.observations.workload -eq 'PASS'){
        Update-OctaneRunStage -Path $metadataPath -Stage workload -Status PASS -Detail "experiment=$ExperimentId; fixture contract and independent report validator PASS."
    }else{
        Update-OctaneRunStage -Path $metadataPath -Stage workload -Status FAIL -Detail "experiment=$ExperimentId; workload automation did not complete the fixture contract."
    }
    if($scenario.observations.nativeDialogs -eq 'PASS'){
        Update-OctaneRunStage -Path $metadataPath -Stage nativeDialogs -Status PASS -Detail "experiment=$ExperimentId; native open/save/overwrite dialogs captured; cancellation and decline paths PASS."
    }else{
        Update-OctaneRunStage -Path $metadataPath -Stage nativeDialogs -Status FAIL -Detail "experiment=$ExperimentId; required native dialog capture/cancellation sequence did not complete."
    }
    if($scenario.observations.export -eq 'PASS' -and $scenario.observations.overwriteDecline -eq 'PASS'){
        Update-OctaneRunStage -Path $metadataPath -Stage export -Status PASS -Detail "experiment=$ExperimentId; exported JSON parsed, matched fixtures, and remained unchanged after overwrite decline."
    }else{
        Update-OctaneRunStage -Path $metadataPath -Stage export -Status FAIL -Detail "experiment=$ExperimentId; export=$($scenario.observations.export); overwriteDecline=$($scenario.observations.overwriteDecline); required export contract did not fully pass."
    }
}else{
    Update-OctaneRunStage -Path $metadataPath -Stage application -Status FAIL -Detail "experiment=$ExperimentId; visual review FAIL; $Detail"
    foreach($stage in @('workload','nativeDialogs','export')){Update-OctaneRunStage -Path $metadataPath -Stage $stage -Status BLOCKED -Detail "Blocked because application visual review failed for $ExperimentId."}
}
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $directory | Out-Null
Update-OctaneEvidenceChecksums -Directory $directory
Write-Output "Application experiment $ExperimentId visualReview=$Status"

