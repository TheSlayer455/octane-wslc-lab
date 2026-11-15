$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$temp=Join-Path ([IO.Path]::GetTempPath()) ('octane-browser-runtime-test-'+[Guid]::NewGuid().ToString('N'))
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$assertions=0
function Check([bool]$Condition,[string]$Message){Assert $Condition $Message;$script:assertions++}

try{
    New-Item -ItemType Directory -Path $temp | Out-Null
    $overlay=Join-Path $temp 'example-app-octane'
    & (Join-Path $root 'scripts/New-OctaneTarget.ps1') -Id example-app -Output $overlay -ExecutableFileName 'example-app.exe' -WindowTitleRegex '^Example App$' -InstallArgument '/S' -VerifiedInstallerArguments | Out-Null
    $valid=& (Join-Path $root 'scripts/Test-OctaneTargetProfile.ps1') -Profile (Join-Path $overlay 'app.json') -Operational
    Check ($valid.id -eq 'example-app' -and $valid.operational) 'Generated explicit overlay must validate for operational preview.'
    Check (Test-Path -LiteralPath (Join-Path $overlay 'MANUAL-CHECKLIST.md')) 'Overlay must include the manual browser checklist.'
    Check (-not (Test-Path -LiteralPath (Join-Path $overlay 'installer.exe'))) 'Overlay must not copy an installer or require target source.'

    $bad=Get-Content -LiteralPath (Join-Path $overlay 'app.json') -Raw | ConvertFrom-Json
    $bad.application.expectedRelativePath='../escape/example-app.exe'
    $badPath=Join-Path $temp 'bad-traversal.json'
    $bad | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badPath
    $rejected=$false
    try{& (Join-Path $root 'scripts/Test-OctaneTargetProfile.ps1') -Profile $badPath | Out-Null}catch{$rejected=$true}
    Check $rejected 'Profile validation must reject path traversal.'

    $bad=Get-Content -LiteralPath (Join-Path $overlay 'app.json') -Raw | ConvertFrom-Json
    $bad.installer.installArguments=@("/S`nmalicious")
    $badPath=Join-Path $temp 'bad-newline.json'
    $bad | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badPath
    $rejected=$false
    try{& (Join-Path $root 'scripts/Test-OctaneTargetProfile.ps1') -Profile $badPath | Out-Null}catch{$rejected=$true}
    Check $rejected 'Profile validation must reject newline-bearing arguments.'

    $bad=Get-Content -LiteralPath (Join-Path $overlay 'app.json') -Raw | ConvertFrom-Json
    $bad.network.requiredEndpoints=@([pscustomobject]@{id='private-endpoint';url='https://user:secret@example.invalid/';expectedStatusCodes=@(200)})
    $badPath=Join-Path $temp 'bad-credential-url.json'
    $bad | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badPath
    $rejected=$false
    try{& (Join-Path $root 'scripts/Test-OctaneTargetProfile.ps1') -Profile $badPath | Out-Null}catch{$rejected=$true}
    Check $rejected 'Profile validation must reject endpoint credentials embedded in a URL.'

    $artifactDirectory=Join-Path $temp 'artifacts'
    $sourceDirectory=Join-Path $temp 'source'
    New-Item -ItemType Directory -Path $sourceDirectory | Out-Null
    $source=Join-Path $sourceDirectory 'setup.exe'
    [IO.File]::WriteAllBytes($source,[Text.Encoding]::UTF8.GetBytes('first immutable build'))
    $one=& (Join-Path $root 'scripts/Stage-OctaneArtifact.ps1') -Installer $source -OutputDirectory $artifactDirectory -BuildLabel build-one
    Check ((Get-FileHash -LiteralPath $one.artifactPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $one.sha256) 'Staged bytes must match the streamed SHA-256.'
    Check (Test-Json -Json (Get-Content -LiteralPath $one.manifestPath -Raw) -SchemaFile (Join-Path $root 'schemas/artifact-manifest.schema.json')) 'Generated artifact manifest must satisfy its schema.'
    [IO.File]::WriteAllBytes($source,[Text.Encoding]::UTF8.GetBytes('second immutable build'))
    $two=& (Join-Path $root 'scripts/Stage-OctaneArtifact.ps1') -Installer $source -OutputDirectory $artifactDirectory -BuildLabel build-two
    Check ($one.sha256 -ne $two.sha256 -and $one.artifactPath -ne $two.artifactPath) 'Same filename with different bytes must produce distinct immutable identities.'
    $rejected=$false
    try{& (Join-Path $root 'scripts/Stage-OctaneArtifact.ps1') -Installer $source -OutputDirectory $artifactDirectory -ProducerSha256 ('0'*64) | Out-Null}catch{$rejected=$true}
    Check $rejected 'Producer hash mismatch must reject the artifact.'

    . (Join-Path $root 'scripts/FileAccess.ps1')
    $inputTree=Join-Path $temp 'input tree ü'
    New-Item -ItemType Directory -Path $inputTree | Out-Null
    [IO.File]::WriteAllText((Join-Path $inputTree 'space ü.txt'),'unchanged',[Text.UTF8Encoding]::new($false))
    $inputOne=Get-OctaneDirectoryManifest -Path $inputTree
    $inputTwo=Get-OctaneDirectoryManifest -Path $inputTree
    Assert-OctaneDirectoryManifest -Expected $inputOne -Actual $inputTwo
    Check ($inputOne.fileCount -eq 1) 'Input manifest must preserve a space/Unicode file identity.'
    [IO.File]::AppendAllText((Join-Path $inputTree 'space ü.txt'),'changed')
    $changed=$false
    try{Assert-OctaneDirectoryManifest -Expected $inputOne -Actual (Get-OctaneDirectoryManifest -Path $inputTree)}catch{$changed=$true}
    Check $changed 'Input integrity comparison must detect changed bytes.'

    . (Join-Path $root 'scripts/RunState.ps1')
    $activeRuns=Join-Path $temp 'active-runs'
    $activeRecord=Join-Path $activeRuns 'octane-0123456789.json'
    Initialize-OctaneRunState -Path $activeRecord -Identity @{
        runId='0123456789';container='octane-0123456789';image='candidate';engine='Docker';engineContext='docker:wsl:test';wslDistro='test';wineProfile='browser';baseImage='candidate';port=3005;endpointKind='Http';installerSha256=('a'*64)
    } | Out-Null
    Set-OctaneActiveRun -RunsDirectory $activeRuns -Container 'octane-0123456789' -RunId '0123456789' -Port 3005 -State RUNNING | Out-Null
    $active=Get-OctaneActiveRun -RunsDirectory $activeRuns
    Check ($active.record.container -eq 'octane-0123456789') 'Active-run journal must resolve through an immutable run record.'
    Check (-not (Clear-OctaneActiveRun -RunsDirectory $activeRuns -Container octane-aaaaaaaaaa)) 'Unrelated cleanup must not clear the active-run journal.'
    Check (Clear-OctaneActiveRun -RunsDirectory $activeRuns -Container octane-0123456789) 'Exact cleanup must clear the matching active-run journal.'

    . (Join-Path $root 'scripts/RuntimeProfiles.ps1')
    $browser=Get-OctaneWineProfile -WineProfile DockerWineStaging1121VisRgnBrowser
    Check ($browser.EndpointKind -eq 'Http' -and $browser.EndpointPath -eq '/octane.html') 'Browser profile must expose the exact HTTP viewer path.'
    Check ($browser.ProfileKind -eq 'DockerWineBrowser' -and $browser.ContainerPort -eq 3000) 'Browser profile must be distinct from RDP profiles.'
    Check ($browser.BuildArguments.NOVNC_COMMIT -match '^[a-f0-9]{40}$' -and $browser.BuildArguments.WEBSOCKIFY_COMMIT -match '^[a-f0-9]{40}$') 'Browser dependencies must be commit pinned.'

    $viewer=Get-Content -LiteralPath (Join-Path $root 'lab/browser/octane.html') -Raw
    foreach($state in @('viewer-page-loaded','websocket-attempted','credentials-required','vnc-negotiated','security-negotiation-failed','disconnected-unclean')){
        Check ($viewer.Contains($state)) "Viewer must expose state '$state'."
    }
    Check ($viewer -notmatch 'password=.*(?:[&#]|$)') 'Viewer must not place credentials in a URL.'
    Check ($viewer -match 'upload-file' -and $viewer -match 'Authorization.*Bearer') 'Viewer must provide an authenticated, explicit file-selection control.'
    $session=Get-Content -LiteralPath (Join-Path $root 'lab/browser/octane-browser-session') -Raw
    Check ($session -match '-passwdfile "\$password_file"') 'VNC authentication must use the per-run password file.'
    Check ($session -match '--auth-plugin ExpectOrigin') 'WebSocket origin validation must be configured.'
    Check ($session -match '-rfbportv6 0 -listen 127\.0\.0\.1 -listen6 ::1') 'Raw VNC listeners must be constrained to container loopback on IPv4 and IPv6.'
    Check ($session -match '\$state_dir/browser-session\.json') 'Viewer session identity must be written inside per-run user-owned state.'
    Check ($session -notmatch 'xrdp|xfreerdp|freerdp') 'Browser session must not invoke an RDP component.'
    Check ($session -match 'octane-upload-server' -and $session -match 'OCTANE_UPLOAD_PUBLIC_URL') 'Browser session must start and identify the scoped upload service.'
    Check ($session -match 'OCTANE_DISPLAY_SERVER' -and $session -match 'displayServer') 'Browser evidence must identify the effective X11 display-server profile.'
    $uploadServer=Get-Content -LiteralPath (Join-Path $root 'lab/browser/octane-upload-server') -Raw
    Check ($uploadServer -match 'hmac\.compare_digest' -and $uploadServer -match 'ALLOWED_ORIGINS') 'Upload service must authenticate and enforce exact origins.'
    Check ($uploadServer -match 'destination-exists' -and $uploadServer -notmatch 'do_DELETE') 'Upload service must reject overwrite and expose no delete API.'
    Check ($uploadServer -notmatch 'send_file|SimpleHTTPRequestHandler') 'Upload service must not expose a file-download server.'
    $preview=Get-Content -LiteralPath (Join-Path $root 'scripts/Start-OctanePreview.ps1') -Raw
    Check ($preview -notmatch 'Write-Output\s+"Password:') 'Preview startup must not echo the viewer credential into controller output.'
    Check ($preview -match 'Get-OctaneViewerCredential\.ps1') 'Preview startup must direct the operator to explicit credential retrieval.'
    Check ($preview -match 'New-OctaneRuntimeSecretFile') 'Preview startup must stage its bind source inside the selected WSL distribution.'
    Check ($preview -match 'New-OctaneRuntimeSessionStorage' -and $preview -match 'lifecycleMode') 'Preview startup must create exact WSL-native per-run storage and record lifecycle mode.'
    Check ($preview.IndexOf('Stage-OctaneArtifact.ps1') -lt $preview.IndexOf('Collect-OctanePreview.ps1')) 'A replacement must stage and validate the new installer before collecting/removing the active run.'
    Check ($preview.IndexOf('Collect-OctanePreview.ps1') -lt $preview.IndexOf('Stop-OctaneLab.ps1')) 'A replacement must collect the active run before exact removal.'
    $runtime=Get-Content -LiteralPath (Join-Path $root 'scripts/Runtime.ps1') -Raw
    Check ($runtime -match 'StandardInput \$Secret') 'WSL-native credential staging must send the secret over standard input rather than command arguments.'
    Check ($runtime -match '/var/lib/octane/sessions/\$Container' -and $runtime -match 'octane-session-storage') 'Runtime storage must be run-scoped and marker-verified before deletion.'
    $stop=Get-Content -LiteralPath (Join-Path $root 'scripts/Stop-OctaneLab.ps1') -Raw
    Check ($stop -match 'Remove-OctaneRuntimeSecretFile') 'Exact run cleanup must remove the distro-local credential file.'
    Check ($stop -match 'Remove-OctaneRuntimeSessionStorage' -and $stop -match 'Clear-OctaneActiveRun') 'Exact cleanup must remove only the run-owned WSL storage and matching active journal.'
    $target=Get-Content -LiteralPath (Join-Path $root 'lab/browser/octane-target') -Raw
    Check ($target -match 'WebView2 drift') 'Target launcher must fail visibly on a declared WebView2 version mismatch.'
    Check ($target -match 'wait_stable' -and $target -match 'application-stability\.json') 'Target launcher must implement an attributable sustained-readiness gate.'
    Check ($target -match 'relaunchUsed:false' -and $target -match 'forcedRepaintUsed:false') 'Sustained readiness evidence must explicitly exclude relaunch and forced repaint.'
    Check ($preview -match "octane-target','wait-stable" -and $preview -match 'readinessStabilitySeconds') 'Preview startup must enforce the profile-locked sustained-readiness interval.'
    $referenceProfile=Get-Content -LiteralPath (Join-Path $root 'profiles/applications/octane-reference.app.json') -Raw | ConvertFrom-Json
    Check ([int]$referenceProfile.application.readinessStabilitySeconds -ge 90) 'The retained reference profile must observe readiness beyond the delayed failure seen in browser smoke testing.'
    $xorgDockerfile=Get-Content -LiteralPath (Join-Path $root 'lab/Dockerfile.browser-xorgdummy') -Raw
    $xorgEntrypoint=Get-Content -LiteralPath (Join-Path $root 'lab/browser/octane-xorg-entrypoint') -Raw
    Check ($xorgDockerfile -match 'xserver-xorg-video-dummy' -and $xorgDockerfile -match 'browser-rdp-required="false"') 'Xorg candidate must use the dummy driver and retain the no-RDP identity.'
    Check ($xorgEntrypoint -match '-nolisten tcp' -and $xorgEntrypoint -match '-auth "\$authority"') 'Standalone Xorg must disable TCP and require a per-container Xauthority cookie.'
    Check ($xorgEntrypoint -notmatch 'chown\s+wineuser') 'Xorg startup must not assume the base entrypoint has already created its runtime account.'
    Check ($xorgEntrypoint -notmatch '(?m)^[^#\r\n]*(?:xrdp|xfreerdp|freerdp)') 'Standalone Xorg candidate must not invoke an RDP component.'

    $scriptText=(Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1' | ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw}) -join "`n"
    Check ($scriptText -notmatch '\bInvoke-Expression\b') 'Controller must not use Invoke-Expression.'
    $parseErrors=@()
    foreach($script in Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1'){
        $tokens=$null;$errors=$null
        [void][Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)
        $parseErrors+=@($errors | ForEach-Object {"$($script.Name): $($_.Message)"})
    }
    Check ($parseErrors.Count -eq 0) ("All PowerShell scripts must parse. " + ($parseErrors -join '; '))
    Write-Output "Browser/runtime contract: $assertions assertions passed (static/unit scope; not browser GUI acceptance)."
}finally{
    if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
