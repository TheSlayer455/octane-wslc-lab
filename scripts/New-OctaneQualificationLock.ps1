[CmdletBinding()]
param(
    [string]$WslDistro = 'Ubuntu-24.04',
    [string]$LockPath,
    [string]$ImageTag,
    [string]$ExpectedWebView2Version = '157.0.4341.60'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $LockPath) { $LockPath = Join-Path $root 'profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json' }
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'Qualification.ps1')

$gitStatus = & git -C $root status --porcelain=v1
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect Git status.' }
if (@($gitStatus).Count -ne 0) { throw 'Commit or otherwise reconcile project changes before freezing a qualification lock.' }
$commit = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[a-f0-9]{40}$') { throw 'Unable to identify the harness commit.' }
$shortCommit = $commit.Substring(0,12)
if (-not $ImageTag) { $ImageTag = "octane-lab:qualification-$shortCommit" }

$profile = Get-OctaneWineProfile -WineProfile DockerWineStaging1121VisRgn
$installerPath = Join-Path $root 'artifacts/Octane-setup.exe'
$manifestPath = Join-Path $root 'artifacts/installer-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($installerHash -ne ([string]$manifest.sha256).ToLowerInvariant()) { throw 'Installer does not match its manifest.' }

$doctorPath = Join-Path $root "runs/qualification-lock-$shortCommit-doctor.json"
$doctor = (& (Join-Path $PSScriptRoot 'Doctor-OctaneLab.ps1') -Engine Docker -WslDistro $WslDistro -Port 3394 -Deep -OutputPath $doctorPath | ConvertFrom-Json)
$runtimeRoot = ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $root
$runtimeDockerfile = ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path (Join-Path $root $profile.Dockerfile)
$buildArguments = [Collections.Generic.List[string]]::new()
foreach ($argument in @('build','--build-arg',"BASE_IMAGE=$($profile.BaseImage)")) { $buildArguments.Add($argument) }
foreach ($entry in $profile.BuildArguments.GetEnumerator()) {
    foreach ($argument in @('--build-arg',"$($entry.Key)=$($entry.Value)")) { $buildArguments.Add($argument) }
}
foreach ($argument in @('-f',$runtimeDockerfile,'-t',$ImageTag,$runtimeRoot)) { $buildArguments.Add($argument) }
$build = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments $buildArguments.ToArray() -TimeoutSeconds $profile.BuildTimeoutSeconds
$imageInspect = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$ImageTag) -TimeoutSeconds 60
$image = @($imageInspect.StdOut | ConvertFrom-Json)[0]

$embeddedCommand = @'
jq -cn \
  --slurpfile wine /opt/octane-wine/share/octane/wine-build.json \
  --arg wineVersion "$(wine --version)" \
  --arg architecture "$(uname -m)" \
  --arg wineBuildSha256 "$(sha256sum /opt/octane-wine/share/octane/wine-build.json | cut -d' ' -f1)" \
  --arg stagingListSha256 "$(sha256sum /opt/octane-wine/share/octane/wine-staging-patches.sha256 | cut -d' ' -f1)" \
  --arg win32uSha256 "$(sha256sum /opt/octane-wine/lib/wine/x86_64-unix/win32u.so | cut -d' ' -f1)" \
  --arg ole32Sha256 "$(sha256sum /opt/octane-wine/lib/wine/x86_64-windows/ole32.dll | cut -d' ' -f1)" \
  '{wineBuild:$wine[0],wineVersion:$wineVersion,architecture:$architecture,wineBuildSha256:$wineBuildSha256,stagingListSha256:$stagingListSha256,win32uSha256:$win32uSha256,ole32Sha256:$ole32Sha256}'
'@
$embeddedResult = Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @(
    'run','--rm','--label','com.octanelab.managed=true','--label','com.octanelab.purpose=qualification-lock-inspection',
    '--entrypoint','/bin/bash',$ImageTag,'-lc',$embeddedCommand
) -TimeoutSeconds 120
$embedded = $embeddedResult.StdOut | ConvertFrom-Json

$wslVersionResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('--version') -TimeoutSeconds 30
$distroResult = Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('-d',$WslDistro,'--exec','bash','-lc','source /etc/os-release; printf "%s|%s|%s" "$PRETTY_NAME" "$(uname -r)" "$(uname -m)"') -TimeoutSeconds 30
$distroParts = $distroResult.StdOut.Trim().Split('|')
$dockerContext = (Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('context','show') -TimeoutSeconds 30).StdOut.Trim()
$dockerVersion = (Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('version','--format','{{.Server.Version}}') -TimeoutSeconds 30).StdOut.Trim()
$dockerInfo = (Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('info','--format','{{json .}}') -TimeoutSeconds 60).StdOut | ConvertFrom-Json

