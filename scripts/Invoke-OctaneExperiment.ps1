[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Docker',
    [string]$WslDistro,
    [ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$ExperimentId = ('wv2-'+[Guid]::NewGuid().ToString('N')),
    [ValidateRange(10,600)][int]$DurationSeconds = 30,
    [ValidateRange(5,600)][int]$StageTimeoutSeconds = 45,
    [string]$BrowserArguments,
    [string]$FixedRuntimeFolder,
    [ValidateSet('PASS','FAIL','NOT_RUN')][string]$VisualReview = 'NOT_RUN'
)

$ErrorActionPreference = 'Stop'
if ($BrowserArguments -match '(?i)(password|passwd|authorization|bearer|access[_-]?token|client[_-]?secret)') {
    throw 'Browser arguments must not contain credentials or access tokens because requested and effective arguments are retained in evidence.'
}
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')

$info = Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro
$metadataPath = Join-Path $root "runs/$Container.json"
if (-not (Test-Path -LiteralPath $metadataPath)) { throw "Run metadata not found: $metadataPath" }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if ($metadata.engine -ne $Engine) { throw "Run metadata belongs to engine $($metadata.engine), not $Engine." }
if ([string]$metadata.wslDistro -ne [string]$WslDistro) { throw 'The selected WSL distribution does not match run metadata.' }
$profile = Get-OctaneWineProfile -WineProfile $metadata.wineProfile -BaseImage $metadata.baseImage

$arguments = [Collections.Generic.List[string]]::new()
foreach ($value in @('exec','-u',$profile.ExecUser,'-e',"OCTANE_EXPERIMENT_ID=$ExperimentId",'-e',"OCTANE_EXPERIMENT_DURATION_SECONDS=$DurationSeconds",'-e',"OCTANE_DIAGNOSTIC_STAGE_TIMEOUT_SECONDS=$StageTimeoutSeconds")) {
    $arguments.Add($value)
}
if ($BrowserArguments) { foreach ($value in @('-e',"OCTANE_WEBVIEW2_BROWSER_ARGS=$BrowserArguments")) { $arguments.Add($value) } }
if ($FixedRuntimeFolder) { foreach ($value in @('-e',"OCTANE_WEBVIEW2_BROWSER_EXECUTABLE_FOLDER=$FixedRuntimeFolder")) { $arguments.Add($value) } }
foreach ($value in @($Container,'octane-lab','experiment')) { $arguments.Add($value) }

$experiment = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $arguments.ToArray() -TimeoutSeconds ($DurationSeconds + $StageTimeoutSeconds + 180) -AllowFailure
$localDirectory = Join-Path $root "evidence/$($metadata.runId)/experiments/$ExperimentId"
New-Item -ItemType Directory -Path $localDirectory -Force | Out-Null
$runtimeDirectory = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $localDirectory
$source = "$Container`:$($profile.EvidenceDirectory)/experiments/$ExperimentId/."
$copy = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',$source,$runtimeDirectory) -TimeoutSeconds 180 -AllowFailure
if ($copy.ExitCode -ne 0 -or $copy.TimedOut) {
    throw "Experiment exited $($experiment.ExitCode), and evidence copy failed. $($copy.StdErr.Trim())"
}

$probePath = Join-Path $localDirectory 'probe.json'
if (-not (Test-Path -LiteralPath $probePath)) {
    throw "Experiment exited $($experiment.ExitCode) without probe.json. Evidence retained at $localDirectory"
}
$probe = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
$screen = [string]$probe.observations.clientAreaChanged
$stageStatus = if ($experiment.ExitCode -ne 0 -or $probe.observations.nativeWindow -ne 'PASS' -or $probe.observations.domMessaging -ne 'PASS') {
    'FAIL'
} elseif ($screen -eq 'FAIL') {
    'FAIL'
} elseif ($screen -eq 'PASS' -and $VisualReview -eq 'PASS') {
    'PASS'
} elseif ($VisualReview -eq 'FAIL') {
    'FAIL'
} else {
    'NOT_RUN'
}
$detail = "experiment=$ExperimentId; exit=$($experiment.ExitCode); display=$($probe.runtime.displayDriver); runtime=$($probe.runtime.webView2Version); raf=$($probe.observations.maxAnimationFrames); intervals=$($probe.observations.maxIntervalCallbacks); clientChange=$screen; visualReview=$VisualReview"
Update-OctaneRunStage -Path $metadataPath -Stage webviewDiagnostic -Status $stageStatus -Detail $detail -DurationMs $experiment.DurationMs
Set-OctaneRunMetadata -Path $metadataPath -Values @{
    lastExperimentId = $ExperimentId
    lastExperimentEvidence = $localDirectory
}

$updatedMetadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
Copy-Item -LiteralPath (Join-Path $root 'artifacts/installer-manifest.json') -Destination (Join-Path $localDirectory 'installer-manifest.json') -Force
[ordered]@{
    schemaVersion = 1
    experimentId = $ExperimentId
    parentRunId = $updatedMetadata.runId
    engine = $Engine
    engineContext = $updatedMetadata.engineContext
    wslDistro = if ($WslDistro) { $WslDistro } else { $null }
    wineProfile = $updatedMetadata.wineProfile
    baseImage = $updatedMetadata.baseImage
    resolvedBaseImage = $updatedMetadata.resolvedBaseImage
    installerSha256 = $updatedMetadata.installerSha256
    durationSeconds = $DurationSeconds
    stageTimeoutSeconds = $StageTimeoutSeconds
    requestedBrowserArguments = if ($BrowserArguments) { $BrowserArguments } else { $null }
    requestedFixedRuntimeFolder = if ($FixedRuntimeFolder) { $FixedRuntimeFolder } else { $null }
    visualReview = $VisualReview
    securityExceptions = @()
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $localDirectory 'profile.json') -Encoding utf8
[ordered]@{
    schemaVersion = 1
    engine = $Engine
    engineContext = $updatedMetadata.engineContext
    wslDistro = if ($WslDistro) { $WslDistro } else { $null }
    wineProfile = $updatedMetadata.wineProfile
    container = $Container
    displayDriver = $probe.runtime.displayDriver
    webView2Version = $probe.runtime.webView2Version
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $localDirectory 'environment.json') -Encoding utf8
[ordered]@{
    schemaVersion = 1
    status = $VisualReview
    reviewedAtUtc = if ($VisualReview -eq 'NOT_RUN') { $null } else { [DateTime]::UtcNow.ToString('o') }
    qualification = if ($VisualReview -eq 'NOT_RUN') { 'Native-window screenshots have not received final visual review.' } else { 'Review applies only to this experiment evidence bundle.' }
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $localDirectory 'visual-review.json') -Encoding utf8
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $localDirectory | Out-Null
Update-OctaneEvidenceChecksums -Directory $localDirectory

Write-Output "Experiment: $ExperimentId"
Write-Output "Evidence: $localDirectory"
Write-Output "webviewDiagnostic=$stageStatus"
Write-Output $detail
if ($experiment.ExitCode -ne 0) { throw "The container experiment returned exit code $($experiment.ExitCode). Evidence was collected." }
