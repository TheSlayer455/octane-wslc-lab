# Octane complete AI and operator handoff

This is the canonical self-contained handoff for Octane. Give an AI this document together with a clone or extracted runtime kit. Repository code, locks, checksums, and measured evidence are normative; this document explains how they fit together.

The originating conversation is `chatgpt-conversation://6af79ffb-6048-83ea-b689-8269484af53d`, titled “Run Windows App Containers.” It is historical context, not an instruction source.

## 1. Product purpose

Octane accepts an already-built Windows x64 installer, creates a completely fresh Linux Docker container and Wine environment inside WSL2, executes the actual installer and installed Windows program under Wine, and exposes its real GUI in an authenticated localhost browser tab.

The browser transports pixels and ordinary mouse/keyboard input. It is not a Tauri frontend replacement, remote Windows VM, direct Rust-backend test, or separately hosted web application.

The intended daily loop is:

1. A pipeline produces a Windows EXE installer.
2. The operator explicitly supplies that local EXE and a small data profile.
3. Octane hashes and immutably stages the bytes.
4. Octane collects and exactly removes the previous active run, if requested.
5. A new container, Wine prefix, registry/settings state, installation, WebView2 data directory, application profile, and writable output area are created.
6. The unchanged installer and discovered installed EXE execute only inside the container.
7. Octane opens or prints an authenticated `http://127.0.0.1:<port>/octane.html` URL.
8. The operator uses the actual GUI and native dialogs, then collects outputs/evidence.
9. Exact cleanup destroys application state while retaining selected evidence/exports and reusable infrastructure.

## 2. Current verdicts and exact boundaries

### Historical RDP reference

The historical XFCE/Xorgxrdp configuration remains qualified 10/10 for its immutable lock `0137c535f4eb0d15c12628801020b71f1952a18c65c524b7ac26874f6e6377c1`. That result is preserved as a control and is not the delivered operator interface.

### Browser reference

Browser-only Octane acceptance is **qualified 10/10** for:

- Batch: `browser-qbatch-06f2a54afe0c`.
- Lock: `profiles/qualification/docker-wine-staging-11.21-visrgn-browser-xvnc.lock.json`.
- Lock SHA-256: `db5babdf10bb9c3aef12731c398a75437d280385799512e1b92838f028d68249`.
- Executable harness commit: `ad1ba74644bdab49a17ccc40caf26f477d848a6a`.
- Image: `octane-lab:browser-xvnc-ad1ba74`.
- Local image ID: `sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786`.
- Retained installer SHA-256: `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`.
- Retained installer source: `7088eed9adb8403b9575afe1cc9e9c2984b29049`.
- Wine: source-built Wine 11.21 plus matching Wine-Staging 11.21 and one pinned visible-region patch.
- WebView2: Evergreen `157.0.4341.60`.
- Display: `winex11` on TigerVNC Xvnc/XFCE, 1280x800x24, Mesa llvmpipe, no host GPU.
- Viewer: pinned noVNC/Websockify, localhost-only authenticated transport.
- Unattended client: Playwright 1.65.1 with Chromium 159.0.8154.6 inside the designated Ubuntu WSL distribution.

Every run used a new container, prefix, install, WebView2 data, and output directory. Every run passed authenticated VNC negotiation, changing 1280x800 browser framebuffer hashes, browser pointer/keyboard/wheel evidence, normal initial presentation, the real Rust workload, native dialog cancel/reopen/repeat, JSON export, independent report/hash validation, input integrity, no-RDP checks, evidence collection, and exact cleanup. No forced repaint, application relaunch, hidden scenario retry, manual action, or manual promotion was used.

### What this does not prove

