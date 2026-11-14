# Octane WSLC + Wine lab

Separate Rust/Tauri Windows test application, NSIS installer build, and disposable Linux Wine desktop running through Microsoft's `wslc.exe`.

The single comprehensive guide is **docs/Octane-Complete-Guide.pdf**. It covers the architecture, every component and command, build and lab operation, data format, security, acceptance criteria, troubleshooting, actual verification results, and future work.

## Quick start

Run the commands below from **Windows PowerShell**, not from an Ubuntu/RHEL shell. `wsl.exe` and `wslc.exe` are Windows host tools; `command not found` inside a Linux distribution is expected.

Download `Octane-setup.exe` and `installer-manifest.json` from the private **Releases → v0.1.1** page and put them in this checkout's `artifacts/` directory. For later builds, download `Octane-windows-x64` from **Actions → Windows installer**; keep the EXE and manifest from the same run.

```powershell
./scripts/Start-OctaneLab.ps1
```

Open the printed local HTTPS address, log in with the generated credentials, and run each command in a terminal inside that desktop:

```bash
octane-lab notepad
octane-lab install
octane-lab launch
```

Load the sample set: expect **8 files, 6 extension groups, 1 duplicate set, 0 errors**. Export to `Z:\config\octane-evidence\report.json`, then collect evidence before removing the container:

```powershell
./scripts/Collect-Evidence.ps1 -Container octane-0123456789
./scripts/Stop-OctaneLab.ps1 -Container octane-0123456789 -RemoveImage
```

Substitute the actual container name. Wine/WebView2 compatibility is experimental; a successful build is not proof of a functioning GUI under Wine. Nothing in this project uses your existing application's source code.

## Build locally

Requires Windows x64, Rust stable MSVC, Visual Studio C++ Build Tools + Windows SDK, Node 22 and pnpm 11.25.0. Then run `./scripts/Build-Octane.ps1`. It creates the installer without installing Octane on the host.

Source is private and has no open-source license grant. Third-party components retain their own licenses.

## WSLC timeout behind a full-tunnel VPN

On the validated WSLC 3.0.1 host, ProtonVPN's on-link `0.0.0.0` route caused the WSLC utility VM's default Consommé networking to time out while starting Docker. Configure NAT in `%LOCALAPPDATA%\wslc\settings.yaml`, terminate only the WSLC system session, and retry:

```yaml
session:
  networkingMode: nat
  idleTimeout: 900
```

```powershell
wslc system session terminate
wslc run --rm hello-world
```

The complete guide records the measured WineGUI, NSIS, and WebView2 results and the exact acceptance status.
