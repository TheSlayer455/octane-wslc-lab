[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$LockPath,
    [string]$WslDistro = 'Ubuntu-24.04',
    [ValidateRange(1024,65535)][int]$Port = 3394
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'RdpSession.ps1')
. (Join-Path $PSScriptRoot 'Qualification.ps1')

$LockPath = [IO.Path]::GetFullPath($LockPath)
$lock = Get-Content -LiteralPath $LockPath -Raw | ConvertFrom-Json
$lockHash = Get-OctaneQualificationLockHash -LockPath $LockPath
Assert-OctaneQualificationLockFiles -Lock $lock -RepositoryRoot $root
if ([string]$lock.host.wslDistro -ne $WslDistro) { throw "Lock requires WSL distribution $($lock.host.wslDistro)." }
$actualImageInspect = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',[string]$lock.image.reference) -TimeoutSeconds 60
$actualImage = @($actualImageInspect.StdOut | ConvertFrom-Json)[0]
if ([string]$actualImage.Id -ne [string]$lock.image.id) { throw 'Locked image ID is absent or has drifted.' }
$context = (Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('context','show') -TimeoutSeconds 30).StdOut.Trim()
if ($context -ne [string]$lock.host.docker.context) { throw "Docker context drift: expected $($lock.host.docker.context), actual $context." }
if (-not (Test-OctanePortAvailable -Port $Port)) { throw "Loopback port $Port is already in use." }

