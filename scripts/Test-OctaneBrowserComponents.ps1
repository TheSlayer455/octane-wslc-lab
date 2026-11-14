[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
    [string]$WslDistro,
    [string]$OutputDirectory
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
. (Join-Path $PSScriptRoot 'RunState.ps1')
$metadataPath=Join-Path $root "runs/$Container.json"
$run=if(Test-Path -LiteralPath $metadataPath){Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json}else{$null}
if(-not $WslDistro){$WslDistro=if($run){[string]$run.wslDistro}else{'Ubuntu-24.04'}}
$inspect=Assert-OctaneContainer -Name $Container -Engine Docker -WslDistro $WslDistro
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root "evidence/$Container-browser-components-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))"}
$out=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path (Join-Path $out 'logs') -Force | Out-Null

function Invoke-ContainerCheck([string]$Name,[string]$Command){
    $result=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$Container,'bash','-lc',$Command) -TimeoutSeconds 60 -AllowFailure
    $result.StdOut | Set-Content -LiteralPath (Join-Path $out "logs/$Name.stdout.log") -Encoding utf8
    $result.StdErr | Set-Content -LiteralPath (Join-Path $out "logs/$Name.stderr.log") -Encoding utf8
    return $result
}

$bindings=@($inspect.HostConfig.PortBindings.PSObject.Properties | ForEach-Object {
    foreach($binding in @($_.Value)){[ordered]@{containerPort=$_.Name;hostIp=[string]$binding.HostIp;hostPort=[string]$binding.HostPort}}
})
$browserBindings=@($bindings | Where-Object {$_.containerPort -eq '3000/tcp' -and $_.hostIp -eq '127.0.0.1'})
$unexpectedBindings=@($bindings | Where-Object {$_.containerPort -ne '3000/tcp' -or $_.hostIp -ne '127.0.0.1'})
$mounts=@($inspect.Mounts | ForEach-Object {[ordered]@{type=$_.Type;destination=$_.Destination;readOnly=(-not $_.RW)}})
$onlyCredentialMount=$mounts.Count -eq 1 -and $mounts[0].type -eq 'bind' -and $mounts[0].destination -eq '/run/octane/viewer-password' -and $mounts[0].readOnly

$processCheck=Invoke-ContainerCheck 'processes' "ps -eo pid,ppid,user,comm,args; if pgrep -af '(^|/)(xrdp|xrdp-sesman|xfreerdp|wlfreerdp)( |$)'; then exit 9; fi"
$listenerCheck=Invoke-ContainerCheck 'listeners' "ss -lntp; ! ss -lntH | grep -Eq ':(3389|3350)([[:space:]]|$)'"
$vncListenerCheck=Invoke-ContainerCheck 'vnc-loopback' 'listeners=$(ss -lntH "( sport = :5901 )"); test -n "$listeners"; printf "%s\n" "$listeners"; ! printf "%s\n" "$listeners" | awk ''{print $4}'' | grep -Ev ''^(127\.0\.0\.1:5901|\[::1\]:5901)$'''
$displayCheck=Invoke-ContainerCheck 'display' 'test "$DISPLAY" = :1 && test -S /tmp/.X11-unix/X1 && xdpyinfo -display :1 | grep -F "dimensions:    1280x800 pixels" && pgrep -af "x11vnc.*-display :1" && pgrep -af "websockify.*0.0.0.0:3000.*127.0.0.1:5901"'
$authCheck=Invoke-ContainerCheck 'authentication' 'test -s /run/octane/viewer-password && pid=$(pgrep -x x11vnc | head -n 1) && tr "\000" " " < "/proc/$pid/cmdline" | grep -F -- "-passwdfile /run/octane/viewer-password" && ! tr "\000" " " < "/proc/$pid/cmdline" | grep -F -- "-nopw"'
$wineDisplayCheck=Invoke-ContainerCheck 'wine-display' 'app=$(jq -r ".unixPath" /home/wineuser/.octane/evidence/target/installed-executable.json); pid=""; for proc in /proc/[0-9]*; do test -r "$proc/cmdline" || continue; first=$(tr "\000" "\n" < "$proc/cmdline" | head -n 1); if test "$first" = "$app"; then pid=${proc##*/}; break; fi; done; test -n "$pid" && tr "\000" "\n" < "/proc/$pid/environ" | grep -Fx "DISPLAY=:1" && grep -F "winex11.drv" "/proc/$pid/maps"'

