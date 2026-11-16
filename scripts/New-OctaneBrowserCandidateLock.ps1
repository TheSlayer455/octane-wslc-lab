[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{7,40}$')][string]$HarnessCommit,
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][string]$InstallerManifest,
    [Parameter(Mandatory=$true)][string]$ApplicationProfile,
    [Parameter(Mandatory=$true)][string]$DoctorRecord,
    [Parameter(Mandatory=$true)][string]$LiveRunRecord,
    [Parameter(Mandatory=$true)][string]$BrowserEvidence,
    [Parameter(Mandatory=$true)][string]$ComponentEvidence,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$WslDistro='Ubuntu-24.04',
    [string]$InstallerSourceCommit='7088eed9adb8403b9575afe1cc9e9c2984b29049'
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'FileAccess.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'Qualification.ps1')

function Resolve-RequiredFile([string]$Value,[string]$Description){
    $path=[IO.Path]::GetFullPath($Value)
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "$Description not found: $path"}
    return $path
}

$manifestPath=Resolve-RequiredFile $InstallerManifest 'Installer manifest'
$profilePath=Resolve-RequiredFile $ApplicationProfile 'Application profile'
$doctorPath=Resolve-RequiredFile $DoctorRecord 'Doctor record'
$liveRunPath=Resolve-RequiredFile $LiveRunRecord 'Live run record'
$browserPath=Resolve-RequiredFile $BrowserEvidence 'Browser reference result'
$componentPath=Resolve-RequiredFile $ComponentEvidence 'Browser component result'
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$profile=Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$doctor=Get-Content -LiteralPath $doctorPath -Raw | ConvertFrom-Json
$liveRun=Get-Content -LiteralPath $liveRunPath -Raw | ConvertFrom-Json
$browserResult=Get-Content -LiteralPath $browserPath -Raw | ConvertFrom-Json
$component=Get-Content -LiteralPath $componentPath -Raw | ConvertFrom-Json

if($doctor.status -ne 'PASS'){throw 'Browser lock requires a passing doctor record.'}
if([string]$doctor.wslDistro -ne $WslDistro){throw "Doctor record is for $($doctor.wslDistro), not $WslDistro."}
if([string]$liveRun.state -ne 'REMOVED' -or [string]$liveRun.stages.cleanup.status -ne 'PASS'){
    throw 'Browser lock requires a collected exploratory run with exact cleanup already complete.'
}
if([string]$liveRun.browserEndToEndStatus -ne 'PASS' -or [string]$browserResult.status -ne 'PASS'){
    throw 'Browser lock requires an attributable passing browser reference scenario.'
}
if([string]$component.componentStatus -ne 'PASS'){throw 'Browser lock requires passing browser component evidence.'}
if([bool]$browserResult.forcedRepaintUsed -or [int]$browserResult.hiddenRetries -ne 0 -or [int]$browserResult.manualOperatorActions -ne 0 -or [bool]$browserResult.rdpUsed){
    throw 'Exploratory browser evidence violates the unattended/no-RDP/no-repaint contract.'
}

$inspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$Image) -TimeoutSeconds 60
$imageObject=@($inspect.StdOut | ConvertFrom-Json)[0]
$labels=$imageObject.Config.Labels
if($labels.'com.octanelab.browser-transport' -ne 'novnc' -or $labels.'com.octanelab.browser-rdp-required' -ne 'false'){
    throw 'Image is not an identified noVNC/no-RDP browser candidate.'
}
if($labels.'com.octanelab.browser-display-server' -ne 'tigervnc-xvnc'){
    throw 'Browser qualification requires the integrated TigerVNC Xvnc display candidate.'
}
if($labels.'com.octanelab.harness-commit' -ne $HarnessCommit){
    throw "Image harness label '$($labels.'com.octanelab.harness-commit')' does not match $HarnessCommit."
}
if([string]$liveRun.resolvedImageId -ne [string]$imageObject.Id){throw 'Exploratory browser run used a different image ID.'}
if([string]$liveRun.installerSha256 -ne [string]$manifest.sha256){throw 'Exploratory browser run used a different installer.'}

