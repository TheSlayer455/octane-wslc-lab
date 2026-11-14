[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Docker',
    [string]$WslDistro,
    [ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$ObservationId = ('repaint-'+[Guid]::NewGuid().ToString('N')),
    [ValidateRange(10,180)][int]$ObserveSeconds = 60
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
$arguments = @(
    'exec','-u',$profile.ExecUser,
    '-e',"OCTANE_REPAINT_OBSERVATION_ID=$ObservationId",
    '-e',"OCTANE_REPAINT_OBSERVE_SECONDS=$ObserveSeconds",
    $Container,'octane-lab','repaint-observation'
)
$run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $arguments -TimeoutSeconds ($ObserveSeconds + 180) -AllowFailure

$localDirectory = Join-Path $root "evidence/$($metadata.runId)/repaint/$ObservationId"
New-Item -ItemType Directory -Path $localDirectory -Force | Out-Null
$runtimeDirectory = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $localDirectory
$source = "$Container`:$($profile.EvidenceDirectory)/repaint/$ObservationId/."
$copy = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',$source,$runtimeDirectory) -TimeoutSeconds 180 -AllowFailure
if ($copy.ExitCode -ne 0 -or $copy.TimedOut) { throw "Repaint observation exited $($run.ExitCode), and evidence copy failed. $($copy.StdErr.Trim())" }

$resultPath = Join-Path $localDirectory 'repaint-observation.json'
if (-not (Test-Path -LiteralPath $resultPath)) { throw "Repaint observation did not produce repaint-observation.json. Evidence: $localDirectory" }
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
$pass = $run.ExitCode -eq 0 -and -not $run.TimedOut -and
    $result.observations.nativeWindow -eq 'PASS' -and $result.observations.initialVisible -eq 'PASS' -and
    -not $result.policy.forcedRepaintUsed -and -not $result.policy.forbiddenActionsObserved
$status = if ($pass) { 'PASS' } else { 'FAIL' }
$detail = "observation=$ObservationId; normalInitialPresentation=$($result.observations.initialVisible); firstVisibleAfterMs=$($result.observations.firstVisibleAfterMs); maxClientColors=$($result.observations.maxClientColorCount); forcedRepaintUsed=$($result.policy.forcedRepaintUsed); forbiddenActions=$($result.policy.forbiddenActionsObserved)"
Update-OctaneRunStage -Path $metadataPath -Stage repaintDiagnostic -Status $status -Detail $detail -DurationMs $run.DurationMs
Set-OctaneRunMetadata -Path $metadataPath -Values @{lastRepaintObservationId=$ObservationId;lastRepaintEvidence=$localDirectory}
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $localDirectory | Out-Null
Update-OctaneEvidenceChecksums -Directory $localDirectory
Write-Output "Repaint observation: $ObservationId"
Write-Output "Evidence: $localDirectory"
Write-Output $detail
if (-not $pass) { throw "Normal initial presentation was not established. Evidence was retained at $localDirectory" }
