# Octane Windows installer container lab

Octane runs an unchanged Windows x64 installer inside a fresh Docker/Wine environment in WSL2. The delivered candidate streams the Linux X11 desktop containing the real Wine application to a localhost browser with no RDP dependency. It never installs the target on Windows, recompiles it, substitutes a Linux build, or turns the Tauri frontend into a website.

Current status is deliberately split:

- Historical Docker/Wine Octane qualification: **PASS 10/10** for the immutable RDP-era lock and retained installer.
- Browser candidate components: **PASS** for build, clean install, exact executable/WebView2 identity, X11/VNC/Websockify health, loopback viewer/upload publication, authentication/origin enforcement, WSL-native session storage, no-RDP enforcement, evidence, and exact cleanup.
- Self-contained WSL appliance candidate: **PASS** for hash verification, `wsl --import`, pinned Docker 29.6.2 startup, separate image load, deep doctor, unchanged-installer preview/component checks, collection, and exact distro/container cleanup. This still is not browser framebuffer/input acceptance.
- Manual browser smoke: **NOT_RUN** unless an operator supplies attributable evidence.
- Automated browser acceptance and browser 10/10 qualification: **BLOCKED** because this execution environment has no approved controllable browser.
- Browser runtime kit release: **not qualified** while the mandatory browser gates remain blocked.

The canonical AI/operator reference is [docs/OCTANE-AI-HANDOFF.md](docs/OCTANE-AI-HANDOFF.md). The short operator path is [docs/BROWSER-CANDIDATE-QUICKSTART.md](docs/BROWSER-CANDIDATE-QUICKSTART.md). Historical results remain in [docs/compatibility-matrix.md](docs/compatibility-matrix.md) and the comprehensive [PDF guide](docs/Octane-Complete-Guide.pdf).

## Packaged appliance quick start

The private `Octane-v1` candidate packages the management distribution and Wine/browser image separately:

```text
Octane-v1/
  Install-Octane.ps1
  Octane.ps1 / Octane.cmd / Uninstall-Octane.ps1
  appliance/octane-ubuntu.tar
  images/octane-wine-image.tar.zst
  runtime/
  profiles/ docs/ manifest.json checksums.sha256
```

From Windows PowerShell 7 in the extracted package:

```powershell
# Hash/check the whole install plan without changing host state.
./Install-Octane.ps1 -PackageRoot $PWD -PlanOnly

# One-time import. This does not need an existing Ubuntu distro or Docker install.
./Install-Octane.ps1 -PackageRoot $PWD

# Open a new terminal after PATH is updated.
octane doctor -Deep
octane target -Id example-app `
  -TargetOutput 'C:\Octane Targets\example-app-octane'

# After reviewing and completing the generated data-only app.json:
octane open 'C:\Builds\setup.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results'
```

`octane open` first hashes and stages the unchanged EXE. Only after that succeeds, it collects and removes the prior active run's exact disposable resources, creates a fresh WSL-native home/container/prefix/install, waits for the viewer and native application identity, copies the new run credential to the Windows clipboard, and opens the exact localhost URL in the default browser. It never launches the installer on Windows. If browser opening is blocked, use `-NoBrowser` and the printed URL plus `octane credential -Container <exact-name>`.

The viewer includes an authenticated, per-run upload control. It accepts explicit files only, caps each file at 512 MiB, writes atomically, rejects overwrite/path traversal, and exposes no download or directory-management API. Selected Windows inputs and uploaded inputs appear below `C:\octane-input`; output remains separate at `C:\octane-output`.

`octane stop` collects an uncollected target preview before exact cleanup. Explicit collection is still available:

```powershell
octane collect -Container octane-0123456789
octane stop -Container octane-0123456789
```

For an intentionally parallel comparison, choose a separate unused viewer/upload port pair:

```powershell
octane compare 'C:\Builds\setup-previous.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -Port 3010 -UploadPort 3011
```

Uninstall is deliberately separate and destructive. It verifies the appliance marker and exact distribution identity before unregistering:

```powershell
& "$env:LOCALAPPDATA\Octane\Uninstall-Octane.ps1" `
  -ConfirmDistributionRemoval
```

The release layout does not bake `/var/lib/docker` into the WSL TAR. Docker Engine lives in the imported Ubuntu appliance; the separately checksum-verified archive is streamed into `docker load`. Wine, WebView2, X11, noVNC, and the unchanged target live in the disposable Docker container.

