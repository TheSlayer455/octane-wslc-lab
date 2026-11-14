$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$temp=Join-Path ([IO.Path]::GetTempPath()) ('octane-script-test-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $temp 'artifacts') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'scripts') -Destination $temp -Recurse
$installer=Join-Path $temp 'artifacts/Octane-setup.exe'
Set-Content -LiteralPath $installer -Value 'mock installer only'
@{sha256=(Get-FileHash -LiteralPath $installer).Hash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $temp 'artifacts/installer-manifest.json')

$global:calls=[Collections.Generic.List[object]]::new()
function global:Invoke-OctaneNativeProcess {
    param([string]$FileName,[string[]]$Arguments,[int]$TimeoutSeconds=300,[string]$StandardInput)
    $global:calls.Add([pscustomobject]@{file=$FileName;arguments=@($Arguments);standardInput=$StandardInput})
    $stdout=''
    if($Arguments -contains 'wslpath'){$stdout='/mnt/c/mock/octane'}
    elseif($Arguments[0] -eq 'version'){$stdout='wslc 3.0.1.0'}
    elseif($Arguments[0] -eq 'inspect'){$stdout='[{"Config":{"Labels":{"com.octanelab.managed":"true","com.octanelab.engine":"wslc","com.octanelab.profile":"WineGui"}}}]'}
    elseif($Arguments[0] -eq 'logs'){$stdout='mock container log'}
    elseif($Arguments[0] -eq 'image' -and $Arguments[1] -eq 'inspect'){$stdout='["lscr.io/linuxserver/winegui@sha256:mock"]'}
    elseif($Arguments -contains 'passwd'){$stdout='$1$mocksalt$mockhash'}
    return [pscustomobject]@{StartedAtUtc=[DateTime]::UtcNow.ToString('o');DurationMs=12;ExitCode=0;TimedOut=$false;StdOut=$stdout;StdErr=''}
}
function global:Wait-OctaneEndpoint { param([string]$Kind,[int]$Port,[int]$TimeoutSeconds) return [int64]25 }
function Assert($condition,$message){if(-not $condition){throw $message}}

try {
    $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $listener.Start();$port=([Net.IPEndPoint]$listener.LocalEndpoint).Port;$listener.Stop()
    $output=& (Join-Path $temp 'scripts/Start-OctaneLab.ps1') -Port $port -SkipDeepDoctor
    $run=Get-ChildItem -LiteralPath (Join-Path $temp 'runs') -Filter 'octane-??????????.json' | Select-Object -First 1
    $metadata=Get-Content -LiteralPath $run.FullName -Raw | ConvertFrom-Json
    $runCall=@($global:calls | Where-Object {$_.arguments[0] -eq 'run'})[-1].arguments

    Assert ($metadata.schemaVersion -eq 2) 'Run metadata must use schema 2'
    Assert ($metadata.engine -eq 'Wslc') 'Run metadata must record the engine'
    Assert ($metadata.wineProfile -eq 'WineGui') 'Run metadata must record the Wine profile'
    Assert ($metadata.stages.runtimeDoctor.status -eq 'PASS') 'Runtime doctor must be a named stage'
    Assert ($metadata.stages.desktopEndpoint.status -eq 'PASS') 'Desktop endpoint must be verified'
    Assert ($metadata.stages.webviewDiagnostic.status -eq 'NOT_RUN') 'Native WebView2 diagnostic must be an independent acceptance stage'
    Assert ($metadata.evidenceDirectory -eq '/config/octane-evidence') 'Run metadata must record the profile evidence directory'
    Assert ($runCall -contains "127.0.0.1:${port}:3001") 'Desktop must bind loopback'
    Assert ($runCall -contains 'com.octanelab.engine=wslc') 'Container must record its engine label'
    Assert ($runCall -contains 'com.octanelab.profile=WineGui') 'Container must record its profile label'
    Assert (-not ($runCall -contains '-v')) 'No host bind mounts'
    Assert (-not ($runCall -contains '--privileged')) 'No privileged container'
    Assert (-not ((Get-Content -LiteralPath $run.FullName -Raw) -match 'PASSWORD=')) 'Password must not be persisted'

    & (Join-Path $temp 'scripts/Record-OctaneResult.ps1') -Container $metadata.container -Stage basicWine -Status PASS -Detail 'mock repaint pass' | Out-Null
    $metadata=Get-Content -LiteralPath $run.FullName -Raw | ConvertFrom-Json
    Assert ($metadata.stages.basicWine.status -eq 'PASS') 'Public result recorder must update acceptance stages'
    $rejected=$false
    try { & (Join-Path $temp 'scripts/Record-OctaneResult.ps1') -Container $metadata.container -Stage installer -Status PASS -BlockRemaining | Out-Null } catch {$rejected=$true}
    $metadata=Get-Content -LiteralPath $run.FullName -Raw | ConvertFrom-Json
    Assert ($rejected -and $metadata.stages.installer.status -eq 'NOT_RUN') 'BlockRemaining must reject non-fail status before mutation'

    & (Join-Path $temp 'scripts/Collect-Evidence.ps1') -Container $metadata.container | Out-Null
    $evidence=Get-ChildItem -LiteralPath (Join-Path $temp 'evidence') -Directory | Select-Object -First 1
    Assert (Test-Path -LiteralPath (Join-Path $evidence.FullName 'environment.json')) 'Portable evidence must include environment.json'
    Assert (Test-Path -LiteralPath (Join-Path $evidence.FullName 'results.json')) 'Portable evidence must include results.json'
    Assert (Test-Path -LiteralPath (Join-Path $evidence.FullName 'junit.xml')) 'Portable evidence must include JUnit XML'
    Assert (Test-Path -LiteralPath (Join-Path $evidence.FullName 'checksums.sha256')) 'Portable evidence must include checksums'
    Assert (@($global:calls | Where-Object {$_.arguments[0] -eq 'container' -and $_.arguments[1] -eq 'cp'}).Count -ge 1) 'Must collect with container cp'

    & (Join-Path $temp 'scripts/Stop-OctaneLab.ps1') -Container $metadata.container -RemoveImage | Out-Null
    $remove=@($global:calls | Where-Object {$_.arguments[0] -eq 'rm'})[-1].arguments
    Assert ($remove -contains '-v') 'Must remove anonymous volumes'
    $metadata=Get-Content -LiteralPath $run.FullName -Raw | ConvertFrom-Json
    Assert ($metadata.state -eq 'REMOVED') 'Cleanup must update run state'
    $bundledRun=Get-Content -LiteralPath (Join-Path $evidence.FullName 'run.json') -Raw | ConvertFrom-Json
    Assert ($bundledRun.stages.cleanup.status -eq 'PASS') 'Cleanup must synchronize the collected evidence bundle'

    . (Join-Path $temp 'scripts/Runtime.ps1')
    . (Join-Path $temp 'scripts/RuntimeProfiles.ps1')
    $docker=Get-OctaneRuntimeCommand -Engine Docker -WslDistro Ubuntu-24.04
    Assert ($docker.FileName -eq 'wsl.exe') 'Windows Docker adapter must use the selected WSL distribution'
    Assert ($docker.Prefix[-1] -eq 'docker') 'Docker adapter must invoke the Docker CLI'
    $dockerWine=Get-OctaneWineProfile -WineProfile DockerWine
    Assert ($dockerWine.EndpointKind -eq 'Rdp') 'Docker-Wine profile must expose RDP'
    Assert ($dockerWine.Dockerfile -eq 'lab/Dockerfile.docker-wine') 'Docker-Wine must use its own image adapter'
    Assert ($dockerWine.BaseImage -match '@sha256:[a-f0-9]{64}$') 'Docker-Wine default must be digest pinned'
    $oleControl=Get-OctaneWineProfile -WineProfile WineGuiOle32Control
    $olePatched=Get-OctaneWineProfile -WineProfile WineGuiOle32Mr12477
    Assert ($oleControl.Dockerfile -eq $olePatched.Dockerfile) 'OLE control and candidate must use the same Dockerfile'
    Assert ($oleControl.BuildArguments.WINE_VARIANT -eq 'control') 'OLE control must request the stock source-built binary'
    Assert ($olePatched.BuildArguments.WINE_VARIANT -eq 'mr12477') 'OLE candidate must request MR !12477 only'
    Assert ($oleControl.BaseImage -eq $olePatched.BaseImage) 'OLE comparison must use the same pinned desktop base'
    Assert ($olePatched.ProfileKind -eq 'WineGui') 'OLE comparison must preserve the WineGUI desktop path'
    Assert ($olePatched.BuildTimeoutSeconds -eq 7200) 'Source-built Wine profiles need a bounded extended build timeout'
    $hash=New-OctaneUnixPasswordHash -Password 'not-secret' -WslDistro Ubuntu-24.04
    Assert ($hash -like '$1$*') 'Docker-Wine password must be hashed before container creation'

    $rejected=$false
    try { & (Join-Path $temp 'scripts/Stop-OctaneLab.ps1') -Container 'some-other-container' } catch {$rejected=$true}
    Assert $rejected 'Must reject unrelated container names'
    Set-Content -LiteralPath $installer -Value 'tampered'
    $rejected=$false
    try { & (Join-Path $temp 'scripts/Start-OctaneLab.ps1') -Port $port -SkipDeepDoctor | Out-Null } catch {$rejected=$true}
    Assert $rejected 'Must reject mismatched installer hash'
    Write-Output 'PowerShell harness: 37 assertions passed (mock runtimes; not a GUI compatibility test).'
} finally {
    Remove-Item Function:\Invoke-OctaneNativeProcess -ErrorAction SilentlyContinue
    Remove-Item Function:\Wait-OctaneEndpoint -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