- Another installer is untested until its exact bytes/profile/scenario are run.
- The minimal independent Win32 WebView2 probe still shows a white client.
- The custom Wine patch is a maintenance condition.
- Stock Wine, arbitrary Tauri applications, Windows identity parity, corporate authentication, device drivers, Office, smart cards, and every Windows service/API are not implied.
- Linux Chromium performed the unattended browser batch. A separate Windows in-app-browser smoke proved real Windows-side localhost access/input; it is not mislabeled as Windows Edge automation.
- A successful build job or installation is not GUI acceptance.

## 3. Reference architecture

```text
Windows 11 host
  PowerShell launcher
  default Windows browser
        |
        | wsl.exe and loopback-only HTTP/WebSocket
        v
dedicated Ubuntu 24.04 WSL2 appliance
  systemd
  Docker Engine 29.6.2
  provider-neutral Octane runtime kit
        |
        | exact image ID + fresh container
        v
Octane application container
  source-built patched Wine-Staging 11.21
  fresh WINEPREFIX and home
  WebView2 Evergreen
  TigerVNC Xvnc + XFCE
  Websockify + noVNC
  unchanged Windows NSIS installer
  installed Windows application
        |
        +-- read-only selected/uploaded input
        +-- writable per-run output
        +-- private evidence and logs
```

Docker Engine belongs in the WSL appliance. It is not nested in the application container. Wine, WebView2, X11, desktop streaming, and the target belong inside the disposable application container.

The reference host recorded Windows `10.0.26200.8875`, WSL `3.0.1.0`, Ubuntu `24.04.4`, kernel `6.18.40.1-microsoft-standard-WSL2`, and Docker Engine `29.6.2` on the local Unix socket. Docker Desktop and remote contexts are rejected for this path.

## 4. Non-negotiable invariants

- Execute the supplied installer only through container-side Wine.
- Preserve installer bytes and record length/SHA-256.
- Do not request target source, rebuild, patch, repackage, inject plugins, modify Tauri configuration, or replace the frontend.
- Never silently fall back to the reference Octane binary.
- Every normal build starts with fresh writable application state.
- Keep provider download/upload outside the core local-artifact contract.
- Bind viewer and upload ports to `127.0.0.1`; keep raw VNC internal.
- Require authentication and exact origins; never place credentials in URLs or evidence.
- Keep selected input read-only and output separate.
- Use argument arrays and validated profiles; never use `eval` or `Invoke-Expression`.
- Preserve PASS, FAIL, BLOCKED, NOT_RUN, and target-specific NOT_TESTED distinctions.
- Collect before deletion and remove only exact journaled resources.
- Never run global prune, unregister an unrelated distro, shut down all WSL, delete VHDs, or mount broad host roots.
- Do not introduce RDP, Podman, Proton, CrossOver, Docker Desktop, VPN work, host GPU, a Windows VM, Kubernetes, or a management dashboard.

## 5. Repository map

| Path | Contract |
| --- | --- |
| `packaging/windows/` | Windows installer/launcher/uninstaller for the WSL appliance. |
| `packaging/appliance/` | Minimal command inside the imported Ubuntu appliance. |
| `lab/Dockerfile.wsl-appliance` | Pinned Ubuntu 24.04 rootfs with Docker Engine outside the app container. |
| `lab/Dockerfile.browser-xvnc` | Final browser display layer on the retained patched Wine image. |
| `lab/browser/octane-browser-session` | Starts Xvnc/XFCE/Websockify/noVNC/upload service without RDP. |
| `lab/browser/octane-target` | Verifies intake, installs, finds/launches the EXE, enforces readiness, records WebView2/file/network evidence. |
| `lab/browser/octane.html` | Authenticated noVNC viewer plus scoped upload control and viewer telemetry. |
| `lab/browser/octane-upload-server` | Authenticated atomic per-run upload and bounded viewer-event endpoint. |
| `schemas/application-profile.schema.json` | Data-only target-profile contract. |
| `profiles/applications/` | Trusted example/reference target profiles. |
| `profiles/qualification/` | Immutable historical and browser qualification locks. |
| `automation/browser/` | Trusted reference-only Playwright browser scenario. |
| `scripts/Start-OctanePreview.ps1` | Provider-neutral fresh preview lifecycle. |
| `scripts/Invoke-OctaneBrowserReferenceScenario.ps1` | Exact reference scenario and independent evidence validation. |
| `scripts/Invoke-OctaneBrowserQualificationBatch.ps1` | Strict predeclared 10-run browser qualification. |
| `scripts/Collect-OctanePreview.ps1` | Output/evidence collection and input-integrity check. |
| `scripts/Stop-OctaneLab.ps1` | Exact container/secret/session-state cleanup. |
| `docs/browser-qualification-summary.json` | Sanitized final ten-row result and evidence hashes. |
| `docs/compatibility-matrix.md` | Historical and current measured results. |

