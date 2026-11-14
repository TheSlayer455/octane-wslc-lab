# Octane Windows installer compatibility lab

Octane is a provider-neutral test lab for a real Windows Tauri installer running through Wine inside Linux containers. Its small file-analysis app is the reference workload. The lab never substitutes a Linux build or browser-only app for the Windows installer under test.

The single authoritative reference is **[docs/Octane-Complete-Guide.pdf](docs/Octane-Complete-Guide.pdf)**. It explains the architecture, every command and file, WSLC repair, Docker operation, Wine profiles, acceptance protocol, evidence format, security boundaries, troubleshooting, and measured results.

The dated [compatibility matrix](docs/compatibility-matrix.md) separates historical observations from current runs. The [research evidence ledger](docs/research-evidence-ledger.md) records source authorship, exact commits/versions, reported versus local outcomes, and confidence.

## Supported combinations

| Runtime adapter | Wine environment | Desktop path |
| --- | --- | --- |
| WSLC | WineGUI | Authenticated Selkies HTTPS desktop |
| Docker | WineGUI | Authenticated Selkies HTTPS desktop |
| Docker | Docker-Wine | RDP to an XFCE Linux desktop displaying Wine apps |
| Docker | Pinned Wine 11.21 + Staging 11.21 control | Same Docker-Wine RDP desktop; source-built matched control |
| Docker | Pinned Wine 11.21 + Staging 11.21 visible-region candidate | Same control plus one verified `win32u` patch |
| Docker on native SER8 | Docker-Wine | Ansible-managed XRDP/XFCE run with a black-box FreeRDP probe |

On Windows, the Docker adapter requires an explicit WSL distribution and invokes that distribution's Docker CLI. It does not silently fall back from WSLC to Docker. Podman is intentionally out of scope.

## Quick start

Use **PowerShell 7 from Windows**, from the repository root. `wsl.exe` and `wslc.exe` are Windows host commands; `command not found` at an Ubuntu prompt is expected.

Put a matching `Octane-setup.exe` and `installer-manifest.json` in `artifacts/`. The retained v0.1.1 private release contains the measured pair; later Windows workflow artifacts contain the same two-file contract.

Run the doctor before building a desktop image:

```powershell
./scripts/Doctor-OctaneLab.ps1 -Engine Wslc -Port 3001 -Deep
./scripts/Doctor-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -Port 3002 -Deep
```

The Docker doctor records the Windows/WSL versions, selected distribution and kernel, local Docker context/socket/server/root, architecture, storage, memory/free space, buildx availability, a disposable run/copy-out check, and Windows reachability of a loopback-published container endpoint. It rejects an accidentally selected Docker Desktop or remote endpoint on the Windows/WSL path.

Start one explicit engine/profile combination:

```powershell
# WSLC + browser-streamed WineGUI
./scripts/Start-OctaneLab.ps1 -Engine Wslc -WineProfile WineGui -Port 3001

# Docker inside the named WSL distribution + WineGUI
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 `
  -WineProfile WineGui -Port 3002

# Docker + Docker-Wine RDP profile
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 `
  -WineProfile DockerWine -Port 3390
```

The following experimental profiles are controlled source-build comparisons. Their pinned recipes and build provenance were locally built on 2026-11-14; GUI execution results are recorded separately in the compatibility matrix rather than implied here:

```powershell
# Wine 11.21 + the complete matching Wine-Staging 11.21 patch set
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 `
  -WineProfile DockerWineStaging1121Control -Port 3392

# Exact control plus only the reviewed cross-process visible-region patch
./scripts/Start-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 `
  -WineProfile DockerWineStaging1121VisRgn -Port 3393
```

The launcher prints the exact container name, loopback endpoint, username, one-time password, and run metadata path. Open the selected desktop and run, one stage at a time:

```bash
octane-lab notepad
octane-lab install
octane-lab install-silent
octane-lab launch
```

The enhanced native diagnostic is run from the Windows controller so its raw native-window evidence is copied out even when it fails:

```powershell
./scripts/Invoke-OctaneExperiment.ps1 -Container octane-0123456789 `
  -Engine Docker -WslDistro Ubuntu-24.04 -DurationSeconds 30
```

It uses a fresh WebView2 user-data directory, logs initialization and process events, captures actual child command lines and the loaded Wine display driver, records rAF separately from timer callbacks, performs click/input/scroll/resize/minimize/restore actions, captures X11 screenshots/recording, and compares only the application client area. Automated pixel change remains `NOT_RUN` for final visible acceptance until the screenshots are reviewed; a live DOM cannot turn a blank native window into a pass.

Run the installed Octane black-box scenario separately. The experiment uses the actual installed `octane.exe`, requires a visibly non-blank client before later gates, invokes the real Rust backend, validates the fixture/report contract independently, and exercises native open/save/overwrite behavior:

```powershell
./scripts/Invoke-OctaneApplicationExperiment.ps1 `
  -Container octane-0123456789 -Engine Docker `
  -WslDistro Ubuntu-24.04 -ExperimentId octane-clean-01

# Review the native-window screenshots. Status here is the visual review only;
# workload, dialog, and export stages retain their own automated outcomes.
./scripts/Review-OctaneApplicationExperiment.ps1 `
  -Container octane-0123456789 -ExperimentId octane-clean-01 `
  -Status PASS -Detail 'Native client and interaction evidence reviewed.'
```

Record visible acceptance outcomes, collect evidence, and remove only the named lab resources:

```powershell
./scripts/Record-OctaneResult.ps1 -Container octane-0123456789 `
  -Stage basicWine -Status PASS -Detail 'Notepad rendered and repainted.'

./scripts/Collect-Evidence.ps1 -Container octane-0123456789 `
  -ScreenshotDirectory C:\path\to\screenshots

