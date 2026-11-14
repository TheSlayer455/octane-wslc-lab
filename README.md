# Octane WSLC + Wine lab

Separate Rust/Tauri Windows test application, NSIS installer build, and disposable Linux Wine desktop running through Microsoft's `wslc.exe`.

The single comprehensive guide is **docs/Octane-Complete-Guide.docx**. It covers the architecture, every component and command, build and lab operation, data format, security, acceptance criteria, troubleshooting, actual verification results, and future work.

## Quick start

Download `Octane-windows-x64` from the repository's **Actions → Windows installer** successful run. Put its `artifacts/Octane-setup.exe` and `artifacts/installer-manifest.json` in this checkout's `artifacts/` directory.

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
