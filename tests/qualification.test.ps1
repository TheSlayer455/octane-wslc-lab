$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'scripts/Qualification.ps1')

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function New-PassRun([string]$Id,[string]$LockHash) {
    [pscustomobject]@{
        runId=$Id;status='PASS';lockSha256=$LockHash;scenarioStatus='PASS';reportValidation='PASS';evidenceStatus='PASS';cleanupStatus='PASS'
        forcedRepaintUsed=$false;hiddenRetries=0;manualOverrides=0
    }
}

$lockHash = 'a' * 64
$ids = 1..10 | ForEach-Object { "run-$($_.ToString('00'))" }
$batch = [pscustomobject]@{schemaVersion=1;lockSha256=$lockHash;plannedRunIds=@($ids);runs=@($ids | ForEach-Object { New-PassRun $_ $lockHash })}
$result = Test-OctaneQualificationBatchRecord -Batch $batch -ExpectedLockHash $lockHash
Assert $result.Qualified 'A complete, exact ten-run pass should qualify.'
Assert ($result.Passed -eq 10) 'The complete batch should count ten passes.'

$nine = [pscustomobject]@{schemaVersion=1;lockSha256=$lockHash;plannedRunIds=@($ids);runs=@($batch.runs | Select-Object -First 9)}
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $nine -ExpectedLockHash $lockHash).Qualified) '9/10 must not qualify.'
$forced = $batch | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$forced.runs[3].forcedRepaintUsed = $true
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $forced -ExpectedLockHash $lockHash).Qualified) 'Forced repaint use must reject a batch.'
$manual = $batch | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$manual.runs[4].manualOverrides = 1
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $manual -ExpectedLockHash $lockHash).Qualified) 'A manual override must reject a batch.'
$retry = $batch | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$retry.runs[5].hiddenRetries = 1
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $retry -ExpectedLockHash $lockHash).Qualified) 'A hidden retry must reject a batch.'
$missing = $batch | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$missing.runs[6].evidenceStatus = 'FAIL'
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $missing -ExpectedLockHash $lockHash).Qualified) 'Missing evidence must reject a batch.'
$cleanup = $batch | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$cleanup.runs[7].cleanupStatus = 'FAIL'
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $cleanup -ExpectedLockHash $lockHash).Qualified) 'Failed exact cleanup must reject a batch.'
Assert (-not (Test-OctaneQualificationBatchRecord -Batch $batch -ExpectedLockHash ('b' * 64)).Qualified) 'Lock mismatch must reject a batch.'

$temp = Join-Path ([IO.Path]::GetTempPath()) ('octane-qualification-test-'+[Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $scenarioPath = Join-Path $temp 'scenario.json'
    [ordered]@{
        schemaVersion=2;runId='mock';completedAtUtc=[DateTime]::UtcNow.ToString('o');overallStatus='FAIL';automation=[ordered]@{forcedRepaintUsed=$false}
        gates=[ordered]@{
            passGate=[ordered]@{status='PASS';reason='passed'}
            failGate=[ordered]@{status='FAIL';reason='failed'}
            blockedGate=[ordered]@{status='BLOCKED';reason='blocked upstream'}
        }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $scenarioPath
    Write-OctaneQualificationResultArtifacts -ScenarioPath $scenarioPath -OutputDirectory $temp
    Assert (Test-Path -LiteralPath (Join-Path $temp 'results.json')) 'Result JSON must be emitted.'
    $junit = [xml](Get-Content -LiteralPath (Join-Path $temp 'junit.xml') -Raw)
    Assert ($junit.testsuite.failures -eq '1') 'JUnit must preserve a failed gate.'
    Assert ($junit.testsuite.skipped -eq '1') 'JUnit must map a blocked gate to skipped.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

Write-Output 'Qualification policy: 12 assertions passed (aggregation/schema tests; not a live GUI test).'
