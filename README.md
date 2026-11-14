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

The reliability phase adds a standalone Win32 common-dialog probe and a strict unattended qualification path. Manual review cannot promote a qualification result:

```powershell
# Build and run the IFileOpenDialog/IFileSaveDialog/GetOpenFileName/GetSaveFileName probe.
./scripts/Build-FileDialogProbe.ps1 -WslDistro Ubuntu-24.04
./scripts/Invoke-FileDialogDiagnosticRun.ps1 -WslDistro Ubuntu-24.04 `
  -Phase CleanPrefix -Suite AppMatch -Port 3394
./scripts/Invoke-FileDialogDiagnosticRun.ps1 -WslDistro Ubuntu-24.04 `
  -Phase PostInstall -Suite AppMatch -Port 3394

# Freeze the current clean Git commit, installer, image, host, runtime, display,
# security policy, fixtures, harness files, timeouts, and ten-run contract.
./scripts/New-OctaneQualificationLock.ps1 -WslDistro Ubuntu-24.04

# Execute ten sequential fresh containers/prefixes with no operator input.
./scripts/Invoke-OctaneQualificationBatch.ps1 `
  -LockPath profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json `
  -WslDistro Ubuntu-24.04 -Port 3394
```

The final schema-v3 scenario launches the installed executable once, permits only one normal activation before readiness, and forbids the historical repaint helper. It validates exact Unicode clipboard round-tripping, a deliberate missing input, cancel/reopen behavior, the real eight-file Rust workload, save cancellation, new export, existing-output protection, ordinary post-readiness resize/restore, actual Wine/WebView2/display identity, complete evidence, and exact cleanup.

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

The earlier WSLC timeout and all initial blank/black, repaint-assisted, 1/3, 5/10, and 9/10 outcomes remain historical evidence. The final primary path is Docker Engine 29.6.2 inside `Ubuntu-24.04` WSL2. No VPN, Podman, Proton, Steam, CrossOver, Docker Desktop, host GPU mapping, `--no-sandbox`, privileged mode, host networking, broad host mount, or Docker-socket mount was used.

The unchanged retained installer has SHA-256 `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a` and source commit `7088eed9adb8403b9575afe1cc9e9c2984b29049`. The final qualification lock records:

- Harness commit `7181a47ee47ae1d63b3bcd4fa6a480d45b560ee3`.
- Lock SHA-256 `0137c535f4eb0d15c12628801020b71f1952a18c65c524b7ac26874f6e6377c1`.
- Image `sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c`.
- Wine `2528aff...`, matching Wine-Staging `04414f...`, and the pinned `win32u` visible-region patch `f0ea7e...`.
- `winex11`, XFCE/Xorgxrdp, `1280x800`, Mesa llvmpipe, no host GPU, and Evergreen WebView2 `157.0.4341.60`.

Final batch `qbatch-e2aaafff4b38` passed 10/10 unattended fresh containers and Wine prefixes. Every run had ten PASS gates, `forcedRepaintUsed=false`, zero hidden retries, zero manual overrides, a validated 8-file/6-group/1-duplicate/176-byte/0-error report, exact Unicode/space and deliberate missing-input reports, complete evidence, and cleanup PASS. Initial visible presentation took 19.000-19.084 seconds without resize/minimize/restore readiness manipulation. All 1,853 entries in the batch checksum manifest verify.

Two earlier failed qualification batches were preserved and fixed rather than replaced: 5/10 exposed a transient inter-run loopback-port readiness bug; 9/10 exposed a single-sample dialog-foreground synchronization race while the recording showed the picker visibly present. A narrower schema-v2 batch later reached 10/10, but audit found that its keystroke oracle dropped `Ω`; schema v3 replaced it with verified clipboard input and exact report assertions before the final batch.

The standalone native dialog probe passed 7/7 in clean and post-install prefixes with exact Unicode paths. The separate minimal Win32 WebView2 probe still has a white client and is not rewritten as a pass. No current Wine 11.21 run reproduced the historical `IDropTarget_Release` crash.

**Technical feasibility: demonstrated.**

**Full Octane acceptance: qualified against the declared 10/10 unattended fresh-prefix contract for the exact recorded installer and configuration.** The custom visible-region patch is a maintenance condition. This does not qualify stock Wine, arbitrary Tauri applications, or a proprietary installer that was not tested.

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