./scripts/Stop-OctaneLab.ps1 -Container octane-0123456789 -RemoveImage
```

Evidence includes normalized run metadata, environment data, complete stage results, JUnit XML, logs, optional screenshots/recording, and SHA-256 checksums. Cleanup synchronizes its final status into already-collected bundles.

Docker-Wine runs explicitly disable its upstream passwordless-sudo option. No profile mounts the Docker socket, broad host paths, or host secrets; no profile defaults to privileged mode, host networking, ptrace, `--no-sandbox`, or a disabled Linux security policy.

## Native SER8 Ansible path

The `lab/ser8-*.yml` playbooks provide an intentionally narrow native-Linux path for the existing home-lab inventory alias `ser8`. They require the dedicated `svc.ansible` identity and expected hostname `jakeubuntu`, allow only the reviewed Tailscale or LAN bind address, rehash the frozen installer on the server, label every disposable resource with its run ID, and refuse broad cleanup. The sequence is:

```text
ser8-docker-wine-preflight.yml
ser8-docker-wine.yml
ser8-rdp-probe-start.yml
ser8-docker-wine-collect.yml
ser8-docker-wine-stop.yml
```

Before starting, stage the frozen installer and manifest under `artifacts/`, and download the private `WebView2Diagnostic-windows-x64` workflow artifact into `diagnostics/webview2-win32/artifacts/`. Both generated directories are Git-ignored; the playbook copies them only after the controller has the expected files, and the server rehashes the installer before building.

The RDP password is generated per run. The upstream Docker-Wine server receives only its MD5-crypt hash; the FreeRDP probe receives the clear password through a one-use, mode-0600 file that is removed before the client starts. See the guide for the exact variables, measured endpoint choice, evidence layout, and rollback.

## Measured result

The earlier WSLC timeout is fixed and preserved as historical evidence. The current primary path is Docker Engine 29.6.2 inside `Ubuntu-24.04` WSL2; its deep run/copy/cleanup doctor passed. No VPN, Podman, Proton, Steam, CrossOver, Docker Desktop, host GPU mapping, `--no-sandbox`, privileged mode, or Docker-socket mount was used in this iteration.

For the unchanged retained installer (`SHA-256 adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`):

- The baseline Docker-Wine/Wine 11 run passed desktop, Notepad input, NSIS, and Evergreen WebView2 157.0.4341.60 installation. The enhanced native probe had live DOM/input/timer activity but a zero client-pixel delta and a white client; Octane remained black.
- The pinned source control uses Wine commit `2528aff26208257fdbf980666a4f0e66d47563ce` plus the complete matching Wine-Staging commit `04414fee61f7d283072d40905816b928875b2d4b`. One fresh control completed the real GUI/workload/dialog/export scenario after a focus/input and three-cycle resize/minimize/restore repaint nudge; the next fresh control remained black after the same bounded procedure. The control is non-repeatable.
- The candidate adds only the reviewed `win32u` cross-process visible-region patch, SHA-256 `f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752`, from `JustNotesa/solid-edge-wine-fixes` commit `d3fd3268536ed43c7e5c616bc1c98eec07a9d154`.
- In three fresh candidate containers, the installed Tauri/WebView2 client visibly rendered only after three resize/minimize/restore cycles. All three then completed the real 8-file Rust workload with 6 extension groups, 1 duplicate set, 176 bytes, and 0 errors.
- Only candidate run 1 completed every executed native-dialog and export/no-overwrite gate. Runs 2 and 3 produced correct first exports but failed the later dialog/no-overwrite sequence. A reused-prefix debug run validated the hardened overwrite synchronizer, but Choose Files returned `Selection canceled` without a visible picker; it is explicitly not clean acceptance.
- The minimal Win32 probe still rendered a solid-white WebView client with the candidate (rAF 0, timers 114, client-pixel delta 0). The patch is not a general WebView2 fix, and the mandatory window-state nudge is not normal repaint behavior.
- No current Wine 11.21 run reproduced the historical `IDropTarget_Release` crash. That does not rewrite the earlier observation or prove Wine bug 60225 was the same defect.

**Verdict: NOT YET DEMONSTRATED repeatably.** There is a conditional laboratory rendering/workload result, but the required three complete fresh passes and pinned-rebuild confirmation were not achieved. A disposable native-Windows control was unavailable, and the owner's everyday Windows installation was intentionally untouched.

## Build locally

Requires Windows x64, Rust stable MSVC, Visual Studio C++ Build Tools plus Windows SDK, Node 22, and pnpm 11.25.0:

```powershell
./scripts/Build-Octane.ps1
./scripts/Build-WebView2Diagnostic.ps1
```

The first command creates the installer and manifest without installing Octane on the host. The second restores the pinned WebView2 SDK, builds the native x64 probe, and emits its own manifest. Both commands are provider-neutral; the GitHub workflows are thin wrappers. Source is private and has no open-source license grant; third-party components retain their own licenses.

## WSLC timeout repair used on the measured host

ProtonVPN's full-tunnel route caused WSLC's default Consommé utility-session networking to time out. Save this at `%LOCALAPPDATA%\wslc\settings.yaml`, terminate only the WSLC system session, and retest:

```yaml
session:
  networkingMode: nat
  idleTimeout: 900
```

```powershell
wslc system session terminate
wslc run --rm hello-world
```

The complete guide contains the diagnosis, rollback considerations, exact measured environments, and screenshots.