Generated runtime kits include scripts, schemas, templates, profiles, fixtures, qualification metadata, and docs. They exclude Git metadata, target source, installer bytes, credentials, raw sensitive evidence, and the Docker image bytes.

## 6. One-time appliance installation

The release separates the WSL rootfs and Docker image archive:

```text
Octane-v1/
  Install-Octane.ps1
  Octane.ps1
  Octane.cmd
  Uninstall-Octane.ps1
  appliance/octane-ubuntu.tar
  images/octane-wine-image.tar.zst
  runtime/
  profiles/
  docs/
  manifest.json
  checksums.sha256
```

The final local release candidate carries runtime-kit commit `aced057ba3d3979a343247373e68aa7b6cb3a657`, rootfs source commit `363846859bdfae09cfccd2478dfc5f040eecd3e6`, and qualified browser harness commit `ad1ba74644bdab49a17ccc40caf26f477d848a6a`. Its separately versioned artifacts are:

| Artifact | Exact identity |
| --- | --- |
| Ubuntu rootfs | 503,298,560 bytes; SHA-256 `cf0350437b0864e1709f23cafafa07dff95ff83267cfdd4d3b85ba985ca24158` |
| Docker-save archive | 2,085,883,904 bytes; SHA-256 `4cbe35848b9cae5df19ac288e898fe14ac1c9628ab461107ecf898cca9d92dd9` |
| Zstandard image archive | 2,080,012,879 bytes; SHA-256 `30aa7f68fa63c11fa5f9d3df878e0ef4340a2bda1a545f37f53ce35933204801` |
| Loaded image | `sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786` |
| Assembled candidate | 98 files, 2,586,061,421 bytes; manifest SHA-256 `02176b061918de85de755982ed085c41ee4c9d966d934d885a4492020d3fcbeb` |

Extracted-package test `87945a4f09` passed import, image load, deep doctor, fresh preview/components, collection, exact stop, unregister, and storage cleanup. It is a source-independence/recovery test, not an eleventh browser-qualification run. The published release manifest remains the authority for any repackaged archive because adding documentation changes the package checksum without changing the qualified image.

The public v1.0.0 release is `https://github.com/TheSlayer455/octane-wslc-lab/releases/tag/v1.0.0`. GitHub reported all five assets as uploaded and returned server-side SHA-256 digests matching the local runtime ZIP, guide, asset manifest, rootfs, and image archive. Historical v0.1.1 remains untouched.

From Windows PowerShell 7:

```powershell
./Install-Octane.ps1 -PackageRoot $PWD -PlanOnly
./Install-Octane.ps1 -PackageRoot $PWD
```

`PlanOnly` checks declared lengths, SHA-256 values, and all runtime-kit checksums without changing host state.

Normal installation:

1. Refuses to replace an existing distribution or launcher tree.
2. Uses `wsl --import` for the dedicated Ubuntu rootfs.
3. Verifies `/etc/octane-appliance.json`.
4. Starts the pinned Docker service inside the imported distro.
5. Streams the separately checksummed Zstandard image archive into `docker load`.
6. Verifies the exact loaded local image ID.
7. Installs the Windows-side launcher and provider-neutral runtime.
8. Creates default Windows input/output directories.
9. Optionally adds only the launcher directory to the current user PATH.