$port=[int]$browserBindings[0].hostPort
$uri="http://127.0.0.1:$port/octane.html"
$response=Invoke-WebRequest -Uri $uri -SkipHttpErrorCheck -TimeoutSec 10
$viewerPagePass=$response.StatusCode -eq 200 -and $response.Content -match 'viewer-page-loaded' -and $response.Content -match 'vnc-negotiated'
$originStatus=$null
try{
    $bad=Invoke-WebRequest -Uri "http://127.0.0.1:$port/websockify" -Method Get -Headers @{
        Origin='http://example.invalid';Upgrade='websocket';Connection='Upgrade';'Sec-WebSocket-Version'='13';'Sec-WebSocket-Key'='dGhlIHNhbXBsZSBub25jZQ=='
    } -SkipHttpErrorCheck -TimeoutSec 10
    $originStatus=[int]$bad.StatusCode
}catch{
    if($_.Exception.Response){$originStatus=[int]$_.Exception.Response.StatusCode.value__}
}
$originRejected=$originStatus -in @(401,403)

$runtimeOut=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path (Join-Path $out 'container-side-root.png')
Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$Container,'bash','-lc','import -window root /tmp/octane-container-side-root.png 2>/dev/null || true') -TimeoutSeconds 60 -AllowFailure | Out-Null
Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',"$Container`:/tmp/octane-container-side-root.png",$runtimeOut) -TimeoutSeconds 60 -AllowFailure | Out-Null

$checks=[ordered]@{
    identifiedManagedContainer=if($inspect.Config.Labels.'com.octanelab.managed' -eq 'true'){'PASS'}else{'FAIL'}
    browserImageIdentity=if($inspect.Config.Labels.'com.octanelab.browser-transport' -eq 'novnc' -and $inspect.Config.Labels.'com.octanelab.browser-rdp-required' -eq 'false'){'PASS'}else{'FAIL'}
    loopbackPublication=if($browserBindings.Count -eq 1 -and $unexpectedBindings.Count -eq 0){'PASS'}else{'FAIL'}
    credentialMount=if($onlyCredentialMount){'PASS'}else{'FAIL'}
    noRdpProcess=if($processCheck.ExitCode -eq 0){'PASS'}else{'FAIL'}
    noRdpListener=if($listenerCheck.ExitCode -eq 0){'PASS'}else{'FAIL'}
    rawVncLoopbackOnly=if($vncListenerCheck.ExitCode -eq 0){'PASS'}else{'FAIL'}
    x11VncDisplayIdentity=if($displayCheck.ExitCode -eq 0){'PASS'}else{'FAIL'}
    authenticationConfigured=if($authCheck.ExitCode -eq 0){'PASS'}else{'FAIL'}
    wineDisplayIdentity=if($wineDisplayCheck.ExitCode -eq 0){'PASS'}else{'FAIL'}
    viewerPageHttp=if($viewerPagePass){'PASS'}else{'FAIL'}
    websocketOriginRejection=if($originRejected){'PASS'}else{'FAIL'}
    vncNegotiation='NOT_RUN'
    browserFramebuffer='NOT_RUN'
    browserInput='NOT_RUN'
    applicationReadyInBrowser='NOT_RUN'
}
$componentPass=@($checks.GetEnumerator() | Where-Object {$_.Value -eq 'FAIL'}).Count -eq 0
$result=[ordered]@{
    schemaVersion=1;scope='Component checks only; no browser GUI acceptance';container=$Container;containerId=$inspect.Id;image=$inspect.Image
    checkedAtUtc=[DateTime]::UtcNow.ToString('o');viewerUri=$uri;bindings=$bindings;mounts=$mounts;badOriginHttpStatus=$originStatus
    checks=$checks;componentStatus=if($componentPass){'PASS'}else{'FAIL'}
    browserAcceptance='BLOCKED';browserAcceptanceReason='No approved controllable browser was available in this execution environment.'
    containerSideScreenshot='container-side-root.png is diagnostic only and is not evidence that a browser received the frame.'
}
Write-OctaneJsonAtomic -Path (Join-Path $out 'browser-component-results.json') -Value $result
if($run){Copy-Item -LiteralPath $metadataPath -Destination (Join-Path $out 'run.json')}
Update-OctaneEvidenceChecksums -Directory $out
Write-Output "Browser component evidence: $out"
Write-Output "Component status: $($result.componentStatus); browser acceptance: BLOCKED"
if(-not $componentPass){throw 'One or more browser component checks failed. Browser acceptance remains blocked regardless.'}
