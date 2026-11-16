# Browser workflow quick start

The Octane reference application is qualified 10/10 for the exact browser lock and image named below. Another unchanged Windows installer remains preview-only until its own profile and scenario are measured.

## Packaged appliance

The validated local v1 candidate contains 98 files (2,586,055,481 bytes), loads image ID `sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786`, and passed clean import/preview/collection/uninstall test `8739fdeafa` from an extracted path containing spaces and Unicode. Use the package's own `manifest.json` and `checksums.sha256` as the exact identity after download.

From Windows PowerShell 7 in the extracted release:

```powershell
# Verify every declared package/runtime hash without changing host state.
./Install-Octane.ps1 -PackageRoot $PWD -PlanOnly

# One-time import of the dedicated Ubuntu WSL appliance and image load.
./Install-Octane.ps1 -PackageRoot $PWD
```

Open a new terminal after the user PATH is updated:

```powershell
octane doctor -Deep

octane target -Id example-app `
  -TargetOutput 'C:\Octane Targets\example-app-octane'

# Review app.json and verify installer arguments before operational use.
octane open 'C:\Builds\setup.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -BuildLabel 'pipeline-12345'
```

`open` hashes and stages the new installer before touching the active build. It collects and removes the prior run's exact disposable resources, creates fresh state, installs and launches the unchanged EXE inside Wine, copies the new run credential to the Windows clipboard, and opens the exact localhost viewer in the Windows default browser. Use `-NoBrowser` if policy blocks automatic opening.

## Source-tree workflow

```powershell
./scripts/Doctor-OctaneLab.ps1 -Engine Docker `
  -WslDistro Ubuntu-24.04 -Port 3005 -Deep

./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane

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

Startup prints the exact container, run ID, artifact identity, viewer URL, credential command, and metadata path. If needed:

```powershell
./scripts/Get-OctaneViewerCredential.ps1 `
  -Container octane-0123456789
```

Do not substitute `/` for the printed `/octane.html` path. Do not expose the endpoint beyond loopback.

## Browser checks

In the browser:

1. Authenticate and confirm the actual target client area, not just the viewer shell or Linux desktop.
2. Confirm normal initial rendering without resize/minimize/restore, reconnect, click-to-wake, repaint helper, or relaunch.
3. Use mouse, keyboard, focus, and scrolling through noVNC.
4. Select controlled files with the real native picker from `C:\octane-input\selected`.
5. Cancel and reopen open/save dialogs; confirm the app stays responsive.
6. Export to `C:\octane-output`.
7. Independently validate collected output and unchanged input hashes.

The upload control is separate from the target application. It accepts explicit files only, requires the per-run credential and exact viewer origin, limits files to 512 MiB, writes atomically, rejects overwrite/traversal, and exposes no download/delete/directory API. Uploaded files appear read-only at `C:\octane-input\uploaded`.

## Collect and stop

```powershell
./scripts/Collect-OctanePreview.ps1 `
  -Container octane-0123456789 -WslDistro Ubuntu-24.04

./scripts/Stop-OctaneLab.ps1 `
  -Container octane-0123456789 -Engine Docker `
  -WslDistro Ubuntu-24.04
```

`stop` removes only the exact asserted container, run-owned WSL session directory, credential, volumes, prefix, application data, WebView2 data, and temporary output. Collected evidence and exports remain.

## Compare two builds

```powershell
octane compare 'C:\Builds\setup-previous.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -Port 3010 -UploadPort 3011
```

Comparison retains two independently isolated runs. It is not same-prefix upgrade testing.

## Reference qualification

- Lock: `profiles/qualification/docker-wine-staging-11.21-visrgn-browser-xvnc.lock.json`
- Lock SHA-256: `db5babdf10bb9c3aef12731c398a75437d280385799512e1b92838f028d68249`
- Harness: `ad1ba74644bdab49a17ccc40caf26f477d848a6a`
- Image: `octane-lab:browser-xvnc-ad1ba74`
- Image ID: `sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786`
- Batch: `browser-qbatch-06f2a54afe0c`, PASS 10/10
- Installer SHA-256: `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`

```powershell
./scripts/Invoke-OctaneBrowserQualificationBatch.ps1 `
  -LockPath ./profiles/qualification/docker-wine-staging-11.21-visrgn-browser-xvnc.lock.json `
  -Installer ./artifacts/Octane-setup.exe `
  -WslDistro Ubuntu-24.04 `
  -Port 3015 -UploadPort 3016
```

This qualification is exact and conditional on the custom Wine patch. The minimal Win32 WebView2 probe remains white, and no result transfers automatically to another installer.
