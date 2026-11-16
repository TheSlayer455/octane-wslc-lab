[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
    [string]$WslDistro,
    [string]$ScreenshotDirectory,
    [string]$RecordingPath
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'FileAccess.ps1')
$metadataPath=Join-Path $root "runs/$Container.json"
if(-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)){throw "Run metadata not found: $metadataPath"}
$record=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if(-not $record.targetPreview){throw "$Container is not a generic target-preview run."}
if(-not $WslDistro){$WslDistro=[string]$record.wslDistro}
Assert-OctaneContainer -Name $Container -Engine Docker -WslDistro $WslDistro | Out-Null

$hostInputIntegrity='NOT_TESTED'
$hostInputDetail='No source manifest was recorded.'
if($record.PSObject.Properties['inputManifestPath'] -and (Test-Path -LiteralPath ([string]$record.inputManifestPath) -PathType Leaf)){
    $expectedInput=Get-Content -LiteralPath ([string]$record.inputManifestPath) -Raw | ConvertFrom-Json
    $actualInput=Get-OctaneDirectoryManifest -Path ([string]$record.inputSource)
    try{
        Assert-OctaneDirectoryManifest -Expected $expectedInput -Actual $actualInput -Context 'Selected host input changed after preview startup.'
        $hostInputIntegrity='PASS'
        $hostInputDetail='Selected host input file identities and hashes are unchanged.'
    }catch{
        $hostInputIntegrity='FAIL'
        $hostInputDetail=$_.Exception.Message
        Update-OctaneRunStage -Path $metadataPath -Stage workload -Status FAIL -Detail $hostInputDetail
    }
}

$verify=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$Container,'octane-target','verify-inputs') -TimeoutSeconds 120 -AllowFailure
if($verify.ExitCode -ne 0 -or $verify.TimedOut){Update-OctaneRunStage -Path $metadataPath -Stage workload -Status FAIL -Detail 'Input integrity verification failed during collection.'}

$outputRoot=[IO.Path]::GetFullPath([string]$record.operatorOutputDirectory)
$runOutput=Join-Path $outputRoot ([string]$record.runId)
if(Test-Path -LiteralPath $runOutput){throw "Per-run output already exists and will not be overwritten: $runOutput. Preserve or remove this exact run output before retrying collection."}
New-Item -ItemType Directory -Path $runOutput | Out-Null
try{
    $runtimeOutput=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $runOutput
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('container','cp',"$Container`:/home/wineuser/.octane/output/.",$runtimeOutput) -TimeoutSeconds 300 | Out-Null
    [ordered]@{schemaVersion=1;runId=[string]$record.runId;container=$Container;collectedAtUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runOutput '.octane-output.json') -Encoding utf8
    [ordered]@{schemaVersion=1;status=$hostInputIntegrity;detail=$hostInputDetail;checkedAtUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runOutput 'host-input-integrity.json') -Encoding utf8
    Update-OctaneEvidenceChecksums -Directory $runOutput
}catch{
    Remove-Item -LiteralPath $runOutput -Recurse -Force -ErrorAction SilentlyContinue
    throw
}

$collectArgs=@{Container=$Container;Engine='Docker';WslDistro=$WslDistro}
if($ScreenshotDirectory){$collectArgs.ScreenshotDirectory=$ScreenshotDirectory}
if($RecordingPath){$collectArgs.RecordingPath=$RecordingPath}
$evidence=& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') @collectArgs
$evidenceLine=$evidence | Where-Object {$_ -match '^Evidence: '} | Select-Object -First 1
$evidencePath=if($evidenceLine){($evidenceLine -replace '^Evidence:\s*','').Trim()}else{$null}
Set-OctaneRunMetadata -Path $metadataPath -Values @{previewOutputCollected=$true;previewOutputPath=$runOutput;previewEvidencePath=$evidencePath;previewCollectedAtUtc=[DateTime]::UtcNow.ToString('o')}
Write-Output $evidence
Write-Output "Collected target output: $runOutput"
$updated=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if([string]$updated.browserEndToEndStatus -eq 'PASS'){
    Write-Output 'Browser gates: PASS from separately attributable approved automation evidence recorded for this run.'
}else{
    Write-Output 'Browser gates remain BLOCKED unless separately attributable operator or approved automation evidence was supplied.'
}
