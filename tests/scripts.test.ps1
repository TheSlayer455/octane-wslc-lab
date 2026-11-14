$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$temp=Join-Path ([IO.Path]::GetTempPath()) ('octane-script-test-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $temp 'artifacts') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'scripts') -Destination $temp -Recurse
$installer=Join-Path $temp 'artifacts/Octane-setup.exe'
Set-Content -LiteralPath $installer -Value 'mock installer only'
@{sha256=(Get-FileHash -LiteralPath $installer).Hash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'artifacts/installer-manifest.json')
$global:calls=[Collections.Generic.List[object]]::new()
function global:wslc.exe {
    $global:calls.Add(@($args))
    $global:LASTEXITCODE=0
    if($args[0] -eq 'inspect'){'[{"Config":{"Labels":{"com.octanelab.managed":"true"}}}]'}
    elseif($args[0] -eq 'logs'){'mock container log'}
}
function Assert($condition,$message){if(-not $condition){throw $message}}
$output=& (Join-Path $temp 'scripts/Start-OctaneLab.ps1')
$run=Get-ChildItem -LiteralPath (Join-Path $temp 'runs') | Select-Object -First 1
$metadata=Get-Content -LiteralPath $run.FullName -Raw | ConvertFrom-Json
$runCall=@($global:calls | Where-Object {$_[0] -eq 'run'})[0]
Assert ($runCall -contains '127.0.0.1:3001:3001') 'Desktop must bind loopback'
Assert (-not ($runCall -contains '-v')) 'No host bind mounts'
Assert (-not ($runCall -contains '--privileged')) 'No privileged container'
Assert (-not ((Get-Content -LiteralPath $run.FullName -Raw) -match 'PASSWORD')) 'Password must not be persisted'
& (Join-Path $temp 'scripts/Collect-Evidence.ps1') -Container $metadata.container | Out-Null
Assert (@($global:calls | Where-Object {$_[0] -eq 'container' -and $_[1] -eq 'cp'}).Count -ge 1) 'Must collect with container cp'
& (Join-Path $temp 'scripts/Stop-OctaneLab.ps1') -Container $metadata.container -RemoveImage | Out-Null
$remove=@($global:calls | Where-Object {$_[0] -eq 'rm'})[0]
Assert ($remove -contains '-v') 'Must remove anonymous volumes'
$rejected=$false
try { & (Join-Path $temp 'scripts/Stop-OctaneLab.ps1') -Container 'some-other-container' } catch {$rejected=$true}
Assert $rejected 'Must reject unrelated container names'
Set-Content -LiteralPath $installer -Value 'tampered'
$rejected=$false
try { & (Join-Path $temp 'scripts/Start-OctaneLab.ps1') | Out-Null } catch {$rejected=$true}
Assert $rejected 'Must reject mismatched installer hash'
Remove-Item Function:\wslc.exe
Write-Output 'PowerShell harness: 8 assertions passed (mock WSLC; not a runtime compatibility test).'
