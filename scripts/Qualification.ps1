Set-StrictMode -Version Latest

function Get-OctaneQualificationCriticalFiles {
    @(
        'lab/Dockerfile.wine-staging-11.21',
        'lab/octane-lab',
        'lab/octane-qualification-experiment',
        'lab/patches/0002-win32u-recheck-visrgn-for-cross-process-children.patch',
        'scripts/Invoke-OctaneQualificationBatch.ps1',
        'scripts/Invoke-OctaneQualificationExperiment.ps1',
        'scripts/New-OctaneQualificationLock.ps1',
        'scripts/Qualification.ps1',
        'scripts/RdpSession.ps1',
        'scripts/Runtime.ps1',
        'scripts/RuntimeProfiles.ps1',
        'scripts/Validate-OctaneReport.ps1'
    )
}

function Get-OctaneQualificationFileManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot)
    foreach ($relative in Get-OctaneQualificationCriticalFiles) {
        $path = Join-Path $RepositoryRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Qualification input is missing: $relative" }
        [ordered]@{
            path = $relative.Replace('\','/')
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
}

function Get-OctaneQualificationLockHash {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LockPath)
    if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) { throw "Qualification lock not found: $LockPath" }
    return (Get-FileHash -LiteralPath $LockPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-OctaneQualificationLockFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Lock,
        [Parameter(Mandatory=$true)][string]$RepositoryRoot
    )
    if ([int]$Lock.schemaVersion -ne 1) { throw 'Qualification lock schemaVersion must be 1.' }
    if ([int]$Lock.contract.plannedRuns -ne 10) { throw 'Qualification lock must declare exactly ten planned runs.' }
    if ([string]$Lock.profile.name -ne 'DockerWineStaging1121VisRgn') { throw 'Qualification lock selected an unexpected profile.' }
    foreach ($entry in @($Lock.harness.files)) {
        $path = Join-Path $RepositoryRoot ([string]$entry.path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Locked harness file is missing: $($entry.path)" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Qualification lock drift: $($entry.path)" }
    }
    foreach ($entry in @($Lock.fixtures.files)) {
        $path = Join-Path $RepositoryRoot ([string]$entry.path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Locked fixture is missing: $($entry.path)" }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "Qualification fixture drift: $($entry.path)" }
    }
    $installer = Join-Path $RepositoryRoot 'artifacts/Octane-setup.exe'
    $manifest = Join-Path $RepositoryRoot 'artifacts/installer-manifest.json'
    foreach ($item in @(
        @{Path=$installer;Expected=[string]$Lock.artifact.installerSha256;Name='installer'},
        @{Path=$manifest;Expected=[string]$Lock.artifact.manifestSha256;Name='installer manifest'}
    )) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) { throw "Locked $($item.Name) is missing." }
        $actual = (Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $item.Expected.ToLowerInvariant()) { throw "Qualification $($item.Name) drift." }
    }
}

