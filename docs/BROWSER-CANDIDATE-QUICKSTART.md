# Browser candidate operator quick start

This is the normal browser workflow for the current **unqualified candidate**. Historical RDP commands are intentionally absent. Browser acceptance remains blocked until an approved browser path supplies real framebuffer and input evidence.

## One-time checks

Open Windows PowerShell 7 at the repository or extracted runtime-kit root:

```powershell
./scripts/Doctor-OctaneLab.ps1 -Engine Docker `
  -WslDistro Ubuntu-24.04 -Port 3005 -Deep
```

The doctor must identify Docker Engine in `Ubuntu-24.04`, the local Unix-socket context, Linux amd64, usable storage/memory, build capability, copy-out, exact cleanup, and Windows reachability of a loopback-published test endpoint. It rejects Docker Desktop and remote daemons on this Windows/WSL path.

The browser image is acquired in one of two explicit ways:

```powershell
# Build on top of the retained exact qualification image.
./scripts/Build-OctaneBrowserImage.ps1 `
  -WslDistro Ubuntu-24.04 `
  -Image octane-lab:browser-candidate-v1 `
  -HarnessCommit b227260e579bc4806cbd92659ea9956b06fbb253

# Or verify and load the retained private recovery archive.
./scripts/Import-OctaneBrowserImage.ps1 `
  -ArchivePath 'C:\Approved\octane-browser-candidate-b227260.tar' `
  -ExpectedSha256 6c1f4f9fd364ed970fc1ba1796a71952e2f917ae7603ea3cf10903d6209dbfb5 `
  -ExpectedImageId sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba `
  -WslDistro Ubuntu-24.04
```

The recovery path is private and local. A checksum detects byte changes; it is not a signature.

## Onboard one unchanged installer

```powershell
./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane
```

Review `../example-app-octane/app.json`. Do not guess silent flags, install scope, executable name, path, architecture, title, dependency policy, or reboot behavior. Set `installer.argumentsVerified=true` only after inspection. A data profile cannot run downloaded code or name an arbitrary scenario script.

```powershell
./scripts/Test-OctaneTargetProfile.ps1 `
  -Profile ../example-app-octane/app.json -Operational
```

## Preview one new pipeline EXE

Wait until the downloaded EXE is complete. Then run:

```powershell
./scripts/Start-OctanePreview.ps1 `
  -Profile ../example-app-octane/app.json `
  -Installer 'C:\Builds\setup.exe' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -WslDistro Ubuntu-24.04 `
  -Port 3005 `
  -Image octane-lab:browser-candidate-v1 `
  -BuildLabel 'pipeline-12345'
```

The command streams and hashes the EXE, atomically admits it to an immutable cache identity, verifies the copied bytes again inside the container, creates a fresh prefix/install/user-data tree, launches the exact discovered executable, and prints the exact viewer URL. It never executes the installer on Windows.

Copy the credential without printing it:

```powershell
./scripts/Get-OctaneViewerCredential.ps1 -Container octane-0123456789
```

Open the printed URL, normally `http://127.0.0.1:3005/octane.html`, in an approved Windows browser. Paste the credential into the page form. The visible state sequence is page loaded, WebSocket attempted, credentials required if needed, VNC negotiated, or a named security/disconnect failure. “VNC negotiated” does not mean the application is ready.

## Manual smoke checklist

Use only the browser viewer for application interaction:

1. Confirm the actual application client area, not only the viewer, desktop, or empty frame.
2. Confirm normal initial rendering without resize/minimize/restore, reconnect, click-to-wake, relaunch, or a repaint helper.
3. Use mouse, keyboard, focus, and scrolling through the viewer.
4. Open the real native file picker and select controlled files from `C:\octane-input`.
5. Cancel and reopen the picker; confirm the app remains responsive.
6. Export through the native save dialog to `C:\octane-output`.
7. Validate the collected output independently and confirm selected host input hashes did not change.

Record this as an operator browser smoke test. One manual pass is not unattended qualification and cannot be added to the ten-run batch.

## Collect and stop

```powershell
./scripts/Collect-OctanePreview.ps1 `
  -Container octane-0123456789 `
  -WslDistro Ubuntu-24.04 `
  -ScreenshotDirectory 'C:\Evidence\browser-smoke'

./scripts/Stop-OctaneLab.ps1 `
  -Container octane-0123456789 `
  -Engine Docker -WslDistro Ubuntu-24.04
```

Collection precedes deletion. Stop removes only the exact asserted managed container and that run's ignored credential directory. It never prunes globally or shuts down WSL.

## Current known live handoff

At the time of the candidate checkpoint, run `octane-c71f9b509b` was deliberately retained at `http://127.0.0.1:3005/octane.html` for an operator smoke test. Never assume it is still alive: first run the handoff verifier.

```powershell
./scripts/Show-OctaneManualBrowserHandoff.ps1 `
  -Container octane-c71f9b509b -WslDistro Ubuntu-24.04
```

If that command says the run is absent, recreate it with the Preview command above. Do not substitute `/`, an old port, RDP, or direct X11 automation.
