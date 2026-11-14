[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Container)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Wslc.ps1')
Assert-OctaneContainer $Container
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root ("evidence/"+$Container+'-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $out -Force | Out-Null
# Never save raw inspect: its environment contains the desktop password.
Invoke-Wslc @('logs',$Container) 2>&1 | Set-Content -LiteralPath (Join-Path $out 'container.log') -Encoding utf8
Invoke-Wslc @('exec',$Container,'mkdir','-p','/config/octane-evidence')
Invoke-Wslc @('container','cp',"${Container}:/config/octane-evidence/.",$out)
$metadata=Join-Path $root "runs/$Container.json"
if(Test-Path -LiteralPath $metadata){Copy-Item -LiteralPath $metadata -Destination (Join-Path $out 'run.json')}
Write-Output "Evidence: $out"
Write-Output 'Review logs and reports for sensitive file paths or credentials before sharing.'
