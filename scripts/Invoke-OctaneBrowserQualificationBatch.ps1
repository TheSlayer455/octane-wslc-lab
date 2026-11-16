[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$LockPath,
    [Parameter(Mandatory=$true)][string]$Installer,
    [string]$ApplicationProfile,
    [string]$InputDirectory,
    [string]$OutputDirectory,
    [string]$WslDistro='Ubuntu-24.04',
    [ValidateRange(1024,65534)][int]$Port=3015,
    [ValidateRange(1025,65535)][int]$UploadPort=3016
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'FileAccess.ps1')
. (Join-Path $PSScriptRoot 'Qualification.ps1')

$lockPathResolved=[IO.Path]::GetFullPath($LockPath)
if(-not (Test-Path -LiteralPath $lockPathResolved -PathType Leaf)){throw "Browser qualification lock not found: $lockPathResolved"}
$lock=Get-Content -LiteralPath $lockPathResolved -Raw | ConvertFrom-Json
if(-not (Test-Json -Json (Get-Content -LiteralPath $lockPathResolved -Raw) -SchemaFile (Join-Path $root 'schemas/browser-candidate-lock.schema.json'))){throw 'Browser qualification lock failed schema validation.'}
Assert-OctaneBrowserQualificationLockFiles -Lock $lock -RepositoryRoot $root
$lockHash=Get-OctaneQualificationLockHash -LockPath $lockPathResolved

$installerPath=[IO.Path]::GetFullPath($Installer)
if(-not (Test-Path -LiteralPath $installerPath -PathType Leaf)){throw "Retained installer not found: $installerPath"}
$installerFile=Get-Item -LiteralPath $installerPath
$installerHash=(Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
if($installerHash -ne [string]$lock.identities.installerSha256 -or $installerFile.Length -ne [int64]$lock.identities.installerLength){throw 'Installer bytes differ from the browser qualification lock.'}

if(-not $ApplicationProfile){$ApplicationProfile=Join-Path $root ([string]$lock.identities.applicationProfilePath)}
$profilePath=[IO.Path]::GetFullPath($ApplicationProfile)
if((Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$lock.identities.applicationProfileSha256){throw 'Application profile differs from the browser qualification lock.'}
if(-not $InputDirectory){$InputDirectory=Join-Path $root 'fixtures'}
$inputPath=[IO.Path]::GetFullPath($InputDirectory)
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'work/browser-qualification-output'}
$operatorOutput=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $operatorOutput -Force | Out-Null

$head=(git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or $head -ne [string]$lock.identities.harnessCommit){throw "Checked-out harness commit $head differs from the lock."}
$imageReference=[string]$lock.identities.imageReference
$imageInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$imageReference) -TimeoutSeconds 60
$image=@($imageInspect.StdOut | ConvertFrom-Json)[0]
if([string]$image.Id -ne [string]$lock.identities.imageId){throw 'Locked browser image is absent or its local image ID drifted.'}
if([string]$image.Config.Labels.'com.octanelab.harness-commit' -ne $head){throw 'Browser image harness label differs from the checked-out locked commit.'}
if([string]$image.Config.Labels.'com.octanelab.browser-display-server' -ne 'tigervnc-xvnc'){throw 'Locked image is not the integrated-Xvnc browser profile.'}
if([string]$image.Config.Labels.'com.octanelab.browser-rdp-required' -ne 'false'){throw 'Locked image unexpectedly requires RDP.'}

if($Port -eq $UploadPort){throw 'Viewer and upload ports must be distinct.'}
if(-not (Test-OctanePortAvailable -Port $Port) -or -not (Test-OctanePortAvailable -Port $UploadPort)){throw 'A locked browser qualification port is already occupied.'}