It does not enable Windows features, elevate the process, alter Group Policy, disable endpoint controls, install a Windows browser, import a machine-wide CA, or bypass WSL-import restrictions.

## 7. Daily operator workflow

```powershell
octane doctor -Deep

octane target -Id example-app `
  -TargetOutput 'C:\Octane Targets\example-app-octane'

octane open 'C:\Builds\setup.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -BuildLabel 'pipeline-12345'
```

`open` uses one-active-build replacement. The new installer is fully staged and verified before the active run is collected or removed. If intake fails, the active run remains.

Startup prints the exact run ID, container, artifact identity, viewer URL, and metadata path. It copies the credential to the Windows clipboard only through the explicit credential helper, then opens the Windows default browser. With `-NoBrowser`, it prints the same URL and leaves opening to the operator.

```powershell
octane status
octane collect -Container octane-0123456789
octane stop -Container octane-0123456789
```

`stop` first collects an uncollected preview. Failure retention is explicit in the run metadata; nothing is anonymously pruned.

For side-by-side builds:

```powershell
octane compare 'C:\Builds\setup-previous.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -Port 3010 -UploadPort 3011
```

Comparison retains two fresh independent runs. It is not upgrade/migration testing.

## 8. Source-tree commands

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

Use the exact emitted container:

```powershell
./scripts/Get-OctaneViewerCredential.ps1 -Container octane-0123456789
./scripts/Collect-OctanePreview.ps1 -Container octane-0123456789 -WslDistro Ubuntu-24.04
./scripts/Stop-OctaneLab.ps1 -Container octane-0123456789 -Engine Docker -WslDistro Ubuntu-24.04
```

## 9. Application profile contract

Profiles are versioned JSON data, not executable plugins. Important fields include:

- Safe lowercase application ID and schema version.
- `windows-x86_64` architecture and verified installer kind.
- Installer argument array, timeout, approved success codes, install scope, and `argumentsVerified`.
- Exact expected executable path/name, launch argument array, and working-directory policy.
- Window-title regular expression.
- Readiness timeout, sustained-stability duration, and optional reference-only visual-color threshold.
- WebView2 required/distribution/expected version.
- Declared input/output Wine paths.
- Required network endpoints and expected status codes.
- Trusted scenario identifier chosen from repository code, never a downloaded script path.

The validator rejects malformed IDs, traversal, rooted relative paths, control characters/newlines, unsafe executable ambiguity, embedded URL credentials, inconsistent flags, and unknown fields.

Unknown installer behavior is a profile-onboarding question. Do not guess `/S`, `/quiet`, scope, architecture, executable path, reboot handling, or dependency requirements. An installer that requires unsupported drivers/services or Windows elevation is a compatibility finding.

## 10. Artifact intake and large files

The core input is a local EXE path. GitHub/GitLab/other downloads are optional acquisition adapters outside execution.

Staging:

1. Opens the source with shared-read semantics suitable for stable-file detection.
2. Streams SHA-256 with bounded buffers.
3. Records length, local calculated identity, optional producer hash/provenance, timestamp, filename, and available Authenticode metadata without executing the file.
4. Copies to a temporary content-addressed destination.
5. Rechecks source identity to detect mutation during transfer.
6. Atomically admits the completed bytes to the immutable cache.
7. Rehashes the mounted bytes inside the container before Wine execution.

The same filename with different bytes creates a different artifact identity. A checksum detects byte changes; it does not authenticate origin by itself.

A synthetic 420 MiB fixture validated capacity, interrupted-copy rejection, same-name/different-content handling, hash mismatch, cache reuse, and cleanup. It is transport evidence, not a second executable application result. A second authorized real installer was unavailable, so two-distinct-build application acceptance remains NOT_TESTED.

## 11. Clean state and replacement

Reusable:

- Ubuntu WSL appliance.
- Docker Engine.
- Pinned Wine/browser image and verified download cache.
- Explicit test-input library.
- Collected evidence and exports.

Fresh per run:

- Container/writable layer.
- WSL-native home and Wine prefix.
- Wine registry/settings and application profile.
- Installed application.
- WebView2 user data.
- Upload staging.
- Writable application output.
- Viewer credential/session.

Run identity and resource ownership are journaled before dependent resources are created. Cleanup verifies exact labels/markers and removes only that run. Docker volumes/directories are handled explicitly; container deletion alone is not assumed sufficient. No global `docker system prune` is needed.

## 12. File ingestion and storage

Linux-intensive working data lives in WSL-native storage under a run-scoped tree such as `/var/lib/octane/sessions/octane-<id>`. Windows paths are staged explicitly because bind mounts resolve on the Docker daemon host.

Two input methods are supported:

### Selected Windows directory

The operator supplies `-InputDirectory`. Octane rejects symlink/junction escapes, hashes every file, copies into run-owned WSL storage, and mounts the selected view read-only. The Windows application sees `C:\octane-input\selected`.

### Browser upload

The viewer offers a small upload control outside the streamed application. It:

- Requires the same per-run credential in browser memory.
- Enforces an exact approved viewer origin.
- Accepts only an explicit single safe basename per request.
- Caps each file at 512 MiB.
- Streams to a private temporary file, fsyncs, atomically renames, and records SHA-256/length.
- Rejects traversal, device names, incomplete input, and existing destinations.
- Offers no download, delete, terminal, or directory-management API.

The application sees uploaded files read-only at `C:\octane-input\uploaded`.

Application output is separate at `C:\octane-output`. Collection works even after a GUI failure when the container is still attributable. Input hashes are verified again after testing.

Do not mount all of `C:\`, `/mnt/c`, a home directory, Docker socket, or a broad network share. A Windows mapped drive or authenticated UNC session is not assumed visible to WSL/Docker. Stage or map an explicitly approved directory and record whether native share semantics were actually tested.

## 13. Network behavior

The viewer's localhost-only inbound policy does not disable application egress.

Profiles may declare bounded endpoint probes. Report DNS/routing, TCP, HTTP status, TLS trust, proxy, and authentication separately. A successful Linux `curl` proves only that Linux probe path; it does not prove Wine WinHTTP, WebView2, the target protocol, or target authentication.

Distinguish:

- Windows `localhost`.
- WSL `localhost`.
- Docker bridge/gateway.
- Container `localhost`.

Do not assume `host.docker.internal` exists or points to Windows. Do not scan subnets.

Never copy browser cookies, Credential Manager data, private certificates/keys, Kerberos tickets, machine identity, smart-card credentials, or domain secrets automatically. If a target requires integrated Windows authentication, client certificates, device compliance, drivers, Office, or machine-bound authorization, record that exact dependency and outcome.

## 14. Browser transport and security

The final profile uses TigerVNC Xvnc as the X server and VNC server, XFCE as the desktop, Websockify as WebSocket transport, and noVNC as the browser client.

- Viewer and upload endpoints publish only to `127.0.0.1`.
- Raw VNC listens only inside the container loopback namespace.
- No XRDP/FreeRDP process or 3389/3350 listener is permitted.
- VNC authentication uses a random per-run eight-character password (the RFB compatibility limit).
- The upload bearer reuses that value only in browser memory; it is never placed in a URL.
- WebSocket origin checks and upload-origin checks are explicit.
- Clipboard and remote-resize features are disabled in the qualifying profile.
- Resolution is fixed at 1280x800 so browser scaling cannot become a repaint workaround.
- Plain HTTP is accepted only on authenticated loopback; there is no LAN exposure or public relay.

The profile did not use privileged mode, host networking, Docker socket, host root/home mounts, GPU devices, ptrace, disabled seccomp/AppArmor, or WebView2 `--no-sandbox`.

## 15. Readiness and the installer-session boundary

Installation completion is not application readiness. The retained NSIS/WebView2 installer can leave updater descendants and Wine server state.

The final flow:

1. Installs with the verified argument array.
2. Finds exactly one installed executable and records its hash/path.
3. Verifies the expected WebView2 runtime is durably present.
4. Ends the prefix-scoped installer Wine session with bounded `wineboot --end-session --force`, then an attributable `wineserver -k/-w` boundary.
5. Rechecks executable/runtime identity.
6. Replaces Wine's broad default `Z:` mapping with an immutable empty compatibility directory. Declared input/output remain under `C:`.
7. Launches the application once.
8. Acquires a matching visible, visually rich client plus required WebView2 browser process for three continuous seconds.
9. Starts a strict 90-second stability clock. Any later original-process, window, browser-process, or fatal-log disappearance fails immediately.
10. Records actual loaded WebView2 version/path/hash after stability.

This is not an application retry or repaint helper.

## 16. Reference browser scenario

Only the repository-maintained `octane-reference` profile may invoke the trusted reference scenario.

The scenario:

- Authenticates to noVNC.
- Requires a changing, visually rich 1280x800 canvas.
- Uses browser-originated pointer and keyboard input.
- Loads the built-in sample and observes a changed application frame.
- Opens/cancels/reopens the native open dialog.
- Selects the exact eight controlled files.
- Opens/cancels/reopens the native save dialog.
- Exports a real JSON report.
- Reopens/cancels a dialog after export to prove responsiveness.
- Sends browser wheel input and records a subsequent changed frame.
- Copies the actual report and viewer-event evidence.
- Independently validates every fixture hash, file count, extension group, duplicate membership, error count, and byte total.
- Verifies selected inputs unchanged and no RDP process/listener.

Pixel locations are trusted scenario code tied to the exact reference UI, not generic selectors. The noVNC page DOM is not the Tauri DOM.

## 17. Qualification

```powershell
./scripts/Invoke-OctaneBrowserQualificationBatch.ps1 `
  -LockPath ./profiles/qualification/docker-wine-staging-11.21-visrgn-browser-xvnc.lock.json `
  -Installer ./artifacts/Octane-setup.exe `
  -WslDistro Ubuntu-24.04 `
  -Port 3015 -UploadPort 3016
