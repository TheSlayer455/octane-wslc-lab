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
if(-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)){throw "Run metadata not found: $metadataPath"}
$run=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if(-not $run.targetPreview -or [string]$run.targetId -ne 'octane-reference'){throw 'The trusted reference browser scenario may run only against an identified octane-reference preview.'}
if([string]$run.state -ne 'RUNNING'){throw "Preview is not running: $($run.state)"}
if(-not $WslDistro){$WslDistro=[string]$run.wslDistro}
[void](Assert-OctaneContainer -Name $Container -Engine Docker -WslDistro $WslDistro)

$secretPath=Join-Path $root "runs/secrets/$Container/viewer-password"
if(-not (Test-Path -LiteralPath $secretPath -PathType Leaf)){throw 'Per-run browser credential is unavailable.'}
$automationRoot=Join-Path $root 'automation/browser'
$nodeModules=Join-Path $automationRoot 'node_modules/playwright'
if(-not (Test-Path -LiteralPath $nodeModules -PathType Container)){
    throw 'Pinned Playwright qualification dependencies are absent. Run the documented qualification-client preparation command.'
}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root "evidence/$Container-browser-scenario-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))"}
$out=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $out){throw "Browser scenario evidence directory already exists: $out"}
New-Item -ItemType Directory -Path (Join-Path $out 'logs') -Force | Out-Null

$nodeProbe=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @('-d',$WslDistro,'--exec','bash','-lc','command -v node') -TimeoutSeconds 30
$nodePath=$nodeProbe.StdOut.Trim()
if($nodeProbe.ExitCode -ne 0 -or -not $nodePath.StartsWith('/')){throw "Node.js is unavailable inside $WslDistro for the qualification client."}
$scriptRuntime=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path (Join-Path $automationRoot 'octane-reference-scenario.mjs')
$secretRuntime=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $secretPath
$outputRuntime=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $out
$url="http://127.0.0.1:$([int]$run.port)/octane.html"

$browser=Invoke-OctaneNativeProcess -FileName 'wsl.exe' -Arguments @(
    '-d',$WslDistro,'--exec',$nodePath,$scriptRuntime,
    '--url',$url,'--password-file',$secretRuntime,'--output',$outputRuntime,'--run-id',[string]$run.runId
) -TimeoutSeconds 300
$browser.StdOut | Set-Content -LiteralPath (Join-Path $out 'logs/browser-client.stdout.log') -Encoding utf8
$browser.StdErr | Set-Content -LiteralPath (Join-Path $out 'logs/browser-client.stderr.log') -Encoding utf8
if($browser.TimedOut -or $browser.ExitCode -ne 0){throw "Browser reference scenario failed. $($browser.StdErr.Trim())"}

$scenarioPath=Join-Path $out 'browser-scenario.json'
if(-not (Test-Path -LiteralPath $scenarioPath -PathType Leaf)){throw 'Browser client did not produce browser-scenario.json.'}
$browserScenario=Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
if([string]$browserScenario.status -ne 'PASS' -or [bool]$browserScenario.forcedRepaintUsed -or [int]$browserScenario.hiddenRetries -ne 0 -or [int]$browserScenario.manualOverrides -ne 0){
    throw 'Browser client result violates the unattended qualification contract.'
}

$reportPath=Join-Path $out 'browser-qualified-report.json'
$eventsPath=Join-Path $out 'viewer-events.json'
$reportRuntime=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $reportPath
$eventsRuntime=ConvertTo-OctaneRuntimePath -Engine Docker -WslDistro $WslDistro -Path $eventsPath
Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',"$Container`:/home/wineuser/.octane/output/browser-qualified-report.json",$reportRuntime) -TimeoutSeconds 60 | Out-Null
Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('cp',"$Container`:/home/wineuser/.octane/evidence/browser-viewer/viewer-events.json",$eventsRuntime) -TimeoutSeconds 60 | Out-Null
& (Join-Path $PSScriptRoot 'Validate-OctaneReport.ps1') -ReportPath $reportPath -FixtureDirectory (Join-Path $root 'fixtures') -OutputPath (Join-Path $out 'report-validation.json') | Out-Null

$events=Get-Content -LiteralPath $eventsPath -Raw | ConvertFrom-Json
$matching=@($events.events | Where-Object {[string]$_.runId -eq [string]$run.runId})
$negotiated=@($matching | Where-Object event -eq 'vnc-negotiated')
$frames=@($matching | Where-Object event -eq 'browser-frame')
$richFrames=@($frames | Where-Object {[int]$_.detail.canvasWidth -eq 1280 -and [int]$_.detail.canvasHeight -eq 800 -and [int]$_.detail.sampledUniqueColors -gt 100})
$frameHashes=@($richFrames | ForEach-Object {[string]$_.detail.rgbaSha256} | Sort-Object -Unique)
$inputs=@($matching | Where-Object event -eq 'browser-input')
$lastInput=$inputs | Select-Object -Last 1
if($negotiated.Count -lt 1){throw 'Authenticated browser telemetry did not record VNC negotiation.'}
if($richFrames.Count -lt 1 -or $frameHashes.Count -lt 2){throw 'Browser telemetry did not record changing, visually rich 1280x800 framebuffer content.'}
if(-not $lastInput -or [int]$lastInput.detail.pointer -lt 1 -or [int]$lastInput.detail.keyboard -lt 1 -or [int]$lastInput.detail.wheel -lt 1){
    throw 'Browser telemetry did not record pointer, keyboard, and wheel input on the connected noVNC surface.'
}