$packageNames=@('curl','git','iproute2','python3-jwcrypto','python3-numpy','python3-redis','python3-requests','tigervnc-standalone-server','tigervnc-tools')
$packageQuery=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments (@('run','--rm','--entrypoint','dpkg-query',$Image,'-W')+$packageNames) -TimeoutSeconds 120
$packageVersions=[ordered]@{}
foreach($line in @($packageQuery.StdOut.Trim() -split "`r?`n")){
    $parts=$line -split "`t",2
    if($parts.Count -eq 2){$packageVersions[$parts[0]]=$parts[1]}
}
if($packageVersions.Count -ne $packageNames.Count){throw 'Unable to record every required browser-image package version.'}

$fixtureManifest=Get-OctaneDirectoryManifest -Path (Join-Path $root 'fixtures')
$fixtureFiles=@($fixtureManifest.files | ForEach-Object {
    [ordered]@{path=('fixtures/'+[string]$_.relativePath).Replace('\','/');length=[int64]$_.length;sha256=[string]$_.sha256}
})
$historicalLock=Join-Path $root 'profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json'
$profileRelative=[IO.Path]::GetRelativePath($root,$profilePath).Replace('\','/')
$manifestRelative=[IO.Path]::GetRelativePath($root,$manifestPath).Replace('\','/')
$browserRelative=[IO.Path]::GetRelativePath($root,$browserPath).Replace('\','/')
$componentRelative=[IO.Path]::GetRelativePath($root,$componentPath).Replace('\','/')
$liveRunRelative=[IO.Path]::GetRelativePath($root,$liveRunPath).Replace('\','/')
$baseReference=[string]$labels.'com.octanelab.browser-base-image-reference'
$baseId=[string]$labels.'com.octanelab.browser-base-image-id'
if(-not $baseReference -or $baseId -notmatch '^sha256:[a-f0-9]{64}$'){throw 'Final image lacks its exact browser base image provenance labels.'}

$value=[ordered]@{
    schemaVersion=1
    kind='browser-candidate-lock'
    status='candidate-ready-for-qualification'
    createdAtUtc=[DateTime]::UtcNow.ToString('o')
    identities=[ordered]@{
        harnessCommit=$HarnessCommit;imageReference=$Image;imageId=[string]$imageObject.Id;imageRepoDigests=@($imageObject.RepoDigests)
        baseImageReference=$baseReference;baseImageId=$baseId
        installerSourceCommit=$InstallerSourceCommit;installerSha256=[string]$manifest.sha256;installerLength=[int64]$manifest.length
        installerManifestPath=$manifestRelative;installerManifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        applicationProfileId=[string]$profile.id;applicationProfilePath=$profileRelative
        applicationProfileSha256=(Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant()
        fixtureFileCount=[int]$fixtureManifest.fileCount
        historicalQualificationLockSha256=(Get-FileHash -LiteralPath $historicalLock -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    harness=[ordered]@{files=@(Get-OctaneBrowserQualificationFileManifest -RepositoryRoot $root)}
    fixtures=[ordered]@{files=$fixtureFiles}
    runtime=[ordered]@{
        architecture=[string]$imageObject.Architecture;wineVersion=[string]$labels.'com.octanelab.wine-version';wineVariant=[string]$labels.'com.octanelab.wine-variant'
        wineSourceCommit=[string]$labels.'com.octanelab.wine-source-commit';wineStagingCommit=[string]$labels.'com.octanelab.wine-staging-commit'
        winePatchSha256=[string]$labels.'com.octanelab.wine-visrgn-patch-sha256';winePrefixArchitecture='win64';windowsVersion='default'
        webView2Distribution=[string]$profile.application.webView2.distribution;expectedWebView2Version=[string]$profile.application.webView2.expectedVersion
        display=':1';displayServer='TigerVNC Xvnc';x11Driver='winex11';desktop='TigerVNC Xvnc/XFCE';resolution='1280x800x24'
        renderer='Mesa llvmpipe (verify per run)';packageVersions=$packageVersions
    }
    browser=[ordered]@{
        transport='noVNC over Websockify to TigerVNC Xvnc';viewerPath='/octane.html'
        noVncCommit=[string]$labels.'com.octanelab.browser-novnc-commit';websockifyCommit=[string]$labels.'com.octanelab.browser-websockify-commit'
        serverResolution='1280x800';remoteResize=$false;clipboard=$false;httpTls=$false
        httpPolicy='plaintext authenticated loopback only; no remote secure-context requirement'
        authentication='per-run random 8-character RFB password file'
        automation=[ordered]@{clientOs=[string]$browserResult.client.os;driver=[string]$browserResult.client.automation;playwright=[string]$browserResult.client.playwright;browser=[string]$browserResult.client.browser}
        upload=[ordered]@{service='Octane authenticated raw-file intake';containerPort=3002;maxBytes=536870912;overwrites=$false;downloads=$false;directoryBrowsing=$false;credential='same per-run credential, browser memory only';originPolicy='exact viewer origins'}
    }
    host=[ordered]@{doctorRecordSha256=(Get-FileHash -LiteralPath $doctorPath -Algorithm SHA256).Hash.ToLowerInvariant();wslDistro=$WslDistro;facts=$doctor.host;runtimeVersion=$doctor.runtimeVersion;context=$doctor.context}
    security=[ordered]@{
        publishedAddress='127.0.0.1 only';publishedPorts=@('authenticated viewer','authenticated scoped upload');rawVncPublished=$false;rdpRequired=$false
        privileged=$false;hostNetwork=$false;dockerSocketMounted=$false;hostGpuMapped=$false;noSandboxAdded=$false;ptraceAdded=$false
        credentialStorage='per-run ignored file, read-only mounted; never included in evidence'
        fileMounts=@('WSL-native disposable home read-write','selected input read-only','uploaded input read-only in application view','upload staging read-write','installer artifact read-only')
    }
    qualification=[ordered]@{
        status='READY';reason='Fresh final-image exploratory run passed browser framebuffer/input, workload, native dialogs, export, component, integrity, and exact-cleanup gates without RDP, forced repainting, relaunch, hidden retries, or manual override.'
        plannedRuns=10;executedRuns=0;historicalRdpBatchIsNotBrowserEvidence=$true
        readiness=[ordered]@{timeoutSeconds=[int]$profile.application.readinessTimeoutSeconds;stabilitySeconds=[int]$profile.application.readinessStabilitySeconds;visualMinColors=[int]$profile.application.visualReadinessMinColors}
        exploratoryEvidence=[ordered]@{
            liveRun=$liveRunRelative;liveRunSha256=(Get-FileHash -LiteralPath $liveRunPath -Algorithm SHA256).Hash.ToLowerInvariant()
            browserResult=$browserRelative;browserResultSha256=(Get-FileHash -LiteralPath $browserPath -Algorithm SHA256).Hash.ToLowerInvariant()
            componentResult=$componentRelative;componentResultSha256=(Get-FileHash -LiteralPath $componentPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        lifecycle='new container, Wine prefix, application install, WebView2 data, and output for every run'
        permittedAutomation='one browser scenario attempt; no application relaunch, repaint helper, manual promotion, or hidden recovery'
    }
}

$output=[IO.Path]::GetFullPath($OutputPath)
Write-OctaneJsonAtomic -Path $output -Value $value
if(-not (Test-Json -Json (Get-Content -LiteralPath $output -Raw) -SchemaFile (Join-Path $root 'schemas/browser-candidate-lock.schema.json'))){throw 'Generated browser candidate lock failed its schema.'}
$hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$output.sha256","$hash  $([IO.Path]::GetFileName($output))`n",[Text.UTF8Encoding]::new($false))
Write-Output "Browser candidate lock: $output"
Write-Output "SHA-256: $hash"
