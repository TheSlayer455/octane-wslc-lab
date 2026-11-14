[CmdletBinding()]
param(
    [ValidateSet('Wslc','Docker')][string]$Engine = 'Wslc',
    [string]$WslDistro,
    [ValidateSet('WineGui','DockerWine')][string]$WineProfile = 'WineGui',
    [ValidateRange(1024,65535)][int]$Port = 3001,
    [string]$BaseImage,
    [ValidateRange(30,900)][int]$StartupTimeoutSeconds = 240,
    [switch]$SkipDeepDoctor
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

Initialize-OctaneRunState -Path $statePath -Identity @{
    runId=$id;container=$name;image=$image;engine=$Engine;engineContext=$runtimeContext
    wslDistro=if($WslDistro){$WslDistro}else{$null};wineProfile=$WineProfile;baseImage=$profile.BaseImage;port=$Port
    endpointKind=$profile.EndpointKind;installerSha256=$expectedHash
} | Out-Null

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
    $build = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('build','--build-arg',"BASE_IMAGE=$($profile.BaseImage)",'-f',$runtimeDockerfile,'-t',$image,$runtimeRoot) -TimeoutSeconds 3600
    Set-OctaneRunResource -Path $statePath -Resource imageCreated -Value $true
    $baseDigest = Get-OctaneImageDigest -Engine $Engine -WslDistro $WslDistro -Image $profile.BaseImage
    Set-OctaneRunMetadata -Path $statePath -Values @{resolvedBaseImage=$baseDigest}
    Update-OctaneRunStage -Path $statePath -Stage imageBuild -Status PASS -Detail "Built $image from $($profile.BaseImage)" -DurationMs $build.DurationMs

    $passwordBytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
    $password = [Convert]::ToBase64String($passwordBytes)
    $runArguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in @('run','-d','--name',$name,'--label','com.octanelab.managed=true','--label',"com.octanelab.engine=$($Engine.ToLowerInvariant())",'--label',"com.octanelab.profile=$WineProfile",'--shm-size=1gb','-p',"127.0.0.1:${Port}:$($profile.ContainerPort)",'-e','TZ=America/Chicago')) { $runArguments.Add($argument) }
    if ($WineProfile -eq 'WineGui') {
        foreach ($argument in @('-e','CUSTOM_USER=octane','-e',"PASSWORD=$password")) { $runArguments.Add($argument) }
    } else {
        $passwordHash = New-OctaneUnixPasswordHash -Password $password -WslDistro $WslDistro
        foreach ($argument in @('--platform','linux/amd64','-e','RDP_SERVER=yes','-e',"USER_PASSWD=$passwordHash")) { $runArguments.Add($argument) }
    }
    $runArguments.Add($image)

    $activeStage = 'containerCreate'
    $run = Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments $runArguments.ToArray() -TimeoutSeconds 180
    Set-OctaneRunResource -Path $statePath -Resource containerCreated -Value $true
    Update-OctaneRunStage -Path $statePath -Stage containerCreate -Status PASS -Detail "Created with $Engine using profile $WineProfile" -DurationMs $run.DurationMs

    $activeStage = 'desktopEndpoint'
    $endpointMs = Wait-OctaneEndpoint -Kind $profile.EndpointKind -Port $Port -TimeoutSeconds $StartupTimeoutSeconds
    $address = if ($profile.EndpointKind -eq 'Https') { "https://localhost:$Port" } else { "localhost:$Port" }
    Update-OctaneRunStage -Path $statePath -Stage desktopEndpoint -Status PASS -Detail "$($profile.DesktopLabel) reachable at $address" -DurationMs $endpointMs
    Set-OctaneRunMetadata -Path $statePath -Values @{desktopAddress=$address;desktopUsername=$profile.Username;stateDirectory=$profile.StateDirectory;evidenceDirectory=$profile.EvidenceDirectory}
    Set-OctaneRunState -Path $statePath -State RUNNING

    Write-Output "Container: $name"
    Write-Output "Engine: $Engine ($runtimeContext)"
    Write-Output "Wine profile: $WineProfile"
    Write-Output "Desktop: $address"
    Write-Output "Username: $($profile.Username)"
    Write-Output "Password: $password"
    Write-Output 'Keep the password local. It is not stored in run metadata.'
    Write-Output "Run metadata: runs/$name.json"
    Write-Output 'Inside the desktop terminal run: octane-lab notepad; octane-lab install; octane-lab launch (one at a time).'
} catch {
    try { Update-OctaneRunStage -Path $statePath -Stage $activeStage -Status FAIL -Detail $_.Exception.Message } catch { }
    try { Block-OctaneRunStages -Path $statePath -Detail "Blocked after $activeStage failed." } catch { }
    Write-Error "Octane lab start failed at $activeStage. Run metadata: $statePath. Any created resource was preserved for diagnosis. $($_.Exception.Message)"
}