## Source-tree browser candidate quick start

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
  -WslDistro Ubuntu-24.04 -Port 3005 -UploadPort 3006 `
  -Image octane-lab:browser-appliance-v1-136944d `
  -LifecycleMode ReplaceActive
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

Each run receives a new marker-journaled directory under `/var/lib/octane/sessions/<container>`, WSL-native home, container, Wine prefix, installation, application data, WebView2 user-data directory, upload staging, and writable output directory. The stable image and content-addressed installer cache may be reused; an installed application prefix is never reused as a clean run. Collected Windows outputs/evidence survive exact session cleanup.

## Exact browser/appliance lifecycle candidate

- Runtime harness commit: `136944da9e8b0ee4f3c6727613d062abbd958857`.
- Local image ID: `sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a`.
- Browser candidate lock: `profiles/candidates/docker-wine-staging-11.21-visrgn-browser-appliance-136944d.candidate.lock.json`.
- Lock SHA-256: `5227a24f4279a599679ff6adb00138776b93fd5205e8627ef11780b26acb4fff`.
- Lock status: `candidate-end-to-end-blocked`; this is not a qualification lock.
- Browser: noVNC commit `63107bd06d9e1f6136ff21aeda8cd62cbf0d433e` and Websockify commit `e81894751365afc19fe64fc9d0e5c6fc52655c36`.
- Display: Xvfb/XFCE `:1`, 1280x800, x11vnc loopback-only inside the container; only Websockify and the scoped upload service are published, both on Windows loopback.
- Wine: pinned Wine/Staging 11.21 plus the retained visible-region patch; WebView2 Evergreen `157.0.4341.60` for the reference profile.

The refreshed local appliance candidate uses executable harness commit `136944d`. Its WSL rootfs is 503,298,560 bytes, SHA-256 `1c8cb6e36a880dcf491aaa12dc1d52c0819824902a2b272b36d3837c451e3368`. The compressed image archive is 2,078,023,379 bytes, SHA-256 `bf47e58e50ef56396ee3e1d43fdecda5de0426ede6c37342609c01c154240b05`; its 2,083,894,784-byte Docker-save source is SHA-256 `5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe`. These are local candidate artifacts, not public download or browser-qualification claims.

Refreshed package test `2164864404` ran from `Octane Moonshot Extracted ü\Octane-v1` and passed unique WSL import, internal Docker/image load, deep doctor, fresh retained-installer preview, browser/upload/no-RDP component checks, collection, exact stop, distro unregister, and storage cleanup. Its package contained 84 files / 2,583,977,275 bytes. This is package/component evidence only; browser framebuffer/input and the browser 10/10 batch remain blocked.

The browser endpoint is plaintext HTTP on loopback only, authenticated with an eight-character per-run RFB password (the protocol limit). The same credential is reused in browser memory as a bearer value for the separate loopback upload port; it is not put in a URL or evidence. Raw VNC is not published. Clipboard and remote desktop resizing are disabled. Do not expose this profile to a LAN or use it as a multi-user gateway.

## Historical qualification boundary

The immutable historical lock `profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json` and batch `qbatch-e2aaafff4b38` qualified the retained Octane installer through XFCE/Xorgxrdp. That proves technical feasibility and full acceptance for that exact RDP-era configuration. It does **not** qualify noVNC, browser-delivered input, another installer, stock Wine, or arbitrary Tauri applications.

The minimal native Win32 WebView2 probe still renders a white client. The custom Wine patch remains a maintenance condition. Podman, Proton, CrossOver, Docker Desktop, host-GPU passthrough, VPN work, Windows VMs, and target-source changes remain out of scope.

## Provider and security boundaries

The core accepts a local EXE, application profile, fixtures, and output directory. GitHub/GitLab download or upload steps are optional wrappers. Profiles are data only; trusted scenario code must come from the repository. No workflow uses `Invoke-Expression`, mounts the Docker socket, mounts a broad Windows drive, enables privileged/host networking, adds ptrace, passes `--no-sandbox`, or silently changes Docker context/distro/runtime.

The source repository is public but currently has no open-source license grant. Third-party components retain their own licenses. Installer bytes, image archives, credentials, and raw evidence remain outside ordinary Git history and are not implied public downloads.
