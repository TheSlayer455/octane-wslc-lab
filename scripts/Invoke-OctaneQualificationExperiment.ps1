[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Docker',
    [string]$WslDistro,
    [ValidatePattern('^[A-Za-z0-9._-]{8,96}$')][string]$QualificationRunId = ('qualification-'+[Guid]::NewGuid().ToString('N')),
    [ValidateSet('Exploratory','Locked')][string]$Mode = 'Exploratory',
    [ValidateRange(180,1800)][int]$TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'Qualification.ps1')

Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro | Out-Null
$metadataPath = Join-Path $root "runs/$Container.json"
if (-not (Test-Path -LiteralPath $metadataPath)) { throw "Run metadata not found: $metadataPath" }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$profile = Get-OctaneWineProfile -WineProfile $metadata.wineProfile -BaseImage $metadata.baseImage
$arguments = @(
    'exec','-u',$profile.ExecUser,
    '-e',"OCTANE_QUALIFICATION_RUN_ID=$QualificationRunId",
    '-e',"OCTANE_QUALIFICATION_MODE=$($Mode.ToLowerInvariant())",
    $Container,'octane-lab','qualification-experiment'
)
$run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $arguments -TimeoutSeconds $TimeoutSeconds -AllowFailure

$localDirectory = Join-Path $root "evidence/$($metadata.runId)/qualification/$QualificationRunId"
New-Item -ItemType Directory -Path $localDirectory -Force | Out-Null
$controllerLogDirectory = Join-Path $localDirectory 'logs/controller'
New-Item -ItemType Directory -Path $controllerLogDirectory -Force | Out-Null
$run.StdOut | Set-Content -LiteralPath (Join-Path $controllerLogDirectory 'runtime.stdout.log') -Encoding utf8
$run.StdErr | Set-Content -LiteralPath (Join-Path $controllerLogDirectory 'runtime.stderr.log') -Encoding utf8
[ordered]@{exitCode=$run.ExitCode;timedOut=$run.TimedOut;durationMs=$run.DurationMs} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $controllerLogDirectory 'runtime-result.json') -Encoding utf8
$runtimeDirectory = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $localDirectory
$source = "$Container`:$($profile.EvidenceDirectory)/qualification/$QualificationRunId/."
$copy = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('container','cp',$source,$runtimeDirectory) -TimeoutSeconds 180 -AllowFailure
if ($copy.ExitCode -ne 0 -or $copy.TimedOut) { throw "Qualification experiment exited $($run.ExitCode), and evidence copy failed. $($copy.StdErr.Trim())" }

$scenarioPath = Join-Path $localDirectory 'scenario.json'
if (-not (Test-Path -LiteralPath $scenarioPath)) { throw "Qualification experiment did not produce scenario.json. Evidence: $localDirectory" }
$scenario = Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
Write-OctaneQualificationResultArtifacts -ScenarioPath $scenarioPath -OutputDirectory $localDirectory
$reportValidation = $null
$reportPath = Join-Path $localDirectory 'report.json'
if (Test-Path -LiteralPath $reportPath) {
    try {
        & (Join-Path $PSScriptRoot 'Validate-OctaneReport.ps1') -ReportPath $reportPath -FixtureDirectory (Join-Path $root 'fixtures') -OutputPath (Join-Path $localDirectory 'report-validation.json') | Out-Null
        $reportValidation = 'PASS'
    } catch {
        $reportValidation = 'FAIL'
        $_.Exception.Message | Set-Content -LiteralPath (Join-Path $localDirectory 'report-validation-error.txt') -Encoding utf8
    }
} else { $reportValidation = 'MISSING' }

function Get-GateStatus([string]$Name) {
    $property = $scenario.gates.PSObject.Properties[$Name]
    if ($null -eq $property) { return 'NOT_RUN' }
    return [string]$property.Value.status
}
$strictPass = $run.ExitCode -eq 0 -and -not $run.TimedOut -and $scenario.overallStatus -eq 'PASS' -and
    $scenario.automation.unattended -eq $true -and $scenario.automation.forcedRepaintUsed -eq $false -and
    [int]$scenario.automation.hiddenRetries -eq 0 -and [int]$scenario.automation.manualOverrides -eq 0 -and
    $reportValidation -eq 'PASS'

$applicationStatus = if ((Get-GateStatus 'initialVisible') -eq 'PASS' -and (Get-GateStatus 'continuingPresentation') -eq 'PASS') { 'PASS' } else { 'FAIL' }
$workloadStatus = Get-GateStatus 'workload'
$dialogStatus = if ((Get-GateStatus 'nativeOpenDialog') -eq 'PASS' -and (Get-GateStatus 'nativeSaveDialog') -eq 'PASS') { 'PASS' } elseif ((Get-GateStatus 'nativeOpenDialog') -eq 'BLOCKED' -or (Get-GateStatus 'nativeSaveDialog') -eq 'BLOCKED') { 'BLOCKED' } else { 'FAIL' }
$exportStatus = if ((Get-GateStatus 'export') -eq 'PASS' -and (Get-GateStatus 'existingOutputAndInputs') -eq 'PASS' -and $reportValidation -eq 'PASS') { 'PASS' } elseif ((Get-GateStatus 'export') -eq 'BLOCKED') { 'BLOCKED' } else { 'FAIL' }

Update-OctaneRunStage -Path $metadataPath -Stage application -Status $applicationStatus -Detail "qualification=$QualificationRunId; initialVisible=$(Get-GateStatus 'initialVisible'); continuingPresentation=$(Get-GateStatus 'continuingPresentation'); forcedRepaintUsed=$($scenario.automation.forcedRepaintUsed)" -DurationMs $run.DurationMs
Update-OctaneRunStage -Path $metadataPath -Stage workload -Status $workloadStatus -Detail "qualification=$QualificationRunId; machine-recorded workload gate."
Update-OctaneRunStage -Path $metadataPath -Stage nativeDialogs -Status $dialogStatus -Detail "qualification=$QualificationRunId; open=$(Get-GateStatus 'nativeOpenDialog'); save=$(Get-GateStatus 'nativeSaveDialog')"
Update-OctaneRunStage -Path $metadataPath -Stage export -Status $exportStatus -Detail "qualification=$QualificationRunId; export=$(Get-GateStatus 'export'); protection=$(Get-GateStatus 'existingOutputAndInputs'); independentValidation=$reportValidation"
Set-OctaneRunMetadata -Path $metadataPath -Values @{lastQualificationRunId=$QualificationRunId;lastQualificationEvidence=$localDirectory;qualificationMode=$Mode;manualReviewUsed=$false}
Write-OctaneResultArtifacts -RunPath $metadataPath -OutputDirectory $localDirectory | Out-Null
Update-OctaneEvidenceChecksums -Directory $localDirectory
Write-Output "Qualification experiment: $QualificationRunId"
Write-Output "Evidence: $localDirectory"
Write-Output "Scenario=$($scenario.overallStatus); reportValidation=$reportValidation; strictPass=$strictPass"
if (-not $strictPass) { throw "Qualification experiment did not pass the strict contract. Evidence was retained at $localDirectory" }
