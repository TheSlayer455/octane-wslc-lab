[CmdletBinding()]
param(
    [string]$WslDistro='Ubuntu-24.04',
    [string]$BaseImage='octane-lab:browser-appliance-v1-136944d',
    [ValidatePattern('^sha256:[a-f0-9]{64}$')][string]$ExpectedBaseImageId='sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a',
    [string]$Image='octane-lab:browser-xorgdummy-candidate-v1',
    [ValidatePattern('^[a-f0-9]{7,40}$')][string]$HarnessCommit,
    [string]$OutputPath
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')

$baseInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$BaseImage) -TimeoutSeconds 60
$base=@($baseInspect.StdOut | ConvertFrom-Json)[0]
if([string]$base.Id -ne $ExpectedBaseImageId){throw "Base browser image drift: expected $ExpectedBaseImageId, selected $($base.Id)."}
if($base.Config.Labels.'com.octanelab.browser-transport' -ne 'novnc' -or $base.Config.Labels.'com.octanelab.browser-rdp-required' -ne 'false'){
    throw 'The Xorg candidate must derive from the identified noVNC/no-RDP browser image.'
}

$context=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $root
$dockerfile=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path (Join-Path $root 'lab/Dockerfile.browser-xorgdummy')
$arguments=[Collections.Generic.List[string]]::new()
foreach($value in @('build','--pull=false','--platform','linux/amd64','--build-arg',"BASE_IMAGE=$BaseImage",'-f',$dockerfile,'-t',$Image)){$arguments.Add($value)}
if($HarnessCommit){$arguments.Add('--label');$arguments.Add("com.octanelab.harness-commit=$HarnessCommit")}
$arguments.Add($context)
$build=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments $arguments.ToArray() -TimeoutSeconds 1800

$imageInspect=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('image','inspect',$Image) -TimeoutSeconds 60
$imageObject=@($imageInspect.StdOut | ConvertFrom-Json)[0]
if($imageObject.Config.Labels.'com.octanelab.browser-display-server' -ne 'xorg-dummy' -or $imageObject.Config.Labels.'com.octanelab.browser-rdp-required' -ne 'false'){
    throw 'Built candidate is missing its standalone-Xorg/no-RDP identity labels.'
}
$record=[ordered]@{
    schemaVersion=1;status='PASS';scope='exploratory browser display candidate; not acceptance'
    builtAtUtc=[DateTime]::UtcNow.ToString('o');wslDistro=$WslDistro
    imageReference=$Image;imageId=[string]$imageObject.Id;repoDigests=@($imageObject.RepoDigests)
    baseImageReference=$BaseImage;baseImageId=[string]$base.Id;harnessCommit=if($HarnessCommit){$HarnessCommit}else{$null}
    dockerfile='lab/Dockerfile.browser-xorgdummy';displayServer='xorg-dummy';rdpRequired=$false;buildDurationMs=$build.DurationMs
}
if(-not $OutputPath){$OutputPath=Join-Path $root ("runs/browser-xorg-image-build-"+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'.json')}
Write-OctaneJsonAtomic -Path $OutputPath -Value $record
[pscustomobject]$record
