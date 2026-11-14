# Octane Windows installer container lab

Octane runs an unchanged Windows x64 installer inside a fresh Docker/Wine environment in WSL2. The delivered candidate streams the Linux X11 desktop containing the real Wine application to a localhost browser with no RDP dependency. It never installs the target on Windows, recompiles it, substitutes a Linux build, or turns the Tauri frontend into a website.

Current status is deliberately split:

- Historical Docker/Wine Octane qualification: **PASS 10/10** for the immutable RDP-era lock and retained installer.
- Browser candidate components: **PASS** for build, clean install, exact executable/WebView2 identity, X11/VNC/Websockify health, loopback publication, authentication configuration, no-RDP enforcement, evidence, and exact cleanup.
- Manual browser smoke: **NOT_RUN** unless an operator supplies attributable evidence.
- Automated browser acceptance and browser 10/10 qualification: **BLOCKED** because this execution environment has no approved controllable browser.
- Browser runtime kit release: **not qualified** while the mandatory browser gates remain blocked.

The canonical AI/operator reference is [docs/OCTANE-AI-HANDOFF.md](docs/OCTANE-AI-HANDOFF.md). The short operator path is [docs/BROWSER-CANDIDATE-QUICKSTART.md](docs/BROWSER-CANDIDATE-QUICKSTART.md). Historical results remain in [docs/compatibility-matrix.md](docs/compatibility-matrix.md) and the comprehensive [PDF guide](docs/Octane-Complete-Guide.pdf).

## Browser candidate quick start

Run from Windows PowerShell 7 at the repository root. The commands below are locally exercised; replace only the angle-bracket values.

```powershell
# Read-only host/runtime preflight. Docker is explicitly inside this WSL distro.
./scripts/Doctor-OctaneLab.ps1 -Engine Docker `
  -WslDistro Ubuntu-24.04 -Port 3005 -Deep

# Create a small target overlay. This does not copy source or installer bytes.
./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane

# After verifying installer flags, executable identity, and window title in app.json:
./scripts/Test-OctaneTargetProfile.ps1 `
  -Profile ../example-app-octane/app.json -Operational

# Start a clean preview from the external EXE and explicitly selected folders.
./scripts/Start-OctanePreview.ps1 `
  -Profile ../example-app-octane/app.json `
  -Installer 'C:\Builds\setup.exe' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -WslDistro Ubuntu-24.04 -Port 3005 `
  -Image octane-lab:browser-candidate-v1
```

Startup prints the exact `http://127.0.0.1:PORT/octane.html` URL and container name. It does not print the credential. Copy that one run's password to the Windows clipboard explicitly:

```powershell
./scripts/Get-OctaneViewerCredential.ps1 -Container octane-0123456789
./scripts/Show-OctaneManualBrowserHandoff.ps1 `
  -Container octane-0123456789 -WslDistro Ubuntu-24.04
```

Open the exact URL in an organization-approved Windows browser, paste the password into the viewer form, and treat “VNC negotiated” only as transport evidence. Application readiness requires seeing and interacting with the actual client area.

Collect before stopping:

```powershell
./scripts/Collect-OctanePreview.ps1 `
  -Container octane-0123456789 -WslDistro Ubuntu-24.04 `
  -ScreenshotDirectory 'C:\Evidence\browser-smoke'

./scripts/Stop-OctaneLab.ps1 `
  -Container octane-0123456789 -Engine Docker `
  -WslDistro Ubuntu-24.04
```

Each run receives a new container, Wine prefix, installation, application data, WebView2 user-data directory, and writable output directory. The stable image and content-addressed installer cache may be reused; an installed application prefix is never reused as a clean run.

## Exact browser candidate

- Runtime harness commit: `b227260e579bc4806cbd92659ea9956b06fbb253`.
- Local image ID: `sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba`.
- Browser candidate lock: `profiles/candidates/docker-wine-staging-11.21-visrgn-browser.candidate.lock.json`.
- Lock status: `candidate-end-to-end-blocked`; this is not a qualification lock.
- Browser: noVNC commit `63107bd06d9e1f6136ff21aeda8cd62cbf0d433e` and Websockify commit `e81894751365afc19fe64fc9d0e5c6fc52655c36`.
- Display: Xvfb/XFCE `:1`, 1280x800, x11vnc loopback-only inside the container, Websockify as the only published service.
- Wine: pinned Wine/Staging 11.21 plus the retained visible-region patch; WebView2 Evergreen `157.0.4341.60` for the reference profile.

The browser endpoint is plaintext HTTP on loopback only, authenticated with an eight-character per-run RFB password (the protocol limit). Raw VNC is not published. Clipboard and remote desktop resizing are disabled. Do not expose this profile to a LAN or use it as a multi-user gateway.

## Historical qualification boundary

The immutable historical lock `profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json` and batch `qbatch-e2aaafff4b38` qualified the retained Octane installer through XFCE/Xorgxrdp. That proves technical feasibility and full acceptance for that exact RDP-era configuration. It does **not** qualify noVNC, browser-delivered input, another installer, stock Wine, or arbitrary Tauri applications.

The minimal native Win32 WebView2 probe still renders a white client. The custom Wine patch remains a maintenance condition. Podman, Proton, CrossOver, Docker Desktop, host-GPU passthrough, VPN work, Windows VMs, and target-source changes remain out of scope.

## Provider and security boundaries

The core accepts a local EXE, application profile, fixtures, and output directory. GitHub/GitLab download or upload steps are optional wrappers. Profiles are data only; trusted scenario code must come from the repository. No workflow uses `Invoke-Expression`, mounts the Docker socket, mounts a broad Windows drive, enables privileged/host networking, adds ptrace, passes `--no-sandbox`, or silently changes Docker context/distro/runtime.

The repository is private and has no open-source license grant. Third-party components retain their own licenses. Installer bytes, image archives, credentials, and raw evidence remain outside ordinary Git history.