$batchId='browser-qbatch-'+[Guid]::NewGuid().ToString('N').Substring(0,12)
$batchDirectory=Join-Path $root "evidence/batches/$batchId"
$runsDirectory=Join-Path $batchDirectory 'runs'
New-Item -ItemType Directory -Path $runsDirectory -Force | Out-Null
$plannedRunIds=@(1..10 | ForEach-Object {
    $bytes=[Text.Encoding]::UTF8.GetBytes("$batchId`:$($_.ToString('00'))")
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant().Substring(0,10)
})
$batchStart=[DateTime]::UtcNow
$batch=[ordered]@{
    schemaVersion=1;batchId=$batchId;lockPath=[IO.Path]::GetRelativePath($root,$lockPathResolved).Replace('\','/');lockSha256=$lockHash
    declaredAtUtc=$batchStart.ToString('o');plannedRunIds=$plannedRunIds;contract='Ten sequential fresh containers/prefixes/installations through authenticated noVNC framebuffer and browser-originated input; no RDP, repaint helper, relaunch, hidden retry, manual action, or manual promotion.'
    status='RUNNING';qualified=$false;runs=@()
}
Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch.json') -Value $batch
Copy-Item -LiteralPath $lockPathResolved -Destination (Join-Path $batchDirectory 'browser-qualification-lock.json')

$batchDoctor=Join-Path $batchDirectory 'doctor.json'
& (Join-Path $PSScriptRoot 'Doctor-OctaneLab.ps1') -Engine Docker -WslDistro $WslDistro -Port $Port -Deep -OutputPath $batchDoctor | Out-Null
$doctor=Get-Content -LiteralPath $batchDoctor -Raw | ConvertFrom-Json
if($doctor.status -ne 'PASS' -or [string]$doctor.host.dockerContext -ne [string]$lock.host.facts.dockerContext -or [string]$doctor.host.dockerEndpoint -ne [string]$lock.host.facts.dockerEndpoint){throw 'Qualification doctor detected Docker host/context drift.'}

foreach($runId in $plannedRunIds){
    $container="octane-$runId"
    $runDirectory=Join-Path $runsDirectory $runId
    $componentDirectory=Join-Path $runDirectory 'components'
    $scenarioDirectory=Join-Path $runDirectory 'browser-scenario'
    New-Item -ItemType Directory -Path (Join-Path $runDirectory 'logs') -Force | Out-Null
    $journal=[ordered]@{schemaVersion=1;batchId=$batchId;runId=$runId;container=$container;lockSha256=$lockHash;declaredAtUtc=[DateTime]::UtcNow.ToString('o');startAttempted=$false;scenarioAttempts=0;collectionAttempted=$false;cleanupAttempted=$false}
    Write-OctaneJsonAtomic -Path (Join-Path $runDirectory 'resource-journal.json') -Value $journal
    $scenarioStatus='NOT_RUN';$componentStatus='NOT_RUN';$reportValidation='NOT_RUN';$evidenceStatus='FAIL';$cleanupStatus='NOT_RUN';$status='FAIL';$failure=$null
    $forcedRepaint=$false;$hiddenRetries=0;$manualOverrides=0
    $watch=[Diagnostics.Stopwatch]::StartNew()
    try{
        $journal.startAttempted=$true;Write-OctaneJsonAtomic -Path (Join-Path $runDirectory 'resource-journal.json') -Value $journal
        $startArgs=@{
            Profile=$profilePath;Installer=$installerPath;InputDirectory=$inputPath;OutputDirectory=$operatorOutput;WslDistro=$WslDistro
            Port=$Port;UploadPort=$UploadPort;Image=$imageReference;RunId=$runId;LifecycleMode='Standalone';SkipDeepDoctor=$true
        }
        & (Join-Path $PSScriptRoot 'Start-OctanePreview.ps1') @startArgs *>&1 | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/start.log') -Encoding utf8
        $metadataPath=Join-Path $root "runs/$container.json"
        $run=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        if([string]$run.state -ne 'RUNNING' -or [string]$run.resolvedImageId -ne [string]$lock.identities.imageId -or [string]$run.installerSha256 -ne [string]$lock.identities.installerSha256 -or [string]$run.targetProfileSha256 -ne [string]$lock.identities.applicationProfileSha256){throw 'Fresh preview identity differs from the lock.'}
        if([string]$run.displayServer -ne 'tigervnc-xvnc'){throw 'Fresh preview did not use integrated Xvnc.'}

        & (Join-Path $PSScriptRoot 'Test-OctaneBrowserComponents.ps1') -Container $container -WslDistro $WslDistro -OutputDirectory $componentDirectory *>&1 | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/components.log') -Encoding utf8
        $component=Get-Content -LiteralPath (Join-Path $componentDirectory 'browser-component-results.json') -Raw | ConvertFrom-Json
        $componentStatus=[string]$component.componentStatus

        $journal.scenarioAttempts=1;Write-OctaneJsonAtomic -Path (Join-Path $runDirectory 'resource-journal.json') -Value $journal
        & (Join-Path $PSScriptRoot 'Invoke-OctaneBrowserReferenceScenario.ps1') -Container $container -WslDistro $WslDistro -OutputDirectory $scenarioDirectory *>&1 | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/scenario.log') -Encoding utf8
        $scenario=Get-Content -LiteralPath (Join-Path $scenarioDirectory 'browser-reference-result.json') -Raw | ConvertFrom-Json
        $browserTrace=Get-Content -LiteralPath (Join-Path $scenarioDirectory 'browser-scenario.json') -Raw | ConvertFrom-Json
        $validation=Get-Content -LiteralPath (Join-Path $scenarioDirectory 'report-validation.json') -Raw | ConvertFrom-Json
        $scenarioStatus=[string]$scenario.status
        $reportValidation=[string]$validation.status
        $forcedRepaint=[bool]$browserTrace.forcedRepaintUsed
        $hiddenRetries=[int]$browserTrace.hiddenRetries
        $manualOverrides=[int]$browserTrace.manualOverrides
        if($scenarioStatus -ne 'PASS' -or $reportValidation -ne 'PASS' -or $forcedRepaint -or $hiddenRetries -ne 0 -or $manualOverrides -ne 0 -or [int]$scenario.manualOperatorActions -ne 0 -or [bool]$scenario.rdpUsed){throw 'Browser scenario violated a required unattended gate.'}

        $journal.collectionAttempted=$true;Write-OctaneJsonAtomic -Path (Join-Path $runDirectory 'resource-journal.json') -Value $journal
        & (Join-Path $PSScriptRoot 'Collect-OctanePreview.ps1') -Container $container -WslDistro $WslDistro *>&1 | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/collect.log') -Encoding utf8
        $run=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $required=@(
            (Join-Path $scenarioDirectory 'browser-reference-result.json'),(Join-Path $scenarioDirectory 'browser-qualified-report.json'),
            (Join-Path $scenarioDirectory 'report-validation.json'),(Join-Path $scenarioDirectory 'viewer-events.json'),(Join-Path $scenarioDirectory 'checksums.sha256'),
            (Join-Path $componentDirectory 'browser-component-results.json'),(Join-Path $componentDirectory 'checksums.sha256'),
            [string]$run.previewEvidencePath,[string]$run.previewOutputPath
        )
        $missing=@($required | Where-Object {-not $_ -or -not (Test-Path -LiteralPath $_)})
        $evidenceStatus=if($missing.Count -eq 0 -and [string]$run.stages.workload.status -eq 'PASS' -and [string]$run.stages.export.status -eq 'PASS'){'PASS'}else{'FAIL'}
        if($evidenceStatus -ne 'PASS'){throw "Required collected evidence is missing or incomplete: $($missing -join ', ')"}
    }catch{
        $failure=$_.Exception.Message
        $failure | Set-Content -LiteralPath (Join-Path $runDirectory 'failure.txt') -Encoding utf8
    }finally{
        $metadataPath=Join-Path $root "runs/$container.json"
        if(Test-Path -LiteralPath $metadataPath){
            $current=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
            if($current.resources.PSObject.Properties['containerCreated'] -and [bool]$current.resources.containerCreated -and -not [bool]$current.previewOutputCollected){
                try{
                    $journal.collectionAttempted=$true
                    & (Join-Path $PSScriptRoot 'Collect-OctanePreview.ps1') -Container $container -WslDistro $WslDistro *>&1 | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/failure-collect.log') -Encoding utf8
                }catch{ $_.Exception.Message | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/failure-collect-error.txt') -Encoding utf8 }
            }
            try{
                $journal.cleanupAttempted=$true
                & (Join-Path $PSScriptRoot 'Stop-OctaneLab.ps1') -Container $container -Engine Docker -WslDistro $WslDistro *>&1 | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/cleanup.log') -Encoding utf8
                $after=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
                $inspectAfter=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('inspect',$container) -TimeoutSeconds 30 -AllowFailure
                $cleanupStatus=if([string]$after.state -eq 'REMOVED' -and [string]$after.stages.cleanup.status -eq 'PASS' -and $inspectAfter.ExitCode -ne 0){'PASS'}else{'FAIL'}
            }catch{
                $cleanupStatus='FAIL'
                $_.Exception.Message | Set-Content -LiteralPath (Join-Path $runDirectory 'logs/cleanup-error.txt') -Encoding utf8
                if(-not $failure){$failure=$_.Exception.Message}
            }
        }else{$cleanupStatus='PASS'}
        $journal.completedAtUtc=[DateTime]::UtcNow.ToString('o');$journal.cleanupStatus=$cleanupStatus
        Write-OctaneJsonAtomic -Path (Join-Path $runDirectory 'resource-journal.json') -Value $journal
        $watch.Stop()
    }

    if($scenarioStatus -eq 'PASS' -and $componentStatus -eq 'PASS' -and $reportValidation -eq 'PASS' -and $evidenceStatus -eq 'PASS' -and $cleanupStatus -eq 'PASS' -and -not $failure){$status='PASS'}
    $result=[ordered]@{
        schemaVersion=1;runId=$runId;container=$container;status=$status;lockSha256=$lockHash;scenarioStatus=$scenarioStatus;componentStatus=$componentStatus
        reportValidation=$reportValidation;evidenceStatus=$evidenceStatus;cleanupStatus=$cleanupStatus;forcedRepaintUsed=$forcedRepaint;hiddenRetries=$hiddenRetries;manualOverrides=$manualOverrides
        durationMs=[int64]$watch.ElapsedMilliseconds;failure=$failure;evidencePath=[IO.Path]::GetRelativePath($root,$runDirectory).Replace('\','/')
    }
    Write-OctaneJsonAtomic -Path (Join-Path $runDirectory 'batch-run-result.json') -Value $result
    Update-OctaneEvidenceChecksums -Directory $runDirectory
    $batch=Get-Content -LiteralPath (Join-Path $batchDirectory 'batch.json') -Raw | ConvertFrom-Json -AsHashtable
    $batch.runs += $result
    Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch.json') -Value $batch
    Write-Output "$runId $status scenario=$scenarioStatus component=$componentStatus report=$reportValidation evidence=$evidenceStatus cleanup=$cleanupStatus"
}

$batchObject=Get-Content -LiteralPath (Join-Path $batchDirectory 'batch.json') -Raw | ConvertFrom-Json
$assessment=Test-OctaneQualificationBatchRecord -Batch $batchObject -ExpectedLockHash $lockHash -ExpectedRunCount 10
$batch=Get-Content -LiteralPath (Join-Path $batchDirectory 'batch.json') -Raw | ConvertFrom-Json -AsHashtable
$batch.qualified=$assessment.Qualified;$batch.status=if($assessment.Qualified){'PASS'}else{'FAIL'};$batch.completedAtUtc=[DateTime]::UtcNow.ToString('o')
$batch.durationMs=[int64]([DateTime]::UtcNow-$batchStart).TotalMilliseconds;$batch.qualificationReasons=@($assessment.Reasons)
Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch.json') -Value $batch
$summary=[ordered]@{schemaVersion=1;batchId=$batchId;lockSha256=$lockHash;qualified=$assessment.Qualified;passed=$assessment.Passed;planned=$assessment.Planned;reasons=@($assessment.Reasons);runs=$batch.runs}
Write-OctaneJsonAtomic -Path (Join-Path $batchDirectory 'batch-summary.json') -Value $summary

$xml=[Xml.XmlDocument]::new();[void]$xml.AppendChild($xml.CreateXmlDeclaration('1.0','utf-8',$null));$suite=$xml.CreateElement('testsuite')
$suite.SetAttribute('name','Octane browser qualification');$suite.SetAttribute('tests','10');$suite.SetAttribute('failures',[string](10-$assessment.Passed));$suite.SetAttribute('timestamp',$batchStart.ToString('o'));[void]$xml.AppendChild($suite)
foreach($run in @($batch.runs)){$case=$xml.CreateElement('testcase');$case.SetAttribute('name',[string]$run.runId);$case.SetAttribute('classname','octane.browser.fresh-prefix');if($run.status -ne 'PASS'){$failureNode=$xml.CreateElement('failure');$failureNode.SetAttribute('message',[string]$run.failure);$failureNode.InnerText=if($run.failure){[string]$run.failure}else{"status=$($run.status)"};[void]$case.AppendChild($failureNode)};[void]$suite.AppendChild($case)}
$settings=[Xml.XmlWriterSettings]::new();$settings.Indent=$true;$settings.Encoding=[Text.UTF8Encoding]::new($false);$writer=[Xml.XmlWriter]::Create((Join-Path $batchDirectory 'junit.xml'),$settings);try{$xml.Save($writer)}finally{$writer.Dispose()}
Update-OctaneEvidenceChecksums -Directory $batchDirectory
Write-Output "Batch evidence: $batchDirectory"
Write-Output "Result: $($assessment.Passed)/10; qualified=$($assessment.Qualified)"
if(-not $assessment.Qualified){throw "Browser qualification batch failed: $($assessment.Reasons -join '; ')"}
