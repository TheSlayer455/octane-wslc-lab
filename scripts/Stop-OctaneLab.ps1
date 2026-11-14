[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Container,[switch]$RemoveImage)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wslc.ps1')
Assert-OctaneContainer $Container
# Collect evidence first. Remove only the explicitly named, labeled lab container.
Invoke-Wslc @('rm','-f','-v',$Container)
if($RemoveImage){$image='octane-lab:'+$Container.Substring(7);Invoke-Wslc @('image','rm',$image)}
Write-Output "Removed $Container and its anonymous volumes."