function Test-OctaneQualificationBatchRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Batch,
        [Parameter(Mandatory=$true)][string]$ExpectedLockHash,
        [ValidateRange(1,100)][int]$ExpectedRunCount = 10
    )
    $reasons = [Collections.Generic.List[string]]::new()
    if ([int]$Batch.schemaVersion -ne 1) { $reasons.Add('batch schemaVersion is not 1') }
    if ([string]$Batch.lockSha256 -ne $ExpectedLockHash) { $reasons.Add('batch lock hash differs from the declared lock') }
    $planned = @($Batch.plannedRunIds)
    $runs = @($Batch.runs)
    if ($planned.Count -ne $ExpectedRunCount) { $reasons.Add("planned run count is $($planned.Count), expected $ExpectedRunCount") }
    if (@($planned | Select-Object -Unique).Count -ne $planned.Count) { $reasons.Add('planned run IDs are not unique') }
    if ($runs.Count -ne $ExpectedRunCount) { $reasons.Add("recorded run count is $($runs.Count), expected $ExpectedRunCount") }
    foreach ($plannedId in $planned) {
        $matches = @($runs | Where-Object { [string]$_.runId -eq [string]$plannedId })
        if ($matches.Count -ne 1) { $reasons.Add("planned run $plannedId has $($matches.Count) result records"); continue }
        $run = $matches[0]
        if ([string]$run.status -ne 'PASS') { $reasons.Add("run $plannedId status is $($run.status)") }
        if ([string]$run.lockSha256 -ne $ExpectedLockHash) { $reasons.Add("run $plannedId lock hash differs") }
        if ([string]$run.scenarioStatus -ne 'PASS') { $reasons.Add("run $plannedId scenario did not pass") }
        if ([string]$run.reportValidation -ne 'PASS') { $reasons.Add("run $plannedId report validation did not pass") }
        if ([string]$run.evidenceStatus -ne 'PASS') { $reasons.Add("run $plannedId evidence validation did not pass") }
        if ([string]$run.cleanupStatus -ne 'PASS') { $reasons.Add("run $plannedId cleanup did not pass") }
        if ([bool]$run.forcedRepaintUsed) { $reasons.Add("run $plannedId used forced repainting") }
        if ([int]$run.hiddenRetries -ne 0) { $reasons.Add("run $plannedId recorded hidden retries") }
        if ([int]$run.manualOverrides -ne 0) { $reasons.Add("run $plannedId recorded manual overrides") }
    }
    [pscustomobject]@{
        Qualified = $reasons.Count -eq 0
        Passed = @($runs | Where-Object { $_.status -eq 'PASS' }).Count
        Planned = $planned.Count
        Reasons = @($reasons)
    }
}

function Write-OctaneQualificationResultArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ScenarioPath,
        [Parameter(Mandatory=$true)][string]$OutputDirectory
    )
    $scenario = Get-Content -LiteralPath $ScenarioPath -Raw | ConvertFrom-Json
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    [ordered]@{
        schemaVersion=1
        overallStatus=[string]$scenario.overallStatus
        runId=[string]$scenario.runId
        automation=$scenario.automation
        gates=$scenario.gates
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json') -Encoding utf8

    $xml = [Xml.XmlDocument]::new()
    [void]$xml.AppendChild($xml.CreateXmlDeclaration('1.0','utf-8',$null))
    $suite = $xml.CreateElement('testsuite')
    $entries = @($scenario.gates.PSObject.Properties)
    $suite.SetAttribute('name','Octane locked acceptance')
    $suite.SetAttribute('tests',[string]$entries.Count)
    $suite.SetAttribute('failures',[string]@($entries | Where-Object { $_.Value.status -eq 'FAIL' }).Count)
    $suite.SetAttribute('skipped',[string]@($entries | Where-Object { $_.Value.status -in @('BLOCKED','NOT_RUN') }).Count)
    $suite.SetAttribute('timestamp',[string]$scenario.completedAtUtc)
    [void]$xml.AppendChild($suite)
    foreach ($entry in $entries) {
        $case = $xml.CreateElement('testcase')
        $case.SetAttribute('name',[string]$entry.Name)
        $case.SetAttribute('classname','octane.docker.wine.locked')
        $reason = [string]$entry.Value.reason
        if ($entry.Value.status -eq 'FAIL') {
            $failure = $xml.CreateElement('failure'); $failure.SetAttribute('message',$reason); $failure.InnerText=$reason; [void]$case.AppendChild($failure)
        } elseif ($entry.Value.status -in @('BLOCKED','NOT_RUN')) {
            $skipped = $xml.CreateElement('skipped'); $skipped.SetAttribute('message',$reason); [void]$case.AppendChild($skipped)
        } else {
            $systemOut = $xml.CreateElement('system-out'); $systemOut.InnerText=$reason; [void]$case.AppendChild($systemOut)
        }
        [void]$suite.AppendChild($case)
    }
    $settings = [Xml.XmlWriterSettings]::new()
    $settings.Indent=$true; $settings.Encoding=[Text.UTF8Encoding]::new($false)
    $writer = [Xml.XmlWriter]::Create((Join-Path $OutputDirectory 'junit.xml'),$settings)
    try { $xml.Save($writer) } finally { $writer.Dispose() }
}
