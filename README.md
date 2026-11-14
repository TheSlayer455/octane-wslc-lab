# Octane Windows installer compatibility lab

Octane is a provider-neutral test lab for a real Windows Tauri installer running through Wine inside Linux containers. Its small file-analysis app is the reference workload. The lab never substitutes a Linux build or browser-only app for the Windows installer under test.

The single authoritative reference is **[docs/Octane-Complete-Guide.pdf](docs/Octane-Complete-Guide.pdf)**. It explains the architecture, every command and file, WSLC repair, Docker operation, Wine profiles, acceptance protocol, evidence format, security boundaries, troubleshooting, and measured results.

## Supported combinations

| Runtime adapter | Wine environment | Desktop path |
| --- | --- | --- |
| WSLC | WineGUI | Authenticated Selkies HTTPS desktop |
| Docker | WineGUI | Authenticated Selkies HTTPS desktop |
| Docker | Docker-Wine | RDP to an XFCE Linux desktop displaying Wine apps |

On Windows, the Docker adapter requires an explicit WSL distribution and invokes that distribution's Docker CLI. It does not silently fall back from WSLC to Docker. Podman is intentionally out of scope.

## Quick start

Use **PowerShell 7 from Windows**, from the repository root. `wsl.exe` and `wslc.exe` are Windows host commands; `command not found` at an Ubuntu prompt is expected.

Put a matching `Octane-setup.exe` and `installer-manifest.json` in `artifacts/`. The retained v0.1.1 private release contains the measured pair; later Windows workflow artifacts contain the same two-file contract.

Run the doctor before building a desktop image:

```powershell
./scripts/Doctor-OctaneLab.ps1 -Engine Wslc -Port 3001 -Deep
./scripts/Doctor-OctaneLab.ps1 -Engine Docker -WslDistro Ubuntu-24.04 -Port 3002 -Deep
```

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

The launcher prints the exact container name, loopback endpoint, username, one-time password, and run metadata path. Open the selected desktop and run, one stage at a time:

```bash
octane-lab notepad
octane-lab install
octane-lab launch
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

## Measured result

The WSLC timeout is fixed. WSLC 3.0.1 required NAT session networking on this full-tunnel VPN host. Docker 29.6.2 in `Ubuntu-24.04` passed the deep run/copy/cleanup doctor.

For the unchanged installer (`SHA-256 adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`):

- WineGUI under WSLC and Docker rendered Wine 11 Notepad, accepted input, and completed the NSIS installer.
- Docker-Wine over RDP also rendered/repainted Notepad and completed the installer.
- Evergreen WebView2 157.0.4341.60 installed in every measured fresh prefix.
- Octane's WebView2 content did not render in either Wine environment. The browser/renderer began, GPU subprocesses restarted, all WebView2 children exited, and the installed window remained blank or black.
- The workload, native dialogs, and JSON export are `BLOCKED`, not passed or inferred.

These are Wine-compatibility results, not proof of failure on supported Windows. The same installer still needs native Windows GUI qualification.

## Build locally

Requires Windows x64, Rust stable MSVC, Visual Studio C++ Build Tools plus Windows SDK, Node 22, and pnpm 11.25.0:

```powershell
./scripts/Build-Octane.ps1
```

The build creates the installer and manifest without installing Octane on the host. Source is private and has no open-source license grant; third-party components retain their own licenses.

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