$batchId = 'qbatch-' + [Guid]::NewGuid().ToString('N').Substring(0,12)
$batchDirectory = Join-Path $root "evidence/batches/$batchId"
$runsDirectory = Join-Path $batchDirectory 'runs'
New-Item -ItemType Directory -Path $runsDirectory -Force | Out-Null
$plannedRunIds = 1..10 | ForEach-Object { "$batchId-run-$($_.ToString('00'))" }
$batchStart = [DateTime]::UtcNow
$batchRecord = [ordered]@{
    schemaVersion=1;batchId=$batchId;lockPath=[IO.Path]::GetRelativePath($root,$LockPath).Replace('\','/');lockSha256=$lockHash
    declaredAtUtc=$batchStart.ToString('o');plannedRunIds=@($plannedRunIds);runs=@();qualified=$false;status='RUNNING'
}
Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch.json') -Value $batchRecord
Copy-Item -LiteralPath $LockPath -Destination (Join-Path $batchDirectory 'qualification-lock.json')

function Get-DeterministicContainerName([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return 'octane-' + ([Convert]::ToHexString($hash).ToLowerInvariant().Substring(0,10))
}

function Wait-QualificationPortAvailable([int]$Port,[int]$TimeoutSeconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if (Test-OctanePortAvailable -Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    return $false
}

foreach ($plannedRunId in $plannedRunIds) {
    $runDirectory = Join-Path $runsDirectory $plannedRunId
    New-Item -ItemType Directory -Path (Join-Path $runDirectory 'logs/controller') -Force | Out-Null
    $container = Get-DeterministicContainerName -Value $plannedRunId
    $journalPath = Join-Path $runDirectory 'resource-journal.json'
    $journal = [ordered]@{schemaVersion=1;runId=$plannedRunId;container=$container;image=[string]$lock.image.reference;lockSha256=$lockHash;declaredAtUtc=[DateTime]::UtcNow.ToString('o');containerCreated=$false;containerId=$null;evidenceCollected=$false;cleanupStatus='NOT_RUN'}
    Write-OctaneJsonAtomic -Path $journalPath -Value $journal
    $rdp = $null
    $scenarioStatus = 'NOT_RUN'; $reportValidation = 'NOT_RUN'; $evidenceStatus = 'FAIL'; $cleanupStatus = 'NOT_RUN'; $runStatus = 'FAIL'
    $forcedRepaint = $false; $hiddenRetries = 0; $manualOverrides = 0; $failure = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $portWaitSeconds = [int]$lock.automation.interRunPortAvailabilityTimeoutSeconds
        if (-not (Wait-QualificationPortAvailable -Port $Port -TimeoutSeconds $portWaitSeconds)) {
            throw "Loopback port $Port did not become available within $portWaitSeconds seconds before $plannedRunId."
        }
        $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
        $passwordHash = New-OctaneUnixPasswordHash -Password $password -WslDistro $WslDistro
        $runArguments = @(
            'run','-d','--name',$container,
            '--label','com.octanelab.managed=true','--label','com.octanelab.engine=docker','--label','com.octanelab.profile=DockerWineStaging1121VisRgn',
            '--label',"com.octanelab.batch=$batchId",'--label',"com.octanelab.run=$plannedRunId",
            '--shm-size=1gb','-p',"127.0.0.1:${Port}:3389",'--platform','linux/amd64',
            '-e','TZ=America/Chicago','-e','RDP_SERVER=yes','-e','USER_SUDO=no','-e',"USER_PASSWD=$passwordHash",
            [string]$lock.image.reference
        )
        $created = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments $runArguments -TimeoutSeconds 180
        $journal.containerCreated=$true; $journal.containerId=$created.StdOut.Trim(); $journal.createdAtUtc=[DateTime]::UtcNow.ToString('o')
        Write-OctaneJsonAtomic -Path $journalPath -Value $journal
        Wait-OctaneEndpoint -Kind Rdp -Port $Port -TimeoutSeconds 240 | Out-Null
        $rdp = Start-OctaneRdpClient -WslDistro $WslDistro -Port $Port -Username 'wineuser' -Password $password
        $password = $null

        $displayReady = $false
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            $probe = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$container,'bash','-lc','for s in /tmp/.X11-unix/X*; do [ -S "$s" ] || continue; d=:${s##*X}; DISPLAY=$d XAUTHORITY=$HOME/.Xauthority xdpyinfo >/dev/null 2>&1 && exit 0; done; exit 1') -TimeoutSeconds 15 -AllowFailure
            if ($probe.ExitCode -eq 0) { $displayReady=$true; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not $displayReady) { throw 'RDP did not create a usable Xorgxrdp display.' }

        $environment = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$container,'octane-lab','environment') -TimeoutSeconds 120 -AllowFailure
        $environment.StdOut | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/controller/environment.stdout.log') -Encoding utf8
        $environment.StdErr | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/controller/environment.stderr.log') -Encoding utf8
        if ($environment.ExitCode -ne 0 -or $environment.TimedOut) { throw 'Container environment capture failed.' }
        $install = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$container,'octane-lab','install-silent') -TimeoutSeconds 300 -AllowFailure
        [ordered]@{exitCode=$install.ExitCode;timedOut=$install.TimedOut;durationMs=$install.DurationMs;stdout=$install.StdOut;stderr=$install.StdErr} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/controller/install.json') -Encoding utf8
        if ($install.ExitCode -ne 0 -or $install.TimedOut) { throw 'Retained NSIS installer failed.' }

        $scenario = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @(
            'exec','-u','wineuser','-e',"OCTANE_QUALIFICATION_RUN_ID=$plannedRunId",'-e','OCTANE_QUALIFICATION_MODE=locked',
            '-e',"OCTANE_EXPECTED_WEBVIEW2_VERSION=$($lock.profile.webView2.expectedLoadedVersion)",
            '-e',"OCTANE_DIALOG_FOREGROUND_TIMEOUT_SECONDS=$($lock.automation.dialogForegroundTimeoutSeconds)",
            $container,'octane-lab','qualification-experiment'
        ) -TimeoutSeconds 900 -AllowFailure
        $scenario.StdOut | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/controller/scenario.stdout.log') -Encoding utf8
        $scenario.StdErr | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/controller/scenario.stderr.log') -Encoding utf8

        $inspect = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('inspect',$container) -TimeoutSeconds 60
        $inspect.StdOut | Set-Content -LiteralPath (Join-Path $runDirectory 'container-inspect.json') -Encoding utf8
        $inspectObject = @($inspect.StdOut | ConvertFrom-Json)[0]
        $hostBinds = @($inspectObject.HostConfig.Binds | Where-Object { $_ })
        $hostMounts = @($inspectObject.Mounts | Where-Object { $_.Type -eq 'bind' })
        if ($inspectObject.HostConfig.Privileged -or $inspectObject.HostConfig.NetworkMode -eq 'host' -or
            $hostBinds.Count -ne 0 -or $hostMounts.Count -ne 0 -or @($inspectObject.HostConfig.Devices).Count -ne 0) {
            throw 'Container inspection found a forbidden security or host-access setting.'
        }

        $runtimeRunDirectory = ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $runDirectory
        $copy = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('container','cp',"$container`:/home/wineuser/.octane/evidence/qualification/$plannedRunId/.",$runtimeRunDirectory) -TimeoutSeconds 180 -AllowFailure
        if ($copy.ExitCode -ne 0 -or $copy.TimedOut) { throw 'Qualification evidence copy failed.' }
        $rawDirectory = Join-Path $runDirectory 'raw-container-evidence'
        New-Item -ItemType Directory -Path $rawDirectory -Force | Out-Null
        $runtimeRaw = ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $rawDirectory
        $rawCopy = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('container','cp',"$container`:/home/wineuser/.octane/evidence/.",$runtimeRaw) -TimeoutSeconds 180 -AllowFailure
        if ($rawCopy.ExitCode -ne 0 -or $rawCopy.TimedOut) { throw 'Environment evidence copy failed.' }
        $journal.evidenceCollected=$true; Write-OctaneJsonAtomic -Path $journalPath -Value $journal

        $scenarioPath = Join-Path $runDirectory 'scenario.json'
        if (-not (Test-Path -LiteralPath $scenarioPath)) { throw 'scenario.json is missing.' }
        $scenarioObject = Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
        Write-OctaneQualificationResultArtifacts -ScenarioPath $scenarioPath -OutputDirectory $runDirectory
        $scenarioStatus = [string]$scenarioObject.overallStatus
        $forcedRepaint = [bool]$scenarioObject.automation.forcedRepaintUsed
        $hiddenRetries = [int]$scenarioObject.automation.hiddenRetries
        $manualOverrides = [int]$scenarioObject.automation.manualOverrides
        try {
            & (Join-Path $PSScriptRoot 'Validate-OctaneReport.ps1') -ReportPath (Join-Path $runDirectory 'report.json') -FixtureDirectory (Join-Path $root 'fixtures') -OutputPath (Join-Path $runDirectory 'report-validation.json') | Out-Null
            $reportValidation='PASS'
        } catch { $reportValidation='FAIL'; $_.Exception.Message | Set-Content -LiteralPath (Join-Path $runDirectory 'report-validation-error.txt') }
        Copy-Item -LiteralPath $LockPath -Destination (Join-Path $runDirectory 'profile.json')
        $rawManifest = Join-Path $rawDirectory 'installer-manifest.json'
        if (Test-Path -LiteralPath $rawManifest) { Copy-Item -LiteralPath $rawManifest -Destination (Join-Path $runDirectory 'installer-manifest.json') -Force }
        [ordered]@{
            schemaVersion=1;capturedAtUtc=[DateTime]::UtcNow.ToString('o');windows=$lock.host.windowsVersion
            wsl=[ordered]@{versionText=$lock.host.wslVersionText;distribution=$lock.host.wslDistro;os=$lock.host.distroPrettyName;kernel=$lock.host.kernel;architecture=$lock.host.architecture}
            docker=$lock.host.docker;image=[ordered]@{reference=$lock.image.reference;id=$lock.image.id;base=$lock.image.resolvedBaseImage}
            wine=$lock.profile.wine;webView2=$lock.profile.webView2;display=$lock.profile.display;security=$lock.security
        } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $runDirectory 'environment.json') -Encoding utf8
        [ordered]@{schemaVersion=1;batchId=$batchId;runId=$plannedRunId;lockSha256=$lockHash;imageId=[string]$lock.image.id;container=$container;mode='locked';freshContainer=$true;freshWinePrefix=$true;freshWebView2UserData=$true;securityExceptions=@('FreeRDP /cert:ignore on loopback for the container self-signed XRDP certificate.')} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $runDirectory 'run.json') -Encoding utf8
        $requiredEvidence = @('run.json','environment.json','installer-manifest.json','profile.json','results.json','junit.xml','scenario.json','report.json','report-validation.json','recording.mp4')
        $allEvidencePresent = @($requiredEvidence | Where-Object { -not (Test-Path -LiteralPath (Join-Path $runDirectory $_) -PathType Leaf) }).Count -eq 0
        $evidenceStatus = if ($scenarioStatus -eq 'PASS' -and $reportValidation -eq 'PASS' -and -not $forcedRepaint -and $hiddenRetries -eq 0 -and $manualOverrides -eq 0 -and $allEvidencePresent) { 'PASS' } else { 'FAIL' }
    } catch {
        $failure = $_.Exception.Message
        $failure | Set-Content -LiteralPath (Join-Path $runDirectory 'failure.txt') -Encoding utf8
    } finally {
        if ($rdp) { Stop-OctaneRdpClient -Session $rdp -OutputDirectory (Join-Path $runDirectory 'logs/rdp-client'); $rdp=$null }
        if ($journal.containerCreated) {
            if (-not $journal.evidenceCollected) {
                try {
                    $rawDirectory = Join-Path $runDirectory 'raw-container-evidence'
                    New-Item -ItemType Directory -Path $rawDirectory -Force | Out-Null
                    $runtimeRaw = ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $rawDirectory
                    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('container','cp',"$container`:/home/wineuser/.octane/evidence/.",$runtimeRaw) -TimeoutSeconds 180 -AllowFailure | Out-Null
                } catch { }
            }
            try {
                Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('rm','-f','-v',$container) -TimeoutSeconds 120 | Out-Null
                $remaining = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('inspect',$container) -TimeoutSeconds 30 -AllowFailure
                if ($remaining.ExitCode -ne 0) { $cleanupStatus='PASS' } else { $cleanupStatus='FAIL' }
            } catch { $cleanupStatus='FAIL'; if (-not $failure) { $failure=$_.Exception.Message } }
        } else { $cleanupStatus='PASS' }
        $journal.cleanupStatus=$cleanupStatus; $journal.completedAtUtc=[DateTime]::UtcNow.ToString('o'); Write-OctaneJsonAtomic -Path $journalPath -Value $journal
        $watch.Stop()
    }

    if ($scenarioStatus -eq 'PASS' -and $reportValidation -eq 'PASS' -and $evidenceStatus -eq 'PASS' -and $cleanupStatus -eq 'PASS') { $runStatus='PASS' }
    $runResult = [ordered]@{
        schemaVersion=1;runId=$plannedRunId;container=$container;status=$runStatus;lockSha256=$lockHash;scenarioStatus=$scenarioStatus
        reportValidation=$reportValidation;evidenceStatus=$evidenceStatus;cleanupStatus=$cleanupStatus;forcedRepaintUsed=$forcedRepaint
        hiddenRetries=$hiddenRetries;manualOverrides=$manualOverrides;durationMs=[int64]$watch.ElapsedMilliseconds;failure=$failure;evidencePath=[IO.Path]::GetRelativePath($root,$runDirectory).Replace('\','/')
    }
    $runResult | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $runDirectory 'batch-run-result.json') -Encoding utf8
    Update-OctaneEvidenceChecksums -Directory $runDirectory
    $batchRecord = Get-Content -LiteralPath (Join-Path $batchDirectory 'batch.json') -Raw | ConvertFrom-Json -AsHashtable
    $batchRecord.runs += $runResult
    Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch.json') -Value $batchRecord
    Write-Output "$plannedRunId $runStatus scenario=$scenarioStatus report=$reportValidation cleanup=$cleanupStatus"
}