$fixtureFiles = Get-ChildItem -LiteralPath (Join-Path $root 'fixtures') -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();bytes=$_.Length}
}
$harnessFiles = @(Get-OctaneQualificationFileManifest -RepositoryRoot $root)
$lock = [ordered]@{
    schemaVersion = 1
    frozenAtUtc = [DateTime]::UtcNow.ToString('o')
    technicalFeasibility = 'conditionally demonstrated'
    fullAcceptanceAtFreeze = 'intermittent, not yet qualified'
    artifact = [ordered]@{
        installerPath = 'artifacts/Octane-setup.exe'
        installerSha256 = $installerHash
        manifestSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        sourceCommit = [string]$manifest.sourceCommit
        installedExecutableSha256 = 'cd7c688df064c1b340e0a0a2d12b1a072e52144fa22c04bfa28693148a767b84'
    }
    harness = [ordered]@{commitAtFreeze=$commit;files=$harnessFiles}
    image = [ordered]@{
        reference=$ImageTag;id=[string]$image.Id;baseReference=$profile.BaseImage;resolvedBaseImage=(Get-OctaneImageDigest -Engine Docker -WslDistro $WslDistro -Image $profile.BaseImage)
        architecture='linux/amd64';dockerfile=$profile.Dockerfile;buildArguments=$profile.BuildArguments;buildDurationMs=$build.DurationMs
    }
    profile = [ordered]@{
        name=$profile.Name;wine=$embedded;prefixArchitecture='win64';windowsVersion='default';dllOverrides='mscoree,mshtml='
        webView2=[ordered]@{distributionMode='Evergreen offline installer';expectedLoadedVersion=$ExpectedWebView2Version;expectedPathFragment="Microsoft\EdgeWebView\Application\$ExpectedWebView2Version\msedgewebview2.exe"}
        display=[ordered]@{driver='winex11';desktop='XFCE/Xorgxrdp';resolution='1280x800';rendererContains='llvmpipe';dpi=96;hostGpuPassthrough=$false}
        resources=[ordered]@{shmSize='1gb';cpuLimit=$null;memoryLimit=$null}
        browserArguments=[ordered]@{expectedMainProcess=@('--disable-gpu');observedFromProcessCommandLine=$true}
    }
    host = [ordered]@{
        windowsVersion=[Environment]::OSVersion.Version.ToString();wslVersionText=$wslVersionResult.StdOut.Trim();wslDistro=$WslDistro
        distroPrettyName=$distroParts[0];kernel=$distroParts[1];architecture=$distroParts[2]
        docker=[ordered]@{context=$dockerContext;serverVersion=$dockerVersion;operatingSystem=[string]$dockerInfo.OperatingSystem;rootless=([string]$dockerInfo.SecurityOptions -match 'rootless');daemonLocation='inside selected WSL distribution'}
        doctorContext=$doctor.context
    }
    fixtures = [ordered]@{expected=[ordered]@{files=8;extensionGroups=6;duplicateSets=1;errors=0;totalBytes=176};files=@($fixtureFiles)}
    security = [ordered]@{desktopBinding='127.0.0.1 only';authenticated=$true;privileged=$false;hostNetwork=$false;dockerSocketMount=$false;hostGpuMapping=$false;noSandboxArgument=$false;rdpCertificateAccommodation='FreeRDP /cert:ignore for container self-signed certificate on loopback only'}
    automation = [ordered]@{unattended=$true;forcedRepaintAllowed=$false;hiddenRetriesAllowed=0;manualOverridesAllowed=0;initialPresentationTimeoutSeconds=45;scenarioTimeoutSeconds=900}
    contract = [ordered]@{schemaVersion=2;plannedRuns=10;freshContainer=$true;freshWinePrefix=$true;freshWebView2UserData=$true;sequential=$true}
}
$parent = Split-Path $LockPath -Parent
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$lock | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $LockPath -Encoding utf8
$lockHash = Get-OctaneQualificationLockHash -LockPath $LockPath
"$lockHash  $([IO.Path]::GetFileName($LockPath))" | Set-Content -LiteralPath "$LockPath.sha256" -Encoding ascii
Write-Output "Qualification lock: $LockPath"
Write-Output "SHA-256: $lockHash"
Write-Output "Image: $ImageTag ($($image.Id))"
