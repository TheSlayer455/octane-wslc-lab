[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{7,40}$')][string]$HarnessCommit,
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][string]$InstallerManifest,
    [Parameter(Mandatory=$true)][string]$ApplicationProfile,
    [Parameter(Mandatory=$true)][string]$DoctorRecord,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$WslDistro='Ubuntu-24.04',
    [string]$InstallerSourceCommit='7088eed9adb8403b9575afe1cc9e9c2984b29049'
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'FileAccess.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
$manifestPath=[IO.Path]::GetFullPath($InstallerManifest)
$profilePath=[IO.Path]::GetFullPath($ApplicationProfile)
$doctorPath=[IO.Path]::GetFullPath($DoctorRecord)
foreach($path in @($manifestPath,$profilePath,$doctorPath)){if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Required lock input not found: $path"}}
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$profile=Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$doctor=Get-Content -LiteralPath $doctorPath -Raw | ConvertFrom-Json
if($doctor.status -ne 'PASS'){throw 'Candidate lock requires a passing doctor record.'}
$inspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$Image) -TimeoutSeconds 60
$imageObject=@($inspect.StdOut | ConvertFrom-Json)[0]
$labels=$imageObject.Config.Labels
if($labels.'com.octanelab.browser-transport' -ne 'novnc' -or $labels.'com.octanelab.browser-rdp-required' -ne 'false'){throw 'Image is not the noVNC/no-RDP browser candidate.'}
if($labels.'com.octanelab.harness-commit' -ne $HarnessCommit){throw "Image harness label '$($labels.'com.octanelab.harness-commit')' does not match $HarnessCommit."}
$fixtures=Get-OctaneDirectoryManifest -Path (Join-Path $root 'fixtures')
$fixtureComparable=@($fixtures.files | ForEach-Object {[ordered]@{relativePath=[string]$_.relativePath;length=[int64]$_.length;sha256=[string]$_.sha256}}) | ConvertTo-Json -Depth 10 -Compress
$fixtureHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($fixtureComparable))).ToLowerInvariant()
$historicalLock=Join-Path $root 'profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json'
$value=[ordered]@{
    schemaVersion=1;kind='browser-candidate-lock';status='candidate-end-to-end-blocked';createdAtUtc=[DateTime]::UtcNow.ToString('o')
    identities=[ordered]@{
        harnessCommit=$HarnessCommit;imageReference=$Image;imageId=[string]$imageObject.Id;imageRepoDigests=@($imageObject.RepoDigests)
        baseImageReference='octane-lab:qualification-7181a47ee47a';baseImageId='sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c'
        installerSourceCommit=$InstallerSourceCommit;installerSha256=[string]$manifest.sha256;installerLength=[int64]$manifest.length
        applicationProfileId=[string]$profile.id;applicationProfileSha256=(Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant()
        fixtureManifestSha256=$fixtureHash;fixtureFileCount=[int]$fixtures.fileCount
        historicalQualificationLockSha256=(Get-FileHash -LiteralPath $historicalLock -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    runtime=[ordered]@{
        architecture=[string]$imageObject.Architecture;wineVersion=[string]$labels.'com.octanelab.wine-version';wineVariant=[string]$labels.'com.octanelab.wine-variant'
        wineSourceCommit=[string]$labels.'com.octanelab.wine-source-commit';wineStagingCommit=[string]$labels.'com.octanelab.wine-staging-commit'
        winePatchSha256=[string]$labels.'com.octanelab.wine-visrgn-patch-sha256';winePrefixArchitecture='win64';windowsVersion='default'
        webView2Distribution=[string]$profile.application.webView2.distribution;expectedWebView2Version=[string]$profile.application.webView2.expectedVersion
        display=':1';x11Driver='winex11';desktop='Xvfb/XFCE';resolution='1280x800x24';renderer='Mesa llvmpipe (reference expectation; recheck per run)'
    }
    browser=[ordered]@{
        transport='noVNC over Websockify to x11vnc';viewerPath='/octane.html';noVncCommit=[string]$labels.'com.octanelab.browser-novnc-commit'
        websockifyCommit=[string]$labels.'com.octanelab.browser-websockify-commit';serverResolution='1280x800';remoteResize=$false;clipboard=$false
        httpTls=$false;httpPolicy='plaintext localhost only; noVNC does not require a remote secure context in this profile';authentication='per-run 8-character RFB password file'
        browserIdentity=$null;browserAutomation='BLOCKED — no approved controllable browser was available'
    }
    host=[ordered]@{doctorRecordSha256=(Get-FileHash -LiteralPath $doctorPath -Algorithm SHA256).Hash.ToLowerInvariant();facts=$doctor.host;runtimeVersion=$doctor.runtimeVersion;context=$doctor.context}
    security=[ordered]@{
        publishedAddress='127.0.0.1 only';publishedPorts=@('viewer only');rawVncPublished=$false;rdpRequired=$false
        privileged=$false;hostNetwork=$false;dockerSocketMounted=$false;hostGpuMapped=$false;noSandboxAdded=$false;ptraceAdded=$false
        credentialStorage='per-run ignored file, read-only mounted; retrieved to clipboard by explicit operator action'
    }
    qualification=[ordered]@{
        status='BLOCKED';reason='Approved browser control was unavailable; VNC negotiation, framebuffer delivery, browser-originated input, and 10/10 acceptance were not executed.'
        plannedRuns=10;executedRuns=0;manualSmoke='NOT_RUN';historicalRdpBatchIsNotBrowserEvidence=$true
    }
}
$output=[IO.Path]::GetFullPath($OutputPath)
Write-OctaneJsonAtomic -Path $output -Value $value
if(-not (Test-Json -Json (Get-Content -LiteralPath $output -Raw) -SchemaFile (Join-Path $root 'schemas/browser-candidate-lock.schema.json'))){throw 'Generated browser candidate lock failed its schema.'}
$hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$output.sha256","$hash  $([IO.Path]::GetFileName($output))`n",[Text.UTF8Encoding]::new($false))
Write-Output "Browser candidate lock: $output"
Write-Output "SHA-256: $hash"
