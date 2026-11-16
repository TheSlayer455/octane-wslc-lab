# Octane Windows application container lab

Octane installs an unchanged Windows x64 installer inside a fresh Docker/Wine container in WSL2, then exposes the real Wine desktop through an authenticated localhost browser page. The browser is a pixel/input transport; it is not a rewritten frontend.

## Current verdicts

- Historical Docker/Wine/RDP reference contract: **QUALIFIED 10/10** for its immutable historical lock.
- Browser-only Octane reference contract: **QUALIFIED 10/10** for batch `browser-qbatch-06f2a54afe0c`, lock SHA-256 `db5babdf10bb9c3aef12731c398a75437d280385799512e1b92838f028d68249`, installer SHA-256 `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`, and image ID `sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786`.
- Generic unchanged-installer preview: implemented and exercised with two successive real installers from one independent public Tauri application. Build 2.1.1 passed the browser conversion/dialog/export scenario; clean replacement to build 2.2.0 passed, but that build crashed before usable readiness. The independent application is **NOT QUALIFIED**.
- Minimal native Win32 WebView2 probe: still **FAIL (white client)**. Octane's pass is not a universal WebView2/Wine claim.

The browser batch used ten predeclared, sequential fresh containers and Wine prefixes. All ten passed authenticated noVNC negotiation, changing browser framebuffer evidence, browser-originated pointer/keyboard/wheel input, normal initial rendering, the real Rust workload, native open/save dialogs, independent JSON validation, input integrity, no-RDP checks, evidence collection, and exact cleanup. No repaint helper, application relaunch, hidden scenario retry, manual action, or manual promotion was used.

See [the qualification summary](docs/browser-qualification-summary.json), [independent two-build result](docs/external-application-two-build-result.md), [compatibility matrix](docs/compatibility-matrix.md), and the canonical AI/operator handoff in [Markdown](docs/OCTANE-AI-HANDOFF.md) or [PDF](docs/OCTANE-AI-HANDOFF.pdf).