$requiredActions=@(
    'vnc-negotiated','load-sample-set','open-dialog-for-cancel','cancel-open-dialog',
    'open-dialog-for-eight-file-selection','type-eight-file-selection','accept-eight-file-selection',
    'save-dialog-for-cancel','cancel-save-dialog','save-dialog-for-export','accept-save-dialog',
    'post-export-responsiveness-open','post-export-responsiveness-cancel','browser-wheel-scroll'
)
$actualActions=@($browserScenario.actions.action)
$missingActions=@($requiredActions | Where-Object {$_ -notin $actualActions})
if($missingActions.Count -ne 0){throw "Browser action trace is incomplete: $($missingActions -join ', ')"}

$inputCheck=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$Container,'octane-target','verify-inputs') -TimeoutSeconds 120 -AllowFailure
if($inputCheck.ExitCode -ne 0 -or $inputCheck.TimedOut){throw 'Input integrity verification failed after browser interaction.'}
$noRdp=Invoke-OctaneRuntime -Engine Docker -WslDistro $WslDistro -Arguments @('exec','-u','wineuser',$Container,'bash','-lc',"! pgrep -af '(^|/)(xrdp|xrdp-sesman|xfreerdp|wlfreerdp)( |`$)' && ! ss -lntH | grep -Eq ':(3389|3350)([[:space:]]|`$)'") -TimeoutSeconds 60 -AllowFailure
if($noRdp.ExitCode -ne 0 -or $noRdp.TimedOut){throw 'RDP process or listener appeared during the browser scenario.'}

$result=[ordered]@{
    schemaVersion=1;status='PASS';scope='Unattended reference application scenario through the browser-delivered noVNC framebuffer and input path.'
    runId=[string]$run.runId;container=$Container;recordedAtUtc=[DateTime]::UtcNow.ToString('o')
    client=$browserScenario.client;viewer=$url;manualOperatorActions=0;forcedRepaintUsed=$false;hiddenRetries=0;rdpUsed=$false
    checks=[ordered]@{
        vncNegotiation='PASS';browserFramebuffer='PASS';browserPointerInput='PASS';browserKeyboardInput='PASS';browserWheelInput='PASS'
        initialVisible='PASS';continuingRepaint='PASS';rustWorkload='PASS';nativeOpenCancelAndRepeat='PASS';nativeSaveCancelAndExport='PASS'
        exportedReportValidation='PASS';postDialogResponsive='PASS';inputIntegrity='PASS';noRdp='PASS'
    }
    evidence=[ordered]@{browserScenario='browser-scenario.json';viewerEvents='viewer-events.json';report='browser-qualified-report.json';reportValidation='report-validation.json';screenshots=@($browserScenario.screenshots.file)}
}
Write-OctaneJsonAtomic -Path (Join-Path $out 'browser-reference-result.json') -Value $result
Copy-Item -LiteralPath $metadataPath -Destination (Join-Path $out 'run-before-browser-review.json')
Update-OctaneEvidenceChecksums -Directory $out

Update-OctaneRunStage -Path $metadataPath -Stage application -Status PASS -Detail 'Installed Octane rendered and continued repainting through the authenticated browser framebuffer; no repaint helper or relaunch was used.'
Update-OctaneRunStage -Path $metadataPath -Stage workload -Status PASS -Detail 'Browser-originated input selected the exact eight fixtures through the installed GUI and produced the 8-file/6-group/1-duplicate/176-byte result.'
Update-OctaneRunStage -Path $metadataPath -Stage nativeDialogs -Status PASS -Detail 'Browser-originated keyboard/pointer input cancelled and reopened native open/save dialogs and returned to a responsive app.'
Update-OctaneRunStage -Path $metadataPath -Stage export -Status PASS -Detail 'The native save dialog created browser-qualified-report.json and independent validation passed.'
Set-OctaneRunMetadata -Path $metadataPath -Values @{browserEndToEndStatus='PASS';browserEndToEndReason='Trusted unattended browser reference scenario passed.';browserScenarioEvidence=$out;browserAutomationClient='WSL Playwright Chromium';manualBrowserSmokeSeparate=$true}
Copy-Item -LiteralPath $metadataPath -Destination (Join-Path $out 'run-after-browser-review.json')
Update-OctaneEvidenceChecksums -Directory $out
Write-Output "Browser reference scenario evidence: $out"
Write-Output 'Result: PASS (browser negotiation/framebuffer/input, workload, dialogs, export, integrity, and no-RDP checks).'
