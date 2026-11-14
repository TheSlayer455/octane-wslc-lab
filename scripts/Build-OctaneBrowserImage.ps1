[CmdletBinding()]
param(
    [string]$WslDistro='Ubuntu-24.04',
    [string]$BaseImage='octane-lab:qualification-7181a47ee47a',
    [ValidatePattern('^sha256:[a-f0-9]{64}$')][string]$ExpectedBaseImageId='sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c',
    [string]$Image='octane-lab:browser-candidate-v1',
    [ValidatePattern('^[a-f0-9]{7,40}$')][string]$HarnessCommit,
    [string]$OutputPath
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RuntimeProfiles.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
$profile=Get-OctaneWineProfile -WineProfile DockerWineStaging1121VisRgnBrowser -BaseImage $BaseImage
$baseInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$BaseImage) -TimeoutSeconds 60
$base=@($baseInspect.StdOut | ConvertFrom-Json)[0]
if([string]$base.Id -ne $ExpectedBaseImageId){throw "Base image drift: expected $ExpectedBaseImageId, selected $($base.Id)."}

$context=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $root
$dockerfile=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path (Join-Path $root $profile.Dockerfile)
$arguments=[Collections.Generic.List[string]]::new()
foreach($value in @('build','--pull=false','--platform','linux/amd64','--build-arg',"BASE_IMAGE=$BaseImage",'--build-arg',"NOVNC_COMMIT=$($profile.BuildArguments.NOVNC_COMMIT)",'--build-arg',"WEBSOCKIFY_COMMIT=$($profile.BuildArguments.WEBSOCKIFY_COMMIT)",'-f',$dockerfile,'-t',$Image)){$arguments.Add($value)}
if($HarnessCommit){$arguments.Add('--label');$arguments.Add("com.octanelab.harness-commit=$HarnessCommit")}
$arguments.Add($context)
$build=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments $arguments.ToArray() -TimeoutSeconds $profile.BuildTimeoutSeconds
$imageInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$Image) -TimeoutSeconds 60
$imageObject=@($imageInspect.StdOut | ConvertFrom-Json)[0]
if($imageObject.Config.Labels.'com.octanelab.browser-transport' -ne 'novnc' -or $imageObject.Config.Labels.'com.octanelab.browser-rdp-required' -ne 'false'){
    throw 'Built image is missing the required browser/no-RDP identity labels.'
}
$record=[ordered]@{
    schemaVersion=1;status='PASS';builtAtUtc=[DateTime]::UtcNow.ToString('o');wslDistro=$WslDistro
    imageReference=$Image;imageId=[string]$imageObject.Id;repoDigests=@($imageObject.RepoDigests)
    baseImageReference=$BaseImage;baseImageId=[string]$base.Id;harnessCommit=if($HarnessCommit){$HarnessCommit}else{$null}
    dockerfile=$profile.Dockerfile;noVncCommit=$profile.BuildArguments.NOVNC_COMMIT;websockifyCommit=$profile.BuildArguments.WEBSOCKIFY_COMMIT
    buildDurationMs=$build.DurationMs
}
if(-not $OutputPath){$OutputPath=Join-Path $root ("runs/browser-image-build-"+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'.json')}
Write-OctaneJsonAtomic -Path $OutputPath -Value $record
[pscustomobject]$record
