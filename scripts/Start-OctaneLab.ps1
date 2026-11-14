[CmdletBinding()]
param(
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Wslc',
    [string]$WslDistro,
    [ValidateSet('WineGui','DockerWine','WineGuiOle32Control','WineGuiOle32Mr12477','DockerWineStaging1121Control','DockerWineStaging1121VisRgn','DockerWineStaging1121VisRgnBrowser')][string]$WineProfile = 'WineGui',
    [ValidateRange(1024,65535)][int]$Port = 3001,
    [string]$BaseImage,
    [ValidateRange(30,900)][int]$StartupTimeoutSeconds = 240,
    [switch]$SkipDeepDoctor,
    [switch]$OpenBrowser
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')

$profile = Get-OctaneWineProfile -WineProfile $WineProfile -BaseImage $BaseImage
$id = [Guid]::NewGuid().ToString('N').Substring(0,10)
$name = "octane-$id"
$image = "octane-lab:$id"
$runs = Join-Path $root 'runs'
$statePath = Join-Path $runs "$name.json"
$doctorPath = Join-Path $runs "$name-doctor.json"
$runtimeContext = (Get-OctaneRuntimeCommand -Engine $Engine -WslDistro $WslDistro).Context
$manifestPath = Join-Path $root 'artifacts/installer-manifest.json'
$installerPath = Join-Path $root 'artifacts/Octane-setup.exe'
$manifest = if (Test-Path -LiteralPath $manifestPath) { Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } else { $null }
$expectedHash = if ($manifest) { [string]$manifest.sha256 } else { $null }
$viewerSecretDirectory = $null
$viewerPassword = $null

if ($profile.ProfileKind -eq 'DockerWineBrowser' -and $Engine -ne 'Docker') {
    throw 'The browser candidate is a Docker-only profile. Historical WSLC support remains separate.'
}

Initialize-OctaneRunState -Path $statePath -Identity @{
    runId=$id;container=$name;image=$image;engine=$Engine;engineContext=$runtimeContext
    wslDistro=if($WslDistro){$WslDistro}else{$null};wineProfile=$WineProfile;baseImage=$profile.BaseImage;port=$Port
    endpointKind=$profile.EndpointKind;installerSha256=$expectedHash
} | Out-Null
Set-OctaneRunMetadata -Path $statePath -Values @{
    wineExperiment=$profile.Experiment
    imageBuildArguments=$profile.BuildArguments
}

$activeStage = 'artifact'
try {
    if (-not (Test-Path -LiteralPath $installerPath)) { throw 'Build or download the installer to artifacts/Octane-setup.exe first.' }
    if (-not $manifest) { throw 'Place the matching artifacts/installer-manifest.json beside the installer.' }
    $actual = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expectedHash.ToLowerInvariant()) { throw 'Installer hash does not match manifest.' }
    Update-OctaneRunStage -Path $statePath -Stage artifact -Status PASS -Detail "SHA-256 $actual"

    $activeStage = 'runtimeDoctor'
    $doctorArguments = @{Engine=$Engine;WslDistro=$WslDistro;Port=$Port;OutputPath=$doctorPath}
    if (-not $SkipDeepDoctor) { $doctorArguments.Deep = $true }
    $doctorJson = & (Join-Path $PSScriptRoot 'Doctor-OctaneLab.ps1') @doctorArguments
    $doctor = ($doctorJson -join "`n") | ConvertFrom-Json
    Update-OctaneRunStage -Path $statePath -Stage runtimeDoctor -Status PASS -Detail "$($doctor.context); runtime $($doctor.runtimeVersion)"

    $activeStage = 'imageBuild'
    $runtimeRoot = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $root
    $runtimeDockerfile = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path (Join-Path $root $profile.Dockerfile)
    $buildArguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in @('build','--build-arg',"BASE_IMAGE=$($profile.BaseImage)")) { $buildArguments.Add($argument) }
    foreach ($entry in $profile.BuildArguments.GetEnumerator()) {
        foreach ($argument in @('--build-arg',"$($entry.Key)=$($entry.Value)")) { $buildArguments.Add($argument) }
    }
    foreach ($argument in @('-f',$runtimeDockerfile,'-t',$image,$runtimeRoot)) { $buildArguments.Add($argument) }
    $build = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $buildArguments.ToArray() -TimeoutSeconds $profile.BuildTimeoutSeconds
    Set-OctaneRunResource -Path $statePath -Resource imageCreated -Value $true
    $baseDigest = Get-OctaneImageDigest -Engine $Engine -WslDistro $WslDistro -Image $profile.BaseImage
    Set-OctaneRunMetadata -Path $statePath -Values @{resolvedBaseImage=$baseDigest}
    $buildDetail = "Built $image from $($profile.BaseImage)"
    if ($profile.Experiment) { $buildDetail += "; $($profile.Experiment)" }
    Update-OctaneRunStage -Path $statePath -Stage imageBuild -Status PASS -Detail $buildDetail -DurationMs $build.DurationMs

    $passwordBytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
    $password = [Convert]::ToBase64String($passwordBytes)
    $runArguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in @('run','-d','--name',$name,'--label','com.octanelab.managed=true','--label',"com.octanelab.engine=$($Engine.ToLowerInvariant())",'--label',"com.octanelab.profile=$WineProfile",'--shm-size=1gb','-p',"127.0.0.1:${Port}:$($profile.ContainerPort)",'-e','TZ=America/Chicago')) { $runArguments.Add($argument) }
    if ($profile.ProfileKind -eq 'WineGui') {
        foreach ($argument in @('-e','CUSTOM_USER=octane','-e',"PASSWORD=$password")) { $runArguments.Add($argument) }
    } elseif ($profile.ProfileKind -eq 'DockerWineBrowser') {
        $viewerPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(4)).ToLowerInvariant()
        $viewerSecretDirectory = Join-Path $runs "secrets/$name"
        New-Item -ItemType Directory -Path $viewerSecretDirectory -Force | Out-Null
        $viewerSecretPath = Join-Path $viewerSecretDirectory 'viewer-password'
        [IO.File]::WriteAllText($viewerSecretPath,$viewerPassword,[Text.UTF8Encoding]::new($false))
        $runtimeSecretPath = ConvertTo-OctaneRuntimePath -Engine $Engine -WslDistro $WslDistro -Path $viewerSecretPath
        foreach ($argument in @(
            '--platform','linux/amd64','--mount',"type=bind,src=$runtimeSecretPath,dst=/run/octane/viewer-password,readonly",
            '-e','RDP_SERVER=no','-e','USE_XVFB=yes','-e','USER_SUDO=no','-e',"OCTANE_RUN_ID=$id",
            '-e',"OCTANE_VIEWER_ORIGINS=http://127.0.0.1:$Port http://localhost:$Port"
        )) { $runArguments.Add($argument) }
    } else {
        $passwordHash = New-OctaneUnixPasswordHash -Password $password -WslDistro $WslDistro
        foreach ($argument in @('--platform','linux/amd64','-e','RDP_SERVER=yes','-e','USER_SUDO=no','-e',"USER_PASSWD=$passwordHash")) { $runArguments.Add($argument) }
    }
    $runArguments.Add($image)

    $activeStage = 'containerCreate'
    $run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $runArguments.ToArray() -TimeoutSeconds 180
    Set-OctaneRunResource -Path $statePath -Resource containerCreated -Value $true
    Update-OctaneRunStage -Path $statePath -Stage containerCreate -Status PASS -Detail "Created with $Engine using profile $WineProfile" -DurationMs $run.DurationMs

    $activeStage = 'desktopEndpoint'
    $endpointPath = if ($profile.PSObject.Properties['EndpointPath']) { [string]$profile.EndpointPath } else { '/' }
    $endpointMs = Wait-OctaneEndpoint -Kind $profile.EndpointKind -Port $Port -Path $endpointPath -TimeoutSeconds $StartupTimeoutSeconds
    $address = if ($profile.EndpointKind -eq 'Https') { "https://localhost:$Port$endpointPath" } elseif ($profile.EndpointKind -eq 'Http') { "http://127.0.0.1:$Port$endpointPath" } else { "localhost:$Port" }
    Update-OctaneRunStage -Path $statePath -Stage desktopEndpoint -Status PASS -Detail "$($profile.DesktopLabel) reachable at $address" -DurationMs $endpointMs
    Set-OctaneRunMetadata -Path $statePath -Values @{desktopAddress=$address;desktopUsername=$profile.Username;stateDirectory=$profile.StateDirectory;evidenceDirectory=$profile.EvidenceDirectory}
    Set-OctaneRunState -Path $statePath -State RUNNING

    Write-Output "Container: $name"
    Write-Output "Engine: $Engine ($runtimeContext)"
    Write-Output "Wine profile: $WineProfile"
    if ($profile.Experiment) { Write-Output "Experiment: $($profile.Experiment)" }
    Write-Output "Desktop: $address"
    if ($profile.Username) { Write-Output "Username: $($profile.Username)" }
    if($profile.ProfileKind -eq 'DockerWineBrowser') {
        Write-Output "Credential: ./scripts/Get-OctaneViewerCredential.ps1 -Container $name"
    } else {
        Write-Output "Password: $password"
    }
    Write-Output 'Keep the password local. It is not stored in run metadata.'
    Write-Output "Run metadata: runs/$name.json"
    if ($profile.ProfileKind -eq 'DockerWineBrowser') {
        Write-Output 'Enter the per-run password only in the viewer form. It is not embedded in the URL or run metadata.'
        if ($OpenBrowser) { Start-Process $address }
    } else {
        Write-Output 'Inside the desktop terminal run: octane-lab environment; octane-lab notepad; octane-lab install; octane-lab diagnostic; octane-lab launch-ole (one at a time).'
    }
    Write-Output "From the controller, run: ./scripts/Invoke-OctaneExperiment.ps1 -Container $name -Engine $Engine$(if($WslDistro){" -WslDistro '$WslDistro'"})"
} catch {
    try { Update-OctaneRunStage -Path $statePath -Stage $activeStage -Status FAIL -Detail $_.Exception.Message } catch { }
    try { Block-OctaneRunStages -Path $statePath -Detail "Blocked after $activeStage failed." } catch { }
    if ($viewerSecretDirectory -and -not (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json).resources.containerCreated) {
        Remove-Item -LiteralPath $viewerSecretDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Error "Octane lab start failed at $activeStage. Run metadata: $statePath. Any created resource was preserved for diagnosis. $($_.Exception.Message)"
}