Public release: [Octane v1.0.0 — Browser appliance](https://github.com/TheSlayer455/octane-wslc-lab/releases/tag/v1.0.0). Download all three package assets and follow `v1.0.0-release-assets.json`; GitHub's server-side digests match the locally recorded SHA-256 values.

The v1 appliance lifecycle also passes from an extracted path containing spaces and Unicode: exact package/runtime hashes, unique WSL import, Docker startup, exact qualified-image load, deep doctor, fresh unchanged-installer preview, component checks, collection, exact stop, distro unregister, and storage cleanup. The final local package contains 98 files (2,586,061,421 bytes); its manifest SHA-256 is `02176b061918de85de755982ed085c41ee4c9d966d934d885a4492020d3fcbeb`. GitHub publication status is recorded separately.

## Architecture

```text
Windows 11
  Windows PowerShell launcher + default browser
       |
       | wsl.exe / localhost only
       v
Ubuntu 24.04 WSL appliance
  Docker Engine + Octane controller
       |
       v
fresh Docker container for each build
  patched Wine-Staging 11.21
  WebView2 Evergreen 157.0.4341.60
  TigerVNC Xvnc + XFCE
  Websockify + noVNC
  unchanged Windows installer and installed EXE
```

Docker belongs in the WSL appliance, not inside the application container. Wine, WebView2, X11, desktop streaming, and the installed Windows application belong inside the disposable container.

## Daily source-tree workflow

Run these commands in Windows PowerShell 7 from the repository root. Docker Engine must be the daemon inside the named WSL distribution.

```powershell
./scripts/Doctor-OctaneLab.ps1 -Engine Docker `
  -WslDistro Ubuntu-24.04 -Port 3005 -Deep

./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane

# Review and complete the generated data-only profile. Never guess silent flags.
./scripts/Test-OctaneTargetProfile.ps1 `
  -Profile ../example-app-octane/app.json -Operational

./scripts/Start-OctanePreview.ps1 `
  -Profile ../example-app-octane/app.json `
  -Installer 'C:\Builds\setup.exe' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -WslDistro Ubuntu-24.04 `
  -Port 3005 -UploadPort 3006 `
  -Image octane-lab:browser-xvnc-ad1ba74 `
  -LifecycleMode ReplaceActive `
  -OpenBrowser
```

Startup hashes and stages the local EXE before replacing an active run. It then collects/removes only the old run's exact managed resources, creates a new WSL-native home/prefix/install/WebView2/output state, installs the unchanged EXE inside Wine, prints the exact `http://127.0.0.1:<port>/octane.html` URL, and opens the Windows default browser when requested.

Verified machine-wide NSIS installers are representable without pretending they are per-user installs:

```powershell
./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane `
  -ExecutableFileName example-app.exe `
  -WindowTitleRegex '^Example App$' `
  -InstallArgument /S -InstallScope per-machine `
  -VerifiedInstallerArguments
```

Do not select `per-machine` or `/S` unless those properties were verified for the exact installer family.

The credential is never printed by startup:

```powershell
./scripts/Get-OctaneViewerCredential.ps1 -Container octane-0123456789
```

Collect output and evidence before exact cleanup:

```powershell
./scripts/Collect-OctanePreview.ps1 `
  -Container octane-0123456789 -WslDistro Ubuntu-24.04

./scripts/Stop-OctaneLab.ps1 `
  -Container octane-0123456789 -Engine Docker `
  -WslDistro Ubuntu-24.04
```

## Clean-build and file model

- The WSL appliance, Docker Engine, and pinned Wine/browser image remain installed.
- Every application build receives a new container, Wine prefix, registry/settings state, user profile, WebView2 data directory, installation, output area, and viewer credential.
- `ReplaceActive` validates the new installer first, collects the prior run, removes only its journaled resources, and starts the new build.
- `Comparison` retains two independently isolated runs on explicit separate ports.
- Selected inputs are copied into WSL-native run storage and mounted read-only at `C:\octane-input\selected`.
- Authenticated browser uploads are atomic, bounded to 512 MiB/file, non-overwriting, and visible read-only at `C:\octane-input\uploaded`.
- Application output is written separately at `C:\octane-output`, then collected to the operator-selected Windows output directory.
- Evidence and requested exports survive cleanup; the installed application state does not.
- No global Docker prune, WSL shutdown, distro unregister, broad Windows-drive mount, or warmed installed-app prefix is part of normal operation.

## Locked reference qualification

```powershell
./scripts/Invoke-OctaneBrowserQualificationBatch.ps1 `
  -LockPath ./profiles/qualification/docker-wine-staging-11.21-visrgn-browser-xvnc.lock.json `
  -Installer ./artifacts/Octane-setup.exe `
  -WslDistro Ubuntu-24.04 `
  -Port 3015 -UploadPort 3016
```

Qualification requires the exact local installer, image ID, harness commit, profile, fixtures, Docker context, and browser client recorded by the lock. Any failed, blocked, missing, aborted, or unexecuted run makes a batch not qualified.

## Tests

The current local verification consists of:

- 83 browser/runtime PowerShell assertions.
- 48 controller/mock assertions.
- 12 qualification-policy assertions.
- 32 appliance-packaging assertions.
- 17 upload/telemetry protocol assertions.
- 19 Node tests.
- 4 Rust core tests plus doc tests.
- One final-image exploratory browser pass and a locked 10/10 live browser batch.

Static, unit, mock, component, historical RDP, browser smoke, and browser qualification results are kept separate.

## Boundaries

Octane does not require target source, a target rebuild, Tauri configuration changes, a browser-only replacement, Docker Desktop, RDP, Proton, Podman, CrossOver, a Windows VM, host-GPU passthrough, or provider credentials. Core intake is a local EXE plus a data profile.

The viewer is authenticated and loopback-only. Raw VNC is not published. The qualifying profile did not use privileged mode, host networking, the Docker socket, broad host mounts, ptrace, `--no-sandbox`, host GPU devices, or an RDP fallback.

Wine does not automatically inherit Windows domain identity, browser cookies, Credential Manager secrets, mapped drives, private certificates, smart-card state, device compliance, or every Windows API/service. File paths and required endpoints must be declared and tested for each target.

The retained Wine visible-region patch is a maintenance condition. The result does not qualify stock Wine, arbitrary Windows/Tauri applications, or any installer not actually tested.

## Project provenance

The originating project conversation is `chatgpt-conversation://6af79ffb-6048-83ea-b689-8269484af53d` (“Run Windows App Containers”). It is historical context; repository code, locks, and measured evidence are normative.

The repository can be public without granting an open-source license. No license file is currently present, so normal copyright restrictions remain. Installer bytes, private image archives, credentials, raw evidence, and sensitive test data stay outside ordinary Git history.
