[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^octane-[a-f0-9]{10}$')][string]$Container,
    [string]$WslDistro
)

$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'Runtime.ps1')
$metadataPath=Join-Path $root "runs/$Container.json"
if(-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)){throw "Run metadata not found: $metadataPath"}
$run=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if(-not $WslDistro){$WslDistro=[string]$run.wslDistro}
$inspect=Assert-OctaneContainer -Name $Container -Engine Docker -WslDistro $WslDistro
if(-not $inspect.State.Running){throw "$Container is not running. Recreate it with the recorded profile and artifact rather than assuming the old endpoint is live."}
$viewer=[string]$run.desktopAddress
if(-not $viewer){$viewer="http://127.0.0.1:$($run.port)/octane.html"}
Wait-OctaneEndpoint -Kind Http -Port ([int]$run.port) -Path '/octane.html' -TimeoutSeconds 15 | Out-Null
Write-Output 'MANUAL BROWSER SMOKE TEST — operator-performed; never counted as unattended qualification'
Write-Output "Run: $($run.runId)  Container: $Container"
Write-Output "Image: $($run.image)  Resolved image ID: $($run.resolvedImageId)"
Write-Output "Artifact: $($run.artifactId)"
Write-Output "Profile SHA-256: $($run.targetProfileSha256)"
Write-Output "Viewer: $viewer"
Write-Output "Credential: ./scripts/Get-OctaneViewerCredential.ps1 -Container $Container"
Write-Output ''
Write-Output 'In an organization-approved Windows browser:'
Write-Output '1. Open the exact Viewer URL and enter the per-run password in the page form.'
Write-Output '2. Require the state “VNC negotiated; application readiness unverified,” then confirm the actual application client area is visible.'
Write-Output '3. Confirm normal initial rendering without resize/minimize/restore or click-to-wake.'
Write-Output '4. Use mouse, keyboard, and scrolling through the browser viewer.'
Write-Output '5. Select controlled files from C:\octane-input; cancel and reopen the native open dialog.'
Write-Output '6. Export through the real native save dialog to C:\octane-output.'
Write-Output '7. Confirm the target remains responsive after dialogs. Validate any exported report independently.'
Write-Output ''
Write-Output "Collect: ./scripts/Collect-OctanePreview.ps1 -Container $Container -WslDistro '$WslDistro' -ScreenshotDirectory '<operator browser screenshots>'"
Write-Output "Stop:    ./scripts/Stop-OctaneLab.ps1 -Container $Container -Engine Docker -WslDistro '$WslDistro'"
Write-Output 'If no attributable operator evidence is collected, leave all browser/application gates unverified.'
