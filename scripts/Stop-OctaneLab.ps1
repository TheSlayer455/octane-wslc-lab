[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Container,
    [ValidateSet('Wslc','Docker')][string]$Engine,
    [string]$WslDistro,
    [switch]$RemoveImage
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
$metadata=Join-Path $root "runs/$Container.json"
$runRecord=if(Test-Path -LiteralPath $metadata){Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json}else{$null}
if(-not $Engine){$Engine=if($runRecord){$runRecord.engine}else{'Wslc'}}
if(-not $WslDistro -and $runRecord){$WslDistro=$runRecord.wslDistro}
$containerCreated=if($runRecord -and $runRecord.resources.PSObject.Properties['containerCreated']){[bool]$runRecord.resources.containerCreated}else{$true}
$removeDuration=[int64]0
if($containerCreated){
    Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro | Out-Null
    # Evidence/output collection is a separate explicit stage. Remove only the
    # exact labeled container requested by immutable run identity.
    $remove=Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('rm','-f','-v',$Container) -TimeoutSeconds 120
    $removeDuration=$remove.DurationMs
    if($runRecord){Set-OctaneRunResource -Path $metadata -Resource containerCreated -Value $false}
}elseif(-not $runRecord){
    throw 'Container metadata is required for an idempotent cleanup retry.'
}
$image=if($runRecord){$runRecord.image}else{'octane-lab:'+$Container.Substring(7)}
if($RemoveImage){Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('image','rm',$image) -TimeoutSeconds 180 | Out-Null}
if($runRecord){
    Remove-OctaneRuntimeSecretFile -Engine $Engine -WslDistro $WslDistro -Container $Container
    $storageRemoved=$false
    if($runRecord.resources.PSObject.Properties['sessionStorageCreated'] -and [bool]$runRecord.resources.sessionStorageCreated){
        Remove-OctaneRuntimeSessionStorage -Engine Docker -WslDistro $WslDistro -Container $Container
        Set-OctaneRunResource -Path $metadata -Resource sessionStorageCreated -Value $false
        $storageRemoved=$true
    }
    Update-OctaneRunStage -Path $metadata -Stage cleanup -Status PASS -Detail "Removed exact container, anonymous volumes$(if($storageRemoved){', WSL-native disposable session storage'}else{''})$(if($RemoveImage){', and run image'}else{''})." -DurationMs $removeDuration
    if($RemoveImage){Set-OctaneRunResource -Path $metadata -Resource imageCreated -Value $false}
    Set-OctaneRunState -Path $metadata -State REMOVED
    [void](Clear-OctaneActiveRun -RunsDirectory (Join-Path $root 'runs') -Container $Container)
    Sync-OctaneEvidenceBundles -EvidenceRoot (Join-Path $root 'evidence') -Container $Container -RunPath $metadata
    $secretDirectory=Join-Path $root "runs/secrets/$Container"
    $allowedSecretRoot=[IO.Path]::GetFullPath((Join-Path $root 'runs/secrets'))
    $resolvedSecretDirectory=[IO.Path]::GetFullPath($secretDirectory)
    if($resolvedSecretDirectory.StartsWith($allowedSecretRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedSecretDirectory)){
        Remove-Item -LiteralPath $resolvedSecretDirectory -Recurse -Force
    }
}
Write-Output "Removed exact resources owned by $Container$(if($RemoveImage){' plus its run image'}else{''}); retained artifacts, collected outputs, and evidence were not pruned."