$batchRecord = Get-Content -LiteralPath (Join-Path $batchDirectory 'batch.json') -Raw | ConvertFrom-Json
$assessment = Test-OctaneQualificationBatchRecord -Batch $batchRecord -ExpectedLockHash $lockHash -ExpectedRunCount 10
$batchRecord = Get-Content -LiteralPath (Join-Path $batchDirectory 'batch.json') -Raw | ConvertFrom-Json -AsHashtable
$batchRecord.qualified = $assessment.Qualified
$batchRecord.status = if ($assessment.Qualified) { 'PASS' } else { 'FAIL' }
$batchRecord.completedAtUtc = [DateTime]::UtcNow.ToString('o')
$batchRecord.durationMs = [int64]([DateTime]::UtcNow - $batchStart).TotalMilliseconds
$batchRecord.qualificationReasons = @($assessment.Reasons)
Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch.json') -Value $batchRecord
[ordered]@{schemaVersion=1;batchId=$batchId;lockSha256=$lockHash;qualified=$assessment.Qualified;passed=$assessment.Passed;planned=$assessment.Planned;reasons=@($assessment.Reasons);runs=$batchRecord.runs} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $batchDirectory 'batch-summary.json') -Encoding utf8
Update-OctaneEvidenceChecksums -Directory $batchDirectory
Write-Output "Batch evidence: $batchDirectory"
Write-Output "Result: $($assessment.Passed)/10; qualified=$($assessment.Qualified)"
if (-not $assessment.Qualified) { throw "Qualification batch failed: $($assessment.Reasons -join '; ')" }
