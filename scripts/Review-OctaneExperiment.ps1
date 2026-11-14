[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$ExperimentId,
    [Parameter(Mandatory=$true)][ValidateSet('PASS','FAIL')][string]$Status,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Detail
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'RunState.ps1')

$metadataPath = Join-Path $root "runs/$Container.json"
if (-not (Test-Path -LiteralPath $metadataPath)) { throw "Run metadata not found: $metadataPath" }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$directory = Join-Path $root "evidence/$($metadata.runId)/experiments/$ExperimentId"
$probePath = Join-Path $directory 'probe.json'
$profilePath = Join-Path $directory 'profile.json'
if (-not (Test-Path -LiteralPath $probePath)) { throw "Experiment probe not found: $probePath" }
if (-not (Test-Path -LiteralPath $profilePath)) { throw "Experiment profile not found: $profilePath" }

$probe = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
if ($probe.runId -ne $ExperimentId -or $profile.experimentId -ne $ExperimentId) {
    throw 'Experiment identity does not match its directory.'
}
if ($Status -eq 'PASS' -and $probe.observations.clientAreaChanged -ne 'PASS') {
    throw 'Visible review cannot pass when the native client-area comparison did not pass.'
}

$probe.observations.visualReview = $Status
$probe.qualification = 'Native-window screenshots were reviewed; the review applies only to this experiment bundle.'
$profile.visualReview = $Status
$profile | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $profilePath -Encoding utf8
$probe | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $probePath -Encoding utf8
[ordered]@{
    schemaVersion = 1
    status = $Status
    reviewedAtUtc = [DateTime]::UtcNow.ToString('o')
    detail = $Detail
    qualification = 'Review covers the native application client area, not surrounding desktop activity.'
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $directory 'visual-review.json') -Encoding utf8

$stageStatus = if (
    $Status -eq 'FAIL' -or
    $probe.observations.nativeWindow -ne 'PASS' -or
    $probe.observations.domMessaging -ne 'PASS' -or
    $probe.observations.clientAreaChanged -ne 'PASS'
) { 'FAIL' } else { 'PASS' }
$stageDetail = "experiment=$ExperimentId; exit=$($probe.diagnosticExitCode); display=$($probe.runtime.displayDriver); runtime=$($probe.runtime.webView2Version); raf=$($probe.observations.maxAnimationFrames); intervals=$($probe.observations.maxIntervalCallbacks); clientChange=$($probe.observations.clientAreaChanged); visualReview=$Status; review=$Detail"
Update-OctaneRunStage -Path $metadataPath -Stage webviewDiagnostic -Status $stageStatus -Detail $stageDetail
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $directory | Out-Null
Update-OctaneEvidenceChecksums -Directory $directory

Write-Output "Experiment: $ExperimentId"
Write-Output "Evidence: $directory"
Write-Output "webviewDiagnostic=$stageStatus"