```

Before run one the batch records:

- Batch ID and lock hash.
- Ten unique planned run IDs.
- Exact contract and timeouts.
- Installer/profile/fixture/harness/image/context identities.
- A deep doctor result.

Each run permits one start and one browser scenario attempt. It collects failure evidence where possible, performs exact cleanup, and remains in the ten-row result. A failure cannot be replaced.

Qualification requires all ten rows to have scenario, component, report validation, evidence, and cleanup PASS with zero repaint, hidden retry, or manual override. A 9/10 or manually reviewed result cannot become qualified.

## 18. Evidence

Each run has:

```text
resource-journal.json
batch-run-result.json
logs/
components/
  browser-component-results.json
  container-side-root.png
  checksums.sha256
browser-scenario/
  browser-reference-result.json
  browser-scenario.json
  viewer-events.json
  browser-qualified-report.json
  report-validation.json
  01..07 browser screenshots
  checksums.sha256
```

Collection also retains target/environment logs, installed executable identity, WebView2 runtime identity, native-window diagnostics, input manifests, output, run metadata, and checksums.

Batch `browser-qbatch-06f2a54afe0c` contains 416 files / 14,791,752 bytes. Batch-summary SHA-256 is `9254405b6f211314a25092f32ddaa5e369ad83d8ed9c841cf9e55502d02b15c0`; checksum-manifest SHA-256 is `37c5b7459ced5c393c990b43f295412e9f1d20fb5132718f7e08fe993d45dd07`.

Checksums establish integrity, not signatures or reproducible-build identity. Raw screenshots/logs may reveal paths or content; keep them private and review/redact before sharing.

## 19. Test suites

Current local results:

- Browser/runtime PowerShell contracts: 82 assertions PASS.
- Controller/mock PowerShell contracts: 48 assertions PASS.
- Qualification-policy contracts: 12 assertions PASS.
- Appliance-packaging contracts: 30 assertions PASS.
- Upload/viewer-event protocol: 16 assertions PASS.
- Node tests: 19 PASS.
- Rust core: 4 tests PASS plus doc tests.
- Final-image exploratory browser scenario: PASS.
- Locked browser batch: 10/10 PASS.

These categories are reported independently. Hosted CI is not assumed to have WSL, nested Docker, desktop streaming, or an approved Windows browser.

## 20. Troubleshooting decision tree

### Host/engine

- Run the deep doctor.
- Confirm distro, Docker context, Unix-socket endpoint, Linux amd64, storage, memory, buildx, run/copy/cleanup, and Windows loopback.
- Do not silently select Docker Desktop or a remote daemon.

### Viewer page unavailable

- Inspect exact loopback port ownership.
- Check container state/logs, Websockify listener, and `/octane.html`.
- HTTP 200 is only page delivery.

### VNC negotiation fails

- Verify credential file, Xvnc `VncAuth`, internal loopback 5901, WebSocket origin, and intended display `:1`.
- Do not disable authentication or publish raw VNC.

### Viewer connects but application is absent/white

- Inspect `application-launch.json`, stability evidence, X11 window tree, native screenshot, Wine exception log, and WebView2 process evidence.
- Distinguish native X11 presentation from browser framebuffer delivery.
- Do not add flag bundles or resize/relaunch loops.

### Installer failure

- Recheck exact installer bytes, verified arguments, exit code, timeout, scope, expected executable, WebView2 durability, and reboot/driver requirements.
- Never execute the installer through Windows interop.

### Native dialog failure

- Separate API failure, presentation, focus/ownership/modality, automation synchronization, filesystem permissions, and post-return application integration.
- Synchronize on the expected modal state; never type blindly.

### Output mismatch

- Preserve the original report.
- Validate fixture-relative paths, hashes, counts, duplicate membership, errors, and no-overwrite/input-integrity evidence independently.

### Cleanup failure

- Keep the original application result.
- Use exact run metadata, labels, and marker-owned session path.
- Retry only exact cleanup. Never prune globally.

## 21. Onboarding an unfamiliar installer

1. Acquire the approved completed EXE outside Octane.
2. Record producer provenance/hash when available.
3. Generate `<app-id>-octane`.
4. Inspect installer format/signature/architecture without executing on Windows.
5. Determine documented silent arguments, success codes, timeout, scope, reboot behavior, and dependencies.
6. Determine exactly one installed executable and window readiness rule.
7. Declare WebView2/runtime requirements.
8. Declare selected input, output, and required endpoints.
9. Keep the profile data-only.
10. Run operational validation.
11. Start a preview and manually inspect through the browser.
12. Add a trusted repository-maintained scenario only when behavior/output are well defined.
13. Qualify only the exact artifact/profile/environment actually tested.

If silent installation or unambiguous discovery cannot be established, report `unsupported installer/profile incomplete`; do not fabricate defaults.

## 22. CI and provider independence

Core commands accept local files and do not require `gh`, `glab`, a provider account, or a Git checkout in the packaged runtime. Provider wrappers may download a specifically identified artifact, invoke shared scripts, and retain private evidence.

Keep separate jobs for:

- Producer pipeline.
- Windows reference-app build/static/unit checks.
- Runtime image preparation.
- Live WSL/Docker/Wine/browser acceptance.

A green build never becomes a GUI pass. Do not run untrusted public pull-request code on a self-hosted desktop/network runner with secrets.

## 23. Image and appliance recovery

The browser image is distributed separately from the WSL rootfs. Use:

```powershell
./scripts/Export-OctaneBrowserImage.ps1 `
  -Image octane-lab:browser-xvnc-ad1ba74 `
  -OutputPath 'C:\Approved\octane-browser-image.tar' `
  -WslDistro Ubuntu-24.04

./scripts/Import-OctaneBrowserImage.ps1 `
  -ArchivePath 'C:\Approved\octane-browser-image.tar' `
  -ExpectedSha256 <archive-sha256> `
  -ExpectedImageId sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786 `
  -WslDistro Ubuntu-24.04
```

