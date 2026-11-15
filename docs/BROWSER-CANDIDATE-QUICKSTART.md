# Browser candidate operator quick start

This is the operator workflow for the current **unqualified diagnostic candidate**. Historical RDP commands are intentionally absent. Authenticated noVNC negotiation and framebuffer delivery have been observed, but the retained Octane/WebView2 browser process did not remain stable on the tested Xvfb, standalone-Xorg, or Xvnc profiles. Use this workflow for diagnosis only; do not treat a viewer connection, native frame, or first WebView2 process as application readiness.

## Packaged appliance (recommended operator path)

The extracted private `Octane-v1` package is self-contained at the runtime layer: it carries an importable Ubuntu 24.04 WSL rootfs, pinned Docker management tooling, the checksum-verified compressed Wine/browser image archive, the provider-neutral runtime kit, profiles, and docs. It does not include a target installer or credentials.

Run in Windows PowerShell 7 from the extracted package:

```powershell
# Verify all declared package/runtime hashes and show the plan only.
./Install-Octane.ps1 -PackageRoot $PWD -PlanOnly

# Import the dedicated Octane WSL appliance and load the pinned image once.
./Install-Octane.ps1 -PackageRoot $PWD
```

The import must already be permitted by organizational WSL policy. It does not enable WSL, install Windows features, elevate the Windows process, alter another distro, or bypass application control. The installer refuses an existing `Octane` distro or launcher directory rather than replacing it.

Open a new PowerShell terminal after PATH changes:

```powershell
octane doctor -Deep
octane target -Id example-app `
  -TargetOutput 'C:\Octane Targets\example-app-octane'

# Review and complete app.json before marking installer arguments verified.
octane open 'C:\Builds\setup.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -BuildLabel 'pipeline-12345'
```

Normal `open` validates and immutably stages the new installer before touching the existing run. It then collects and removes the exact previous active session, creates fresh WSL-native application state, copies the new per-run credential to the Windows clipboard, and opens the exact `http://127.0.0.1:<port>/octane.html` URL with the Windows default-browser association. Use `-NoBrowser` when policy blocks automatic opening; the application stays inside Wine either way.

The viewer also exposes an authenticated file-upload control. Uploaded files are written atomically to this run only and appear read-only to the target at `C:\octane-input\uploaded`. Files supplied with `-InputDirectory` appear at `C:\octane-input\selected`; application exports use `C:\octane-output`. The upload service does not expose download, delete, or directory-browsing endpoints.

```powershell
octane status
octane collect -Container octane-0123456789
octane stop -Container octane-0123456789
```

`stop` collects an uncollected preview before deleting its exact marker-owned resources. For an intentionally parallel comparison, keep the active run and allocate a separate viewer/upload port pair:

```powershell
octane compare 'C:\Builds\setup-previous.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -Port 3010 -UploadPort 3011
```

Refreshed package test `2164864404` passed from a path containing spaces and Unicode: unique WSL import, Docker 29.6.2, exact image identity, fresh unchanged-installer run, native window/WebView2 identity, authenticated loopback noVNC/upload components, collection, exact stop, distro unregister, and storage cleanup. Browser negotiation/framebuffer/input remained NOT_RUN, so the package is still a candidate rather than a qualified browser release.

## Source-tree one-time checks

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
  -Image octane-lab:browser-appliance-v1-136944d `
  -HarnessCommit 136944da9e8b0ee4f3c6727613d062abbd958857

# Or verify and load the retained private recovery archive.
./scripts/Import-OctaneBrowserImage.ps1 `
  -ArchivePath 'C:\Approved\octane-wine-image-136944d.tar' `
  -ExpectedSha256 5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe `
  -ExpectedImageId sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a `
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
  -Port 3005 -UploadPort 3006 `
  -Image octane-lab:browser-appliance-v1-136944d `
  -BuildLabel 'pipeline-12345' `
  -LifecycleMode ReplaceActive
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
4. Open the real native file picker and select controlled files from `C:\octane-input\selected`; separately upload a controlled file with the Octane upload control and select it from `C:\octane-input\uploaded`.
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

## Historical handoff state

At the candidate checkpoint, run `octane-c71f9b509b` was retained at `http://127.0.0.1:3005/octane.html`. It has since been removed by exact cleanup. No live endpoint is shipped or left behind. Recreate a diagnostic run with the Preview command above and use the emitted run identity and URL; never reuse the historical container name or assume port 3005 is occupied by Octane.

```powershell
# Expected to report that the historical run is absent.
./scripts/Show-OctaneManualBrowserHandoff.ps1 `
  -Container octane-c71f9b509b -WslDistro Ubuntu-24.04
```

Do not substitute `/`, an old port, RDP, or direct X11 automation. The current candidates are diagnostic only and are expected to fail the sustained WebView2 readiness gate until the recorded browser-process defect is resolved.
