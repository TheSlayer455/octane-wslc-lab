[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Profile,
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$InputDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$WslDistro='Ubuntu-24.04',
    [ValidateRange(1024,65535)][int]$Port=3001,
    [string]$Image='octane-lab:browser-novnc-dev',
    [string]$BuildLabel,
    [ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ProducerSha256,
    [string]$Provenance,
    [switch]$OpenBrowser,
    [switch]$SkipDeepDoctor
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
. (Join-Path $PSScriptRoot 'FileAccess.ps1')
$profilePath=[IO.Path]::GetFullPath($Profile)
$profileResult=& (Join-Path $PSScriptRoot 'Test-OctaneTargetProfile.ps1') -Profile $profilePath -Operational
$profileValue=Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$inputPath=[IO.Path]::GetFullPath($InputDirectory)
$outputPath=[IO.Path]::GetFullPath($OutputDirectory)
if(-not (Test-Path -LiteralPath $inputPath -PathType Container)){throw "Input directory not found: $inputPath"}
if($outputPath -eq $inputPath -or $outputPath.StartsWith($inputPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Output directory must be separate from and outside the read-only input tree.'
}
foreach($item in Get-ChildItem -LiteralPath $inputPath -Recurse -Force){
    if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Input contains a symlink or junction, which copy mode rejects: $($item.FullName)"}
}
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
if(-not (Test-OctanePortAvailable -Port $Port)){throw "Loopback port $Port is already in use."}

$artifactRoot=Join-Path $root 'runs/artifacts'
$stageArguments=@{Installer=$Installer;OutputDirectory=$artifactRoot}
if($BuildLabel){$stageArguments.BuildLabel=$BuildLabel}
if($ProducerSha256){$stageArguments.ProducerSha256=$ProducerSha256}
if($Provenance){$stageArguments.Provenance=$Provenance}
$artifact=& (Join-Path $PSScriptRoot 'Stage-OctaneArtifact.ps1') @stageArguments
$id=[Guid]::NewGuid().ToString('N').Substring(0,10)
$name="octane-$id"
$runs=Join-Path $root 'runs'
$statePath=Join-Path $runs "$name.json"
$doctorPath=Join-Path $runs "$name-doctor.json"
$secretDirectory=Join-Path $runs "secrets/$name"
$password=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(4)).ToLowerInvariant()
New-Item -ItemType Directory -Path $secretDirectory -Force | Out-Null
$secretPath=Join-Path $secretDirectory 'viewer-password'
[IO.File]::WriteAllText($secretPath,$password,[Text.UTF8Encoding]::new($false))
$runtimeSecretCreated=$false
$inputManifestPath=Join-Path $runs "$name-input-manifest.json"
$inputManifest=Get-OctaneDirectoryManifest -Path $inputPath
Write-OctaneJsonAtomic -Path $inputManifestPath -Value $inputManifest

function Wait-OctanePreviewEndpoint([string]$Container,[int]$Port,[int]$TimeoutSeconds){
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds){
        $state=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('inspect','--format','{{.State.Running}} {{.State.ExitCode}}',$Container) -TimeoutSeconds 15 -AllowFailure
        if($state.ExitCode -ne 0){throw "Container $Container disappeared while its viewer was starting."}
        if($state.StdOut.Trim() -match '^false\s+(\d+)$'){
            $logs=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('logs','--tail','40',$Container) -TimeoutSeconds 15 -AllowFailure
            throw "Container $Container exited with code $($Matches[1]) before the viewer became ready. $($logs.StdErr.Trim()) $($logs.StdOut.Trim())"
        }
        try{
            $response=Invoke-WebRequest -Uri "http://127.0.0.1:$Port/octane.html" -SkipHttpErrorCheck -TimeoutSec 5
            if($response.StatusCode -eq 200){$watch.Stop();return [int64]$watch.ElapsedMilliseconds}
        }catch{}
        Start-Sleep -Milliseconds 500
    }
    throw "Browser viewer on 127.0.0.1:$Port/octane.html did not become reachable within $TimeoutSeconds seconds."
}

Initialize-OctaneRunState -Path $statePath -Identity @{
    runId=$id;container=$name;image=$Image;engine='Docker';engineContext="docker:wsl:$WslDistro";wslDistro=$WslDistro
    wineProfile='DockerWineStaging1121VisRgnBrowser';baseImage=$Image;port=$Port;endpointKind='Http';installerSha256=$artifact.sha256
} | Out-Null
Set-OctaneRunMetadata -Path $statePath -Values @{
    targetPreview=$true;targetId=$profileResult.id;targetProfileSha256=$profileResult.profileSha256
    artifactId=$artifact.artifactId;artifactManifest=$artifact.manifestPath;operatorOutputDirectory=$outputPath
    browserEndToEndStatus='BLOCKED';browserEndToEndReason='Requires an approved browser path or separately recorded operator evidence.'
    viewerPath='/octane.html';viewerTransport='noVNC';fileAccessMode='copy';inputSource=$inputPath
    inputManifestPath=$inputManifestPath;inputManifestSha256=(Get-FileHash -LiteralPath $inputManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

$activeStage='artifact'
try{
    Update-OctaneRunStage -Path $statePath -Stage artifact -Status PASS -Detail "Staged immutable $($artifact.artifactId); source and staged hashes agree."
    $activeStage='runtimeDoctor'
    $doctorArgs=@{Engine='Docker';WslDistro=$WslDistro;Port=$Port;OutputPath=$doctorPath}
    if(-not $SkipDeepDoctor){$doctorArgs.Deep=$true}
    & (Join-Path $PSScriptRoot 'Doctor-OctaneLab.ps1') @doctorArgs | Out-Null
    Update-OctaneRunStage -Path $statePath -Stage runtimeDoctor -Status PASS -Detail "Docker daemon explicitly selected in WSL distribution $WslDistro."

    $imageInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$Image) -TimeoutSeconds 60
    $imageObject=@($imageInspect.StdOut | ConvertFrom-Json)[0]
    if($imageObject.Config.Labels.'com.octanelab.browser-transport' -ne 'novnc' -or $imageObject.Config.Labels.'com.octanelab.browser-rdp-required' -ne 'false'){
        throw 'Selected image is not an identified noVNC browser candidate.'
    }
    $activeStage='imageBuild'
    Update-OctaneRunStage -Path $statePath -Stage imageBuild -Status PASS -Detail "Reused prebuilt browser image $Image ($($imageObject.Id)); no application prefix was cached."
    Set-OctaneRunMetadata -Path $statePath -Values @{resolvedImageId=[string]$imageObject.Id;resolvedBaseImage=[string]$imageObject.Id}

    $runtimeSecret=New-OctaneRuntimeSecretFile -Engine Docker -WslDistro $WslDistro -Container $name -Secret $password -ControllerPath $secretPath
    $runtimeSecretCreated=$true
    $runArgs=@(
        'run','-d','--name',$name,
        '--label','com.octanelab.managed=true','--label','com.octanelab.engine=docker','--label','com.octanelab.profile=DockerWineStaging1121VisRgnBrowser',
        '--label',"com.octanelab.run=$id",'--label',"com.octanelab.target=$($profileResult.id)",
        '--shm-size=1gb','-p',"127.0.0.1:${Port}:3000",'--platform','linux/amd64',
        '--mount',"type=bind,src=$runtimeSecret,dst=/run/octane/viewer-password,readonly",
        '-e','TZ=America/Chicago','-e','RDP_SERVER=no','-e','USE_XVFB=yes','-e','USER_SUDO=no','-e',"OCTANE_RUN_ID=$id",
        '-e',"OCTANE_VIEWER_ORIGINS=http://127.0.0.1:$Port http://localhost:$Port",$Image
    )
    $activeStage='containerCreate'
    $created=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments $runArgs -TimeoutSeconds 180
    Set-OctaneRunResource -Path $statePath -Resource containerCreated -Value $true
    Update-OctaneRunStage -Path $statePath -Stage containerCreate -Status PASS -Detail "Created fresh container $name with one loopback browser publication and one read-only distro-local credential-file bind."
    Set-OctaneRunMetadata -Path $statePath -Values @{containerId=$created.StdOut.Trim()}

    $activeStage='desktopEndpoint'
    $endpointMs=Wait-OctanePreviewEndpoint -Container $name -Port $Port -TimeoutSeconds 240
    $address="http://127.0.0.1:$Port/octane.html"
    Update-OctaneRunStage -Path $statePath -Stage desktopEndpoint -Status PASS -Detail "Viewer page returned HTTP at $address; VNC negotiation and browser rendering remain separate gates." -DurationMs $endpointMs

    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','root',$name,'bash','-lc','mkdir -p /home/wineuser/.octane/target/artifact /home/wineuser/.octane/input /home/wineuser/.octane/output && chown -R wineuser:wineuser /home/wineuser/.octane') -TimeoutSeconds 60 | Out-Null
    $runtimeProfile=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $profilePath
    $runtimeArtifact=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $artifact.artifactPath
    $runtimeManifest=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $artifact.manifestPath
    $runtimeInput=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $inputPath
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',$runtimeProfile,"$name`:/home/wineuser/.octane/target/app.json") -TimeoutSeconds 120 | Out-Null
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',$runtimeArtifact,"$name`:/home/wineuser/.octane/target/artifact/$([IO.Path]::GetFileName($artifact.artifactPath))") -TimeoutSeconds 600 | Out-Null
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',$runtimeManifest,"$name`:/home/wineuser/.octane/target/artifact/$([IO.Path]::GetFileName($artifact.manifestPath))") -TimeoutSeconds 120 | Out-Null
    if(@(Get-ChildItem -LiteralPath $inputPath -Force).Count -gt 0){
        Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',"$runtimeInput/.","$name`:/home/wineuser/.octane/input") -TimeoutSeconds 600 | Out-Null
    }
    $inputAfterCopy=Get-OctaneDirectoryManifest -Path $inputPath
    Assert-OctaneDirectoryManifest -Expected $inputManifest -Actual $inputAfterCopy -Context 'Host input changed while it was being staged.'
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','root',$name,'chown','-R','wineuser:wineuser','/home/wineuser/.octane') -TimeoutSeconds 120 | Out-Null

    $activeStage='installer'
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$name,'octane-target','prepare') -TimeoutSeconds 300 | Out-Null
    $install=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$name,'octane-target','install') -TimeoutSeconds ([int]$profileValue.installer.timeoutSeconds+60)
    Update-OctaneRunStage -Path $statePath -Stage installer -Status PASS -Detail 'Unchanged staged installer completed with a profile-approved exit code in the fresh Wine prefix.' -DurationMs $install.DurationMs
    $activeStage='application'
    Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-d','-u','wineuser',$name,'octane-target','launch') -TimeoutSeconds 60 | Out-Null
    $native=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$name,'octane-target','wait-native') -TimeoutSeconds ([int]$profileValue.application.readinessTimeoutSeconds+30)
    if([bool]$profileValue.application.webView2.required){
        $webview=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$name,'octane-target','webview2') -TimeoutSeconds 120
        Update-OctaneRunStage -Path $statePath -Stage webviewDiagnostic -Status PASS -Detail 'The required loaded WebView2 browser process, version, executable path, and hash were recorded. This is not browser rendering evidence.' -DurationMs $webview.DurationMs
    }else{
        Update-OctaneRunStage -Path $statePath -Stage webviewDiagnostic -Status NOT_RUN -Detail 'The application profile does not require WebView2.'
    }
    Update-OctaneRunStage -Path $statePath -Stage application -Status BLOCKED -Detail 'A matching native X11 window was observed, but browser delivery, visible client rendering, and browser-originated input require approved/manual browser evidence.' -DurationMs $native.DurationMs
    $network=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$name,'octane-target','probe-network') -TimeoutSeconds 120 -AllowFailure
    $endpointCount=@($profileValue.network.requiredEndpoints).Count
    $networkStatus=if($endpointCount -eq 0){'NOT_TESTED'}elseif($network.ExitCode -eq 0 -and -not $network.TimedOut){'PASS'}else{'FAIL'}
    Set-OctaneRunMetadata -Path $statePath -Values @{desktopAddress=$address;stateDirectory='/home/wineuser/.octane';evidenceDirectory='/home/wineuser/.octane/evidence';networkProbeExitCode=$network.ExitCode;networkCapabilityStatus=$networkStatus}
    Set-OctaneRunState -Path $statePath -State RUNNING

    Write-Output "Container: $name"
    Write-Output "Run ID: $id"
    Write-Output "Target: $($profileResult.id)"
    Write-Output "Artifact: $($artifact.artifactId)"
    Write-Output "Viewer: $address"
    Write-Output "Credential: ./scripts/Get-OctaneViewerCredential.ps1 -Container $name"
    Write-Output 'Status: candidate implemented; browser end-to-end validation and unattended qualification blocked by unavailable approved browser automation.'
    Write-Output "Run metadata: $statePath"
    if($OpenBrowser){Start-Process $address}
}catch{
    try{Update-OctaneRunStage -Path $statePath -Stage $activeStage -Status FAIL -Detail $_.Exception.Message}catch{}
    try{Block-OctaneRunStages -Path $statePath -Detail "Blocked after $activeStage failed."}catch{}
    $record=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if(-not $record.resources.containerCreated){
        if($runtimeSecretCreated){try{Remove-OctaneRuntimeSecretFile -Engine Docker -WslDistro $WslDistro -Container $name}catch{}}
        Remove-Item -LiteralPath $secretDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw "Preview start failed at $activeStage. Any created container was retained under exact run identity $name for collection and diagnosis. $($_.Exception.Message)"
}