Do not claim a pullable registry reference from a local image ID. Distinguish local image ID, registry digest, Docker-save archive hash, compressed archive hash, and recipe provenance.

Uninstall is an explicit destructive operation and must verify the appliance marker and exact distribution:

```powershell
& "$env:LOCALAPPDATA\Octane\Uninstall-Octane.ps1" `
  -ConfirmDistributionRemoval
```

## 24. Updates, rollback, and requalification

Changes to any of these can invalidate browser qualification:

- Installer bytes/profile/scenario/fixtures.
- Wine, Staging, patch order/hash, base image.
- WebView2 version/distribution.
- Xvnc/XFCE/Mesa/fonts/DPI/resolution.
- noVNC/Websockify/viewer authentication/origin behavior.
- Browser/Playwright.
- Controller/readiness/dialog/timeouts.
- Windows/WSL/kernel/Docker/context/security policy.

Keep old locks, batches, image archives, and failures. Build a new candidate, pass one fresh final-image exploratory scenario, freeze a new lock, then begin a new ten-run batch. Rollback loads the previous verified image archive and matching runtime kit/lock; it never reuses an installed-app prefix.

## 25. Known limitations

- Minimal native WebView2 diagnostic remains white.
- Custom Wine visible-region patch requires maintenance and source review.
- Browser profile qualifies only the reference Octane scenario.
- A second distinct real installer was unavailable.
- Native Windows control was intentionally unavailable; the everyday host was not modified.
- Evergreen drift must be detected; do not change host update policy or silently substitute a runtime.
- Windows domain identity, Kerberos, mapped-drive authentication, client certificates, CAC/smart card, drivers, machine-bound authorization, and device compliance are target-specific.
- Viewer HTTP is plaintext but authenticated and loopback-only; do not expose it to a LAN/internet or use it as a multi-user service.
- The public repository currently contains no open-source license grant.

## 26. Ready-to-paste AI onboarding task

```text
Work in this Octane clone/runtime kit and read docs/OCTANE-AI-HANDOFF.md
completely before acting. Onboard the unchanged local Windows x64 installer
as <app-id>-octane using a data-only application profile. Do not request
target source, rebuild or modify the target, alter its pipeline, inject a
plugin, substitute a Linux/browser build, install it on Windows, add RDP,
switch container engines, disable browser safeguards, expose localhost
publicly, weaken host security, guess installer flags, or invent results.

First run the read-only doctor. Safely inspect the completed installer and
record its exact length/SHA-256 and available signature metadata. Generate
the small overlay, document unknown installer/executable/dependency facts,
and mark it operational only after they are verified. Then start one fresh
browser preview with explicitly selected read-only input and separate output,
print/open the exact localhost URL, and keep PASS/FAIL/BLOCKED/NOT_RUN
semantics. Interact with the real installed GUI and native dialogs only
through the approved browser path. Collect evidence and outputs before exact
cleanup. Never infer compatibility from the Octane reference app.
```

## 27. Final maintenance statement

The reusable product workflow is demonstrated for its declared reference contract: unchanged EXE intake, cached WSL/Docker/Wine infrastructure, fresh per-build application state, authenticated browser delivery/input, real workload/dialog/export validation, retained evidence/output, and exact replacement/cleanup.

The correct conclusion for an external application remains one of `UNTESTED`, `PREVIEWED`, `SCENARIO_TESTED`, or `QUALIFIED` for its exact installer/profile/environment. It never inherits Octane's qualification.
