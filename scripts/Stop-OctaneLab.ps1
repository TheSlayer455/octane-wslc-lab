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
Assert-OctaneContainer -Name $Container -Engine $Engine -WslDistro $WslDistro | Out-Null
# Collect evidence first. Remove only the explicitly named, labeled lab container.
$remove=Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('rm','-f','-v',$Container) -TimeoutSeconds 120
$image=if($runRecord){$runRecord.image}else{'octane-lab:'+$Container.Substring(7)}
if($RemoveImage){Invoke-OctaneRuntime -Engine $Engine -WslDistro $WslDistro -Arguments @('image','rm',$image) -TimeoutSeconds 180 | Out-Null}
if($runRecord){
    Update-OctaneRunStage -Path $metadata -Stage cleanup -Status PASS -Detail "Removed container, anonymous volumes$(if($RemoveImage){', and run image'}else{''})." -DurationMs $remove.DurationMs
    Set-OctaneRunResource -Path $metadata -Resource containerCreated -Value $false
    if($RemoveImage){Set-OctaneRunResource -Path $metadata -Resource imageCreated -Value $false}
    Set-OctaneRunState -Path $metadata -State REMOVED
    Sync-OctaneEvidenceBundles -EvidenceRoot (Join-Path $root 'evidence') -Container $Container -RunPath $metadata
    $secretDirectory=Join-Path $root "runs/secrets/$Container"
    $allowedSecretRoot=[IO.Path]::GetFullPath((Join-Path $root 'runs/secrets'))
    $resolvedSecretDirectory=[IO.Path]::GetFullPath($secretDirectory)
    if($resolvedSecretDirectory.StartsWith($allowedSecretRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedSecretDirectory)){
        Remove-Item -LiteralPath $resolvedSecretDirectory -Recurse -Force
    }
}
Write-Output "Removed $Container and its anonymous volumes$(if($RemoveImage){' plus its run image'}else{''})."
