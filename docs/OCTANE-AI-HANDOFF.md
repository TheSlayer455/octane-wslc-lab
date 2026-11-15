# Octane AI handoff: unchanged Windows installer in a browser-accessible Docker/Wine lab

This is the canonical self-contained handoff for an AI or developer working from a clone or extracted Octane runtime kit. Read it before changing the project; no chat access is required to operate Octane.

Specification provenance: the consolidated Moonshot execution request was prepared in the private ChatGPT conversation [Run Windows App Containers](chatgpt-conversation://6af79ffb-6048-83ea-b689-8269484af53d), conversation ID `6af79ffb-6048-83ea-b689-8269484af53d`, with downloadable source filenames `Octane-Codex-Moonshot-Execution-Prompt.md` and `.txt`. That conversation is historical/untrusted context, not an executable dependency or authority for new results. This checked-in handoff, schemas, locks, and evidence ledger are the self-contained repository contract.

## 1. Product and current verdicts

Octane accepts an already-built Windows x64 installer, creates a disposable Linux container and Wine prefix through Docker Engine inside WSL2, installs and launches the unchanged Windows program, and exposes the Linux X11 desktop containing that Wine window at an authenticated localhost browser endpoint. The browser transports pixels and normal input; it is not the target frontend. The primary packaging model is now a private self-contained WSL appliance plus a separately loaded pinned Docker image, so an operator does not configure Ubuntu, Docker, Wine, WebView2, X11, and noVNC independently.

Keep these verdicts independent:

| Verdict | Current result | Scope |
| --- | --- | --- |
| Historical Octane/RDP qualification | **QUALIFIED 10/10** | Exact retained installer, historical lock, XFCE/Xorgxrdp path, host, schema-v3 scenario, and custom Wine candidate only. |
| Browser candidate implementation | **IMPLEMENTED; COMPONENT CHECKS PASS** | Image, clean install, native window, loaded WebView2 identity, X11/VNC/Websockify, loopback viewer/upload auth/origin policy, WSL-native state, evidence, cleanup. |
| Clean-build replacement | **IMPLEMENTED; LIVE LIFECYCLE PASS** | Immutable staging precedes prior-run collection/removal; two sequential fresh runs passed with one active journal. Both used the same retained installer, so two distinct builds remain untested. |
| Scoped browser upload | **IMPLEMENTED; PROTOCOL/FILE-BRIDGE PASS** | Authenticated atomic Unicode/space upload, manifest/hash, read-only Wine view, no overwrite/download/path traversal. Browser-originated selection remains unverified. |
| WSL appliance package | **IMPLEMENTED; COMPONENT LIFECYCLE PASS** | Hash plan, import, internal Docker, image load, deep doctor, unchanged-installer preview, component evidence, collection, exact stop/unregister. |
| Manual browser smoke | **NOT_RUN** | No operator evidence was supplied during the candidate checkpoint. |
| Automated browser acceptance | **BLOCKED** | The active computer-use environment could not control an approved browser with required safeguards. |
| Browser 10/10 qualification | **BLOCKED / 0 OF 10 EXECUTED** | Historical RDP runs cannot be reused. |
| Reusable browser runtime-kit release | **NOT YET QUALIFIED** | Mandatory browser delivery/input gates remain blocked. |
| Another external application | **UNTESTED** | It never inherits Octane's result. |

The browser blocker is a validation-capability blocker, not a demonstrated failure of Docker, Wine, noVNC, Edge, Firefox, or the target application. noVNC browser compatibility and the automation system's permitted control paths are separate questions.

## 2. Owner constraints

Do not weaken or reinterpret these:

- The target is an unchanged compiled Windows installer. Do not request source, rebuild, patch, repackage, inject a plugin, change its pipeline, or substitute a Linux/browser build.
- The installer and installed executable run only inside the Linux container through Wine. Never launch the installer with Windows interop.
- The delivered interface is a localhost browser tab. No RDP client, hidden FreeRDP bootstrap, XRDP-to-browser gateway, or Windows X server belongs in this profile.
- Each preview starts with a new container, Wine prefix, target install, settings/data, WebView2 user-data directory, and output area.
- Keep Docker Engine inside the explicitly selected Ubuntu 24.04 WSL2 distribution. Do not silently use Docker Desktop, a remote daemon, another distro, WSLC, or another engine.
- For the packaged operator path, that selected distribution is the dedicated imported `Octane` appliance. Docker Engine is outside the target container but inside that distro. Wine/WebView2/X11/noVNC are inside the target container.
- Preserve WSLC and the historical RDP profile as immutable secondary/control material. Do not expand them during browser work.
- Podman, Proton, CrossOver, VPN work, alternate distributions, host GPU mapping, Windows VMs, Kubernetes, and broad management UI are out of scope.
- Do not disable URL-policy enforcement or browser safeguards, expose localhost through a tunnel, weaken host security, or switch controllers merely to evade an automation restriction.
- No global Docker prune, WSL shutdown, distro unregister, VHD deletion, broad host mount, Docker-socket mount, privileged/host-network mode, ptrace, disabled sandbox, or unrelated cleanup.
- The source repository is public and has no open-source license grant. Do not publish additional logs, target binaries, raw screenshots/evidence, binary releases, or sensitive issue content without separate authorization and applicable redistribution review.
- Do not use the owner's private application name in generic prompts, docs, filenames, screenshots, commits, issues, or release metadata. Use `example-app`, `<app-id>`, and `<app-id>-octane`.

## 3. Architecture and trust boundaries

```text
producer pipeline / manual download
              |
       unchanged setup.exe
              |
  streamed hash + immutable local cache       optional data-only sidecar manifest
              |                                             |
 Windows Octane launcher -------------------- application profile
              |
 Windows 11 -> imported Octane Ubuntu WSL2 appliance -> Docker Engine
              |
 fresh Linux container + fresh Wine prefix + fresh target/WebView2 data
              |
 pinned Wine-Staging 11.21 + visible-region patch + winex11
              |
         Xvfb :1 + XFCE
              |
 loopback x11vnc <- Websockify/noVNC <- 127.0.0.1:PORT/octane.html
              |
     organization-approved Windows browser

 selected read-only input + scoped upload -> C:\octane-input
 separate writable output <- C:\octane-output
 local run/evidence/output directories survive container cleanup
```

Configuration layers are distinct:

| Layer | Example | Never infer from it |
| --- | --- | --- |
| Windows host | Windows 11 build 26200.8875 | Container distro or Wine version. |
| WSL distribution | Ubuntu 24.04.4, kernel 6.18.40.1 | Container base or Docker context. |
| Docker daemon | Engine 29.6.2, context `default`, Unix socket in WSL | Docker Desktop or Windows daemon. |
| Linux image | Browser layer over exact historical image | Installed target state. |
| Wine prefix | New `win64` prefix per run | Reusable cache or upgrade test. |
| Browser viewer | noVNC pixel/input transport | Target DOM, Tauri selector access, or app readiness. |

## 4. Exact measured identities

Historical immutable qualification:

- Harness commit: `7181a47ee47ae1d63b3bcd4fa6a480d45b560ee3`.
- Lock SHA-256: `0137c535f4eb0d15c12628801020b71f1952a18c65c524b7ac26874f6e6377c1`.
- Image ID: `sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c`.
- Batch: `qbatch-e2aaafff4b38`, 10/10 through the RDP path.

Previous browser checkpoint (preserved, superseded for executable work by `136944d`):

- Runtime harness commit: `b227260e579bc4806cbd92659ea9956b06fbb253`.
- Image reference: `octane-lab:browser-candidate-v1`.
- Local image/config identity: `sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba`.
- Candidate lock: `profiles/candidates/docker-wine-staging-11.21-visrgn-browser.candidate.lock.json`.
- Candidate lock SHA-256: `edea2b6489601775489dbc2a5ac6aae4bc2572940632040e98baa053c5077234`.
- noVNC commit: `63107bd06d9e1f6136ff21aeda8cd62cbf0d433e` (v1.7.0 lineage).
- Websockify commit: `e81894751365afc19fe64fc9d0e5c6fc52655c36` (v0.13.0 lineage).
- Wine commit: `2528aff26208257fdbf980666a4f0e66d47563ce`.
- Wine-Staging commit: `04414fee61f7d283072d40905816b928875b2d4b`.
- Visible-region patch SHA-256: `f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752`.
- Reference WebView2 runtime: Evergreen `157.0.4341.60`; each reference run rejects version drift and records the loaded path/hash/process arguments.
- Retained installer source: `7088eed9adb8403b9575afe1cc9e9c2984b29049`.
- Retained installer SHA-256: `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`.
- Retained installer length: `219,839,154` bytes.

Previous extracted-appliance checkpoint (preserved; its package bytes are not the refreshed package):

- Live-tested executable harness commit: `b88db7bafdf129f9727921d27a434a3174998df7`.
- Rootfs source commit: `d8654e38f1db10f11c5a96c69502b784b2aebb3a`.
- Ubuntu base: `ubuntu@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5`.
- Rootfs TAR: 503,298,560 bytes; SHA-256 `56f7445646c6442df301e39d5f4e325dae63b2e85d04a2e7f8d3c70b4cf3c5ae`.
- Appliance Docker: Docker CE 29.6.2, containerd 2.2.6, buildx 0.36.0, Compose 5.3.1.
- Compressed browser-image archive: 2,077,870,568 bytes; SHA-256 `a5876cac7604c47c6e06bcb890f3bc4dedd81aabfb3906a53d9b73929caf8a0e`.
- Uncompressed Docker-save archive: 2,083,884,032 bytes; SHA-256 `6c1f4f9fd364ed970fc1ba1796a71952e2f917ae7603ea3cf10903d6209dbfb5`.
- Loaded image ID: `sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba`.
- Final extracted-package run: appliance test `fd53638dc0`, container `octane-587fa94305`; every package-test lifecycle stage PASS and exact cleanup PASS from `Extracted Appliance ü\Octane-v1`.
- Evidence checksum manifest: SHA-256 `4f5bbcf6bd323ab2b10cfefdb1d2cf64c3d8d07b9192b1da0aec47515281faf3`.

This prior appliance result is component/lifecycle evidence. noVNC negotiation, browser framebuffer delivery, browser-originated input, and browser-specific application acceptance remained NOT_RUN.

Fresh-build/storage/upload candidate added 2026-11-15:

- Executable runtime commit: `136944da9e8b0ee4f3c6727613d062abbd958857`.
- Image reference: `octane-lab:browser-appliance-v1-136944d`; local image ID `sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a`.
- Candidate lock: `profiles/candidates/docker-wine-staging-11.21-visrgn-browser-appliance-136944d.candidate.lock.json`; SHA-256 `5227a24f4279a599679ff6adb00138776b93fd5205e8627ef11780b26acb4fff`.
- Exact live component run: `3ca7d5cbb6`; fresh installer/native window/WebView2/component checks, authenticated upload `pipeline input ü.csv`, input verification, collection, and exact cleanup PASS. Browser framebuffer/input remained NOT_RUN.
- Replacement lifecycle: `750fc957af` was collected and exactly removed before `603b83b9bf` started with a new WSL-native home/prefix on the same ports. Both used the same installer identity; this is replacement-mechanics evidence, not two-build application acceptance.
- Synthetic transport: 420 MiB (`440,401,920` bytes), same filename/different bytes, producer-hash truncation rejection, immutable reuse, and scratch cleanup PASS.
- Refreshed rootfs TAR: 503,298,560 bytes; SHA-256 `1c8cb6e36a880dcf491aaa12dc1d52c0819824902a2b272b36d3837c451e3368`.
- Refreshed compressed image archive: 2,078,023,379 bytes; SHA-256 `bf47e58e50ef56396ee3e1d43fdecda5de0426ede6c37342609c01c154240b05`; source Docker-save SHA-256 `5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe`.
- Refreshed extracted-package test: `2164864404`, container `octane-3fd2c8f429`; 84-file / 2,583,977,275-byte package, unique WSL import, Docker/image load, deep doctor, fresh retained-installer preview, browser/upload/no-RDP component checks, collection, stop, distro unregister, and storage cleanup PASS from `Octane Moonshot Extracted ü\Octane-v1`.
- Package manifest SHA-256 `c7793d91bddeb39857661aa0ff350a1303a7dca999aedbd92a9fa0479d0601c9`; package checksum-manifest SHA-256 `78ca4892559cce8c2a6b5339602affd0fee9116140637e0514df0ec7fcf9b514`; test result SHA-256 `8ad04f36734b35b2a22e7578791fd4cc81889fc7e35f457a9682a870b005073f`.

Those refreshed binaries remain local candidate artifacts pending redistribution review and browser qualification. The extracted component lifecycle passed; it does not establish browser framebuffer/input acceptance and is not a public binary release.

The browser image is a local identity, not an invented public registry reference. The private recovery archive is separate:

- File: `octane-browser-candidate-b227260.tar` outside Git.
- Length: `2,083,884,032` bytes.
- SHA-256: `6c1f4f9fd364ed970fc1ba1796a71952e2f917ae7603ea3cf10903d6209dbfb5`.
- Import was verified in place without deleting the only known-good image. This is not a second-laptop or cold-restore result.

## 5. Repository map

| Path | Contract |
| --- | --- |
| `lab/Dockerfile.browser-novnc` | Adds pinned noVNC/Websockify, x11vnc, curl, and browser launch helpers to the exact historical Wine image. |
| `lab/Dockerfile.wsl-appliance` | Builds the importable Ubuntu 24.04 management rootfs with pinned Docker packages and no populated Docker data root. |
| `packaging/windows/Install-Octane.ps1` | Verifies package/runtime hashes, imports the exact WSL distro without overwrite, starts internal Docker, streams the separate image archive into `docker load`, and installs the Windows launcher. |
| `packaging/windows/Octane.ps1` | Installed `doctor/open/compare/status/collect/stop/credential/target` front door; `open` safely replaces one active build and opens the default browser only after startup succeeds. |
| `packaging/windows/Uninstall-Octane.ps1` | Marker-checks and unregisters only the exact appliance, then removes only journaled approved roots. |
| `lab/browser/octane-browser-session` | Starts XFCE on Xvfb `:1`, loopback-only x11vnc, origin-checked Websockify, the scoped upload service, and writes session identity. |
| `lab/browser/octane.html` | Local noVNC client, observable viewer states, and authenticated explicit-file upload control; never asserts app readiness. |
| `lab/browser/octane-upload-server` | Per-run atomic upload intake with exact origin/auth, size/name/path limits, no overwrite, no downloads, and a SHA-256 manifest. |
| `lab/browser/octane-target` | Validates staged bytes, prepares prefix/file bridges, installs, discovers exactly one executable, launches, observes a native window, records WebView2, probes declared endpoints, and verifies copied inputs. |
| `schemas/application-profile.schema.json` | Versioned data-only target contract. |
| `schemas/artifact-manifest.schema.json` | Per-build immutable artifact identity. |
| `profiles/applications/octane-reference.app.json` | Trusted reference profile only. Do not use it as fallback for another target. |
| `profiles/candidates/*.json` | Browser candidate lock and explicitly blocked ten-run plan. |
| `templates/example-app/` | Honest generic overlay and manual checklist. |
| `scripts/Start-OctanePreview.ps1` | Provider-neutral daily front door with standalone, active-replacement, and isolated-comparison modes plus WSL-native per-run state. |
| `scripts/New-OctaneTarget.ps1` | Creates a small sibling overlay without source or installer bytes. |
| `scripts/Stage-OctaneArtifact.ps1` | Stable-file streamed copy/hash, atomic admission, signature metadata, content-addressed cache. |
| `scripts/Test-OctaneBrowserComponents.ps1` | Component-only checks; cannot promote browser acceptance. |
| `scripts/Collect-OctanePreview.ps1` | Revalidates host/container inputs, copies outputs/evidence, then leaves cleanup explicit. |
| `scripts/Stop-OctaneLab.ps1` | Idempotently removes only the exact asserted container, secret, marker-verified WSL session storage, and matching active journal. |
| `scripts/New-OctaneRuntimeKit.ps1` | Produces a source-independent private kit with checksums. |
| `scripts/Build-OctaneWslAppliance.ps1` | Reproducibly builds/exports the pinned management rootfs TAR and manifest. |
| `scripts/Compress-OctaneImageArchive.ps1` | zstd-compresses and verifies the separate Docker-save archive. |
| `scripts/New-OctaneApplianceRelease.ps1` | Assembles the private package layout and complete checksum manifest. |
| `scripts/Test-OctaneAppliancePackage.ps1` | Imports a unique test distro, exercises doctor/preview/components/collection/cleanup, and records the narrow result. |
| `docs/compatibility-matrix.md` | Dated results; historical observations are never rewritten. |
| `docs/research-evidence-ledger.md` | Claim/source/version/local-outcome/confidence ledger. |

Ignored `artifacts/`, `runs/`, `evidence/`, and `work/` hold binaries, credentials, raw results, caches, and recovery material. Never add them indiscriminately to Git.

## 6. Self-contained appliance install and operator workflow

The private appliance release has this contract:

```text
Octane-v1/
  Install-Octane.ps1
  Octane.ps1
  Octane.cmd
  Uninstall-Octane.ps1
  appliance/octane-ubuntu.tar
  images/octane-wine-image.tar.zst
  runtime/
  profiles/windows-tauri.json
  docs/
  manifest.json
  checksums.sha256
```

The WSL TAR contains Ubuntu userspace, systemd, a non-root `octane` operator, and pinned Docker management packages. It deliberately does not contain a populated `/var/lib/docker`. The zstd archive contains the pinned Wine/browser Docker image and is verified independently. This separation keeps the appliance and image recoverable and updateable without pretending a WSL export and Docker archive are the same artifact.

One-time install from Windows PowerShell 7:

```powershell
# Read every declared package/runtime file and verify hashes; change nothing.
./Install-Octane.ps1 -PackageRoot $PWD -PlanOnly

# Import the dedicated distro and load the exact image.
./Install-Octane.ps1 -PackageRoot $PWD
```

The installer uses supported `wsl.exe --import`, refuses an existing distro/home, verifies the appliance marker, starts Docker with systemd, streams `zstd -dc` into `docker load`, compares the loaded image ID, copies the source-independent runtime, and writes `config.json`. It does not enable WSL, install Windows features, elevate, unregister another distro, modify another Docker context, or execute the target installer.

Normal operator commands after opening a new terminal:

```powershell
octane doctor -Deep
octane target -Id example-app `
  -TargetOutput 'C:\Octane Targets\example-app-octane'

octane open 'C:\Builds\setup.exe' `
  -Profile 'C:\Octane Targets\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -BuildLabel 'pipeline-12345'

octane status
octane collect -Container octane-0123456789
octane stop -Container octane-0123456789
```

`open` creates a clean run, prints the run/container/artifact/URL identities, copies the per-run RFB password to the Windows clipboard without printing it, and calls the Windows default-browser association. `-NoBrowser` leaves startup intact and prints the explicit credential command for environments where automatic opening is blocked.

Uninstall is never automatic recovery. After collecting every wanted run, invoke the installed script explicitly:

```powershell
& "$env:LOCALAPPDATA\Octane\Uninstall-Octane.ps1" `
  -ConfirmDistributionRemoval
```

It validates the exact distro name, appliance marker, and cleanup roots before terminating/unregistering. It does not remove input/output/evidence outside the installed launcher and distro-storage trees.

The refreshed package was assembled directly under a path containing spaces and `ü`. Its manifest/hash plan and live import/doctor/preview/components/collection/cleanup lifecycle passed without source-tree runtime fallback. The live package test used an explicit WSL-visible project state root because this Codex execution sandbox projects `%LOCALAPPDATA%` into a view that `wsl.exe` cannot see. The production `%LOCALAPPDATA%\Octane` plan and package hashes passed, but a normal unsandboxed operator install at that default path was not separately executed here. This is an execution-environment limitation, not a reason to weaken ACLs or host policy.

## 7. Source-tree prerequisite and image setup

Use Windows PowerShell 7. `wsl.exe` is a Windows command. Do not type `wsl` or `wslc` inside Ubuntu and install an unrelated package when the shell reports “not found.”

```powershell
./scripts/Doctor-OctaneLab.ps1 -Engine Docker `
  -WslDistro Ubuntu-24.04 -Port 3005 -Deep
```

Doctor is read-only except for its disposable labeled smoke container. It records Windows/WSL/kernel/distro, Docker client/server/context/socket/root/storage/memory, buildx, architecture, a run/copy-out test, loopback reachability, and exact doctor cleanup. On Windows it requires a local Unix-socket Docker context in the selected distro and rejects Docker Desktop/remote servers.

Build only if the exact historical base image is present:

```powershell
./scripts/Build-OctaneBrowserImage.ps1 `
  -WslDistro Ubuntu-24.04 `
  -BaseImage octane-lab:qualification-7181a47ee47a `
  -ExpectedBaseImageId sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c `
  -Image octane-lab:browser-appliance-v1-136944d `
  -HarnessCommit 136944da9e8b0ee4f3c6727613d062abbd958857
```

Or load the private recovery archive with the exact hash shown in section 4. Do not repull a mutable tag or silently rebuild against a different base after locking.

## 8. Onboard a generic application without source

Create a sibling overlay:

```powershell
./scripts/New-OctaneTarget.ps1 -Id example-app `
  -Output ../example-app-octane
```

The overlay contains:

```text
example-app-octane/
  app.json
  MANUAL-CHECKLIST.md
  octane-runtime.json
```

It contains no source and no installer. Do not create a remote repository without authorization.

Inspect an unfamiliar installer safely:

1. Preserve the exact bytes and calculate SHA-256 and length without executing it on Windows.
2. Inspect Authenticode metadata if available; an unsigned result is not automatically malicious, and a checksum is not publisher authentication.
3. Establish installer kind, x64 architecture, per-user/system behavior, documented silent arguments, success/reboot codes, dependencies, and expected executable location.
4. Do not guess `/S`, `/quiet`, install scope, path, executable, or title. Leave `argumentsVerified=false` until established.
5. Put build label and optional producer hash/provenance beside the artifact, not into a permanent target profile hash.
6. If the installer requires unavailable drivers, services, machine identity, Office, integrated auth, client certificates, or Windows-only APIs, record the precise compatibility result. Do not modify the target to hide it.

Validate only data:

```powershell
./scripts/Test-OctaneTargetProfile.ps1 `
  -Profile ../example-app-octane/app.json -Operational
```

Validation rejects traversal, malformed IDs, newline/NUL arguments, mismatched executable paths, unsafe regexes, credentials in endpoint URLs, unsupported schemes, templates marked operational, and unknown schema fields. Arrays are passed as native arguments; no `eval` or `Invoke-Expression` is used.

## 9. Application-profile contract

`schemaVersion: 1` separates the following:

- Runtime relationship: Octane release and the one browser Wine profile.
- Installer: `nsis`, `x64`, verified argument array, timeout, accepted exit codes, current-user scope.
- Application: exact executable filename or traversal-free relative path, argument array, bounded title regex/readiness deadline, WebView2 requirement/distribution/expected version.
- File access: copy mode, read-only `C:\octane-input\selected`, read-only `C:\octane-input\uploaded`, and writable `C:\octane-output`; source input is read-only by construction.
- Network: an allowlist of explicit HTTP/HTTPS endpoints and acceptable status codes. URLs cannot embed credentials.
- Scenario: manual-only or one trusted repository-maintained scenario ID. A profile never supplies a script path or downloaded code.
- Status: template, preview-only, scenario-defined, or qualified. Status is scoped to an artifact and lock; it is not a generic compatibility label.

Never fall back to the reference Octane binary if another target installation or lookup fails. Exactly one executable must be found, and its path/hash is recorded.

## 10. Daily new-build workflow

Acquisition is separate. The developer downloads one explicit pipeline artifact or uses an optional authorized provider adapter. Octane does not watch download folders, poll pipelines, or execute every `setup.exe`.

Installed-appliance command:

```powershell
octane open 'C:\Builds\setup.exe' `
  -Profile '..\example-app-octane\app.json' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -BuildLabel 'opaque-producer-build-12345'
```

Source-tree equivalent for framework development:

```powershell
./scripts/Start-OctanePreview.ps1 `
  -Profile ../example-app-octane/app.json `
  -Installer 'C:\Builds\setup.exe' `
  -InputDirectory 'C:\TestData\Inputs' `
  -OutputDirectory 'C:\TestData\Results' `
  -WslDistro Ubuntu-24.04 `
  -Port 3005 -UploadPort 3006 `
  -Image octane-lab:browser-appliance-v1-136944d `
  -BuildLabel 'opaque-producer-build-12345' `
  -LifecycleMode ReplaceActive
```

The script performs these bounded steps:

1. Validates the application profile.
2. Ensures input/output are distinct and rejects input reparse points.
3. Opens the EXE read-only, hashes while copying with an 8 MiB buffer, detects source metadata changes, flushes, rehashes the staged copy, and atomically moves it to `installer-<sha256>.exe`.
4. Creates run identity, input manifest, ignored Windows-side credential record, marker-owned WSL-native session tree, and resource journal before dependent resources. The secret crosses the WSL boundary over standard input, never a command argument.
5. Runs deep doctor and verifies the selected image's browser/no-RDP labels.
6. Creates a fresh container with independent loopback viewer/upload publications, 1 GiB shared memory, exact selected/artifact read-only mounts, a target-read-only/upload-service-writable upload view, fresh WSL-native home/output, and one read-only password-file mount.
7. Copies the profile/manifest into the fresh container and exposes only the exact immutable installer and selected/uploaded trees; source files are never mounted broadly.
8. Rechecks the host input manifest after copy and the installer hash inside the container.
9. Creates a new Wine prefix, installs, discovers exactly one executable, launches once, observes the native X11 window, and records loaded WebView2 process/path/version/hash.
10. Records the viewer/upload session identities, prints the exact viewer URL and explicit credential command, and never prints the password.

The 420 MiB synthetic capacity test passed: 440,401,920-byte files streamed/hashed, same filename with different bytes produced different identities, a truncated file failed the authoritative producer hash, and identical bytes reused the immutable cache. This is transport evidence only, not a second executable installer result. A second real installer was unavailable, so two-build application acceptance remains NOT_TESTED.

## 11. Browser viewer and manual operation

Credential retrieval defaults to the Windows clipboard:

```powershell
./scripts/Get-OctaneViewerCredential.ps1 -Container octane-0123456789
```

`-Reveal` exists only for a private terminal and emits a warning because terminal capture may retain the secret.

Open the exact printed path, not `/` by assumption:

```text
http://127.0.0.1:3005/octane.html
```

The viewer exposes these supported noVNC states:

- Viewer page loaded.
- WebSocket connection attempted.
- Authentication required.
- VNC negotiated; application readiness unverified.
- Security negotiation failed.
- Clean or unexpected disconnect.
- Run/display/resolution identity loaded from the current container.

The password exists only in the page's memory after entry and is not placed in a URL. The profile uses plaintext HTTP/WebSocket because it is strictly loopback and this noVNC flow does not require a remote secure context. There is no machine-wide CA or disabled certificate verification. This is not suitable for LAN/internet exposure: a stronger gateway/TLS design requires a separate security review and requalification.

x11vnc listens only on `127.0.0.1:5901` and `[::1]:5901` inside the container. Websockify port 3000 and the scoped upload service port 3002 receive separate Windows/WSL loopback publications; raw VNC is never published. Websockify and upload require origins matching the exact `127.0.0.1` or `localhost` viewer URL/port. The eight-character RFB password is per run and is reused only in browser memory as the upload bearer value. Clipboard and remote resize are disabled. The fixed server resolution prevents connection-time resizing from acting as a hidden repaint helper.

Manual checklist:

1. Confirm the real application client, not a desktop, frame, viewer canvas, or spinner.
2. Confirm first rendering without resize/minimize/restore, reconnect, click-to-wake, relaunch, or helper.
3. Send mouse, keyboard, focus, and scroll through noVNC.
4. Use the real open dialog from the target; select controlled input from `C:\octane-input\selected`, cancel, and reopen.
5. Upload one controlled file with the Octane control, select it from `C:\octane-input\uploaded`, and run the target's real ingestion behavior.
6. Use the real save dialog; cancel, then export to `C:\octane-output`.
7. Confirm post-dialog responsiveness and independently validate output.
8. Capture browser-attributable screenshots/recording separately from container-native diagnostic images.

An operator result is a manual smoke test. It never becomes an unattended run or automatic PASS.

## 12. File bridge and clean-state model

The target's picker sees the Wine filesystem, not the entire Windows laptop.

- Host input is enumerated and hashed; symlinks/junctions are rejected.
- Copy mode stages only that tree into marker-owned WSL storage and exposes it read-only at `C:\octane-input\selected`.
- The authenticated upload service accepts explicit files only, writes atomically to a separate per-run staging tree, manifests hashes, and exposes that tree read-only to the target at `C:\octane-input\uploaded`. It provides no download, delete, overwrite, or directory-browsing API.
- The host input is never mounted writable. The copied tree is rehashed before collection, and the original host tree is independently rehashed against the startup manifest.
- Output is a separate disposable `C:\octane-output`; collection writes to `<operator-output>/<run-id>` and refuses overwrite.
- Container cleanup cannot delete the independently collected output/evidence.
- UNC/mapped-drive identity is not assumed to cross WSL. Stage authorized network files explicitly or validate a narrow daemon-visible mapping. Do not claim live-share semantics after a local-copy test.
- Paths with spaces and Unicode were exercised for the runtime kit and input contract. Broad `C:\`, `/mnt/c`, home, or network-tree mounts are forbidden.

What can be cached: pinned Linux/Wine/browser image, verified content-addressed EXE cache, package/download layers, local evidence, and previous installer bytes under explicit retention.

What is always fresh: container, Wine prefix and registry, installed target, target settings/data, WebView2 user-data, output tree, run credential, and run identity.

This release implements one-active-build replacement and explicit isolated comparison, but not in-place upgrade, profile migration, same-prefix rollback, or persistent target cookies/tokens.

## 13. Network capability model

Localhost-only inbound viewer exposure does not disable target egress. A profile declares only endpoints it needs; probes are bounded and never scan a subnet.

Each endpoint has an ID, HTTP/HTTPS URL without credentials, and accepted status-code array. The probe records exit code, HTTP status, remote IP, and duration. TLS verification remains enabled. A reachable controlled container service returned PASS/exit 0; an unavailable port produced `accepted:false` and exit 1.

The probe is explicitly **Linux container curl only**. It does not prove:

- Wine WinHTTP/WinINet behavior.
- WebView2 network behavior.
- Target protocol semantics.
- Proxy, corporate CA, authentication, authorization, Kerberos, CAC/smart-card, client certificate, machine compliance, or domain identity.
- Windows localhost, WSL host, Docker gateway, or `host.docker.internal` equivalence.

Never copy Windows browser cookies, Credential Manager data, private keys, tickets, certificates, or machine secrets into the container automatically. If a target requires one of those, identify the exact dependency and report PASS, FAIL, BLOCKED, or NOT_TESTED for an approved mechanism.

## 14. Collection, evidence, and status semantics

```powershell
./scripts/Collect-OctanePreview.ps1 `
  -Container octane-0123456789 `
  -WslDistro Ubuntu-24.04 `
  -ScreenshotDirectory 'C:\Evidence\browser-smoke'
```

Evidence includes run/environment/results/JUnit metadata, doctor record, target preparation, installer manifest and in-container hash, installed executable identity, WebView2 identity/processes, native X11 window observation, viewer logs/session identity, network probes, input manifests, output checksums, optional operator screenshots/recording, and overall checksum manifest. Only files actually produced are included.

With the installed appliance, `octane collect -Container <exact-name>` and `octane stop -Container <exact-name>` call the same shared scripts against the appliance's internal Docker daemon.

Keep meanings exact:

- `PASS`: the named gate executed and satisfied its contract.
- `FAIL`: the named gate executed and contradicted the contract.
- `BLOCKED`: another failed or unavailable prerequisite prevented the gate.
- `NOT_RUN`: it was not attempted.
- `NOT_TESTED`: the capability was absent from this target/profile or lacked authorized infrastructure.

HTTP 200 proves only static viewer delivery. VNC `connect` proves negotiation, not application readiness. A native screenshot proves only container-side X11 state, not the browser frame. A process/window/WebView2 path proves runtime presence, not visible rendering. Direct X11 automation while a browser page sits open does not prove browser-originated input.

Raw evidence may contain paths, filenames, screenshots, and output data. Keep it private and local. Review/redact before any publication. Never log the credential or include it in manifests/checksums intended for sharing.

## 15. Exact cleanup and failure recovery

```powershell
./scripts/Stop-OctaneLab.ps1 `
  -Container octane-0123456789 `
  -Engine Docker -WslDistro Ubuntu-24.04
```

The stop path asserts the exact managed container and engine context, removes that container and anonymous volumes, updates the run journal, and removes only `runs/secrets/<exact-container>`. It does not delete the immutable image unless an explicit historical command requests its own run image, and it never prunes.

On failure:

1. Keep the exact run ID.
2. Collect before deleting.
3. Inspect stage reason, container log, browser component JSON, viewer/X11 logs, target logs, process arguments, cgroup/OOM/resource state, and current listeners.
4. Preserve the first outcome. Do not retry until it looks good and erase the failure.
5. Remove only the exact resource after evidence exists, or deliberately retain it and state the handoff command.

If the controller is interrupted, use `runs/octane-<id>.json` and labels `com.octanelab.managed=true`, `com.octanelab.run=<id>` to reconcile. Never match only a loose name substring.

## 16. Troubleshooting decision path

| Layer | Evidence | Typical classification |
| --- | --- | --- |
| Windows/WSL | `wsl --version`, doctor host facts | Missing distro/kernel/policy: environment FAIL/BLOCKED. |
| Docker | context/socket/server/root, deep smoke | Wrong daemon/context: preflight FAIL; do not switch silently. |
| Image | exact ID/labels/base, build record | Drift or missing image: integrity FAIL/BLOCKED. |
| Viewer HTTP | exact `/octane.html`, port binding | HTTP failure: transport setup FAIL. HTTP 200 is not VNC/app PASS. |
| WebSocket/VNC | origin rejection, x11vnc listener, noVNC state | Negotiation/security/credential failure: viewer FAIL. |
| X11 | Xvfb socket, resolution, Wine process `DISPLAY`, `winex11.drv` maps | Display mismatch: X11/Wine FAIL. |
| Installer | in-container SHA, exit/timeout, one executable | Installer or discovery FAIL; never fall back. |
| WebView2 | loaded path/version/hash/process args | Drift/process failure; still separate from pixels. |
| Native client | X11 window/title/geometry/container image | Native observation only; browser delivery still BLOCKED. |
| Browser pixels/input | browser-attributable frame changes and input | Mandatory browser acceptance evidence. |
| Dialog/target | foreground/modal return/output | Distinguish API, presentation, focus, automation, filesystem, and app integration. |
| Output | independent parser/hash/no-overwrite/input integrity | Functional PASS/FAIL independent of visual review. |

Do not resume broad GPU/Wine flag searches. The current candidate already uses the qualified Wine build and records effective WebView2 arguments. The minimal native WebView2 probe remains white; that does not erase observed Octane success, and Octane success does not make the probe pass.

## 17. Qualification boundary and blocked ten-run plan

The candidate lock status is `candidate-end-to-end-blocked`, not qualified. The declared batch `browser-qbatch-...` lists ten planned runs, each `NOT_RUN` with the same browser-control blocker. This is more accurate than executing the app entirely through X11 and claiming the browser path.

Resume only when an approved browser-control path exists. Freeze the final candidate, then run ten sequential fresh containers/prefixes. The automatic client must receive frames and send input through noVNC. Every run must prove viewer/auth/session identity, unchanged installer/runtime, initial browser-visible client without helper, continuing pixels and input, real 8-file workload, Unicode/space/missing paths, native open/save cancel/reopen/multi-select, correct export/no-overwrite/input integrity, post-dialog responsiveness, browser/native evidence, and exact cleanup. A single FAIL/BLOCKED/NOT_RUN or missing evidence makes the batch not 10/10.

After changing image, viewer, Wine/patch, WebView2, script, timeout, fixture, browser behavior, or security policy, generate a new lock and start a new batch. Never replace a failed run or manually promote one.

## 18. Runtime kit and recovery

Create a private source-independent kit:

```powershell
./scripts/New-OctaneRuntimeKit.ps1 `
  -OutputDirectory 'C:\Approved\Octane Kit 1' `
  -Version browser-appliance-v1-136944d-candidate `
  -HarnessCommit 136944da9e8b0ee4f3c6727613d062abbd958857
```

The kit includes scripts/modules, profile schemas/templates, browser image layer, reference profile/fixtures, locks, validation helpers, this document, quick start, compatibility/research records, and checksums. It excludes target source, installer bytes, image bytes, credentials, provider tokens, Git metadata, and raw evidence.

Build the larger private appliance release only from verified inputs:

```powershell
./scripts/Build-OctaneWslAppliance.ps1 `
  -OutputPath 'work\appliance\octane-ubuntu.tar'

./scripts/Compress-OctaneImageArchive.ps1 `
  -InputPath 'work\moonshot-appliance-136944d\images\octane-wine-image.tar' `
  -OutputPath 'work\appliance\octane-wine-image.tar.zst'

./scripts/New-OctaneApplianceRelease.ps1 `
  -ApplianceTar 'work\appliance\octane-ubuntu.tar' `
  -ImageArchive 'work\appliance\octane-wine-image.tar.zst' `
  -RuntimeKitDirectory 'work\runtime-kit' `
  -OutputDirectory 'work\Octane-v1' `
  -Version '1.0.0-browser-candidate.136944d' `
  -ImageReference 'octane-lab:browser-appliance-v1-136944d' `
  -ImageId 'sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a' `
  -UncompressedImageArchiveSha256 5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe
```

The release builder verifies its input manifests before copying and writes a top-level manifest plus checksums for every packaged file. Large archives remain outside Git. The source repository is public, but redistribution permission for third-party binaries is not inferred from a successful build; keep the binary candidate local until license review and a separate binary-release decision are complete.

The extracted-kit exercise used a path containing spaces and `ü`, created/validated `example-app-octane`, staged the external retained EXE to the exact hash, started a clean preview without source-tree fallbacks, passed every available component check, collected output/evidence, and removed the exact container. Browser input remained blocked. Re-run this exercise after final docs/kit packaging changes.

Image recovery:

```powershell
./scripts/Export-OctaneBrowserImage.ps1 `
  -OutputPath 'C:\Approved\octane-wine-image-136944d.tar' `
  -Image octane-lab:browser-appliance-v1-136944d `
  -WslDistro Ubuntu-24.04
```

Keep archive/manifest together outside Git. Import verifies archive SHA before Docker reads it and optionally asserts the expected loaded image ID. The image recipe documents inputs but does not prove byte-for-byte reproducibility; the archive checksum is integrity, not authenticity.

## 19. CI/provider independence

Core commands require only local files and do not call `gh`, `glab`, GitHub, or GitLab. Producer build, Windows reference compilation, static/unit/mock checks, image preparation, and live browser acceptance are separate jobs. Hosted CI is not assumed to provide WSL, nested Docker, interactive display, or a Windows browser.

Provider wrappers may check out, select a trusted runner, invoke shared scripts, and upload private results. They must not duplicate acceptance logic or execute untrusted public pull requests on a runner with desktop/network access. A green build/static job is never GUI qualification. No live GitLab project result is claimed.

## 20. Updating, requalifying, and rolling back

Treat these as qualification-sensitive: target installer, Wine/Staging/patch, WebView2, X11/desktop, noVNC/Websockify/x11vnc, browser/controller, controller/scenario code, fixtures, host/WSL/kernel/Docker, ports/security policy, and timeouts.

Update procedure:

1. Preserve the prior image, lock, evidence, and guide.
2. Change one intentional layer or a justified dependent patch set.
3. Run static/unit tests and focused component/live diagnostics.
4. Commit executable code before generating a lock to avoid self-reference.
5. Rebuild with the executable commit label; record exact image/base/package identities.
6. Run manual/browser acceptance through an approved path.
7. Declare and execute a new ten-run batch; preserve every attempt.
8. Publish only after authorization and only with accurate candidate/qualified wording.

Rollback means selecting a retained exact image/profile/installer in a new clean run. It does not mean downgrading a live prefix or deleting later evidence.

## 21. Known limitations

- Browser framebuffer/input/manual smoke and ten-run qualification are not yet executed.
- HTTP/RFB on loopback is not a remote multi-user security design.
- The custom Wine visible-region patch is a maintenance condition.
- The native Win32 WebView2 probe remains white.
- The reference app's successful RDP qualification does not generalize to stock Wine, arbitrary Tauri apps, another installer, or Windows-equivalent identity/auth/services.
- Only one real retained installer was available. The 420 MiB second-build tests are synthetic transport tests, not app acceptance.
- Generic network probes establish only Linux curl reachability. Corporate authentication and target protocol behavior remain target-specific.
- No native Windows control, second laptop restore, public registry digest, live GitLab pipeline, or public release is claimed.
- A complete self-contained appliance lifecycle passed from a project-scoped WSL-visible state root. The normal `%LOCALAPPDATA%` install was plan/hash tested but could not be live-executed through this Codex sandbox's projected filesystem view.
- The appliance artifacts are roughly 2.58 GB combined before runtime/docs overhead; importing WSL distributions may require organizational approval and adequate disk space.

## 22. Ready-to-paste AI onboarding task

```text
Use docs/OCTANE-AI-HANDOFF.md as the authoritative Octane specification.
Work in the existing clone/runtime kit or installed Octane appliance. Preserve
historical evidence and the browser candidate lock. Onboard the unchanged
compiled installer at <EXE_PATH> as target ID <APP_ID> using a small
<APP_ID>-octane data overlay.

Do not request target source, recompile or patch the target, change its build
pipeline, substitute a Linux/browser build, install it on Windows, add RDP,
disable browser safeguards, expose localhost publicly, weaken host security,
switch Docker context/distro/runtime silently, or invent results.

Inspect and verify installer flags, executable identity, dependencies, file
mapping, and declared endpoints. Run doctor, validate the profile, stage and
hash the exact EXE, start one fresh browser preview, print the exact localhost
URL and safe credential command, preserve PASS/FAIL/BLOCKED/NOT_RUN semantics,
collect evidence before exact cleanup, and report only what actually ran.

Browser readiness requires the target client pixels and browser-originated
input, not HTTP 200, VNC connect, a process, DOM activity, or container-side
screenshots. If approved browser control is unavailable, leave browser
acceptance BLOCKED and provide the exact manual operator handoff.
```

## 23. Smallest next action

With candidate run `octane-c71f9b509b` still present, an authorized operator can run `Show-OctaneManualBrowserHandoff.ps1`, open its verified URL in an approved Windows browser, perform the seven-step smoke checklist, collect attributable browser evidence, and then stop the exact container. If the run is gone, recreate it from the locked image/profile/installer. Only after that smoke succeeds should unattended browser qualification resume.

## 24. Implemented fresh-build replacement and WSL storage design

The runtime now implements immutable intake before replacement, one active build by default, explicit isolated comparison, WSL-native per-run application state, separate selected/uploaded input views, retained Windows outputs/evidence, and authenticated browser upload. The implementation and protocol/component checks passed. Browser-originated file selection and application ingestion through the streamed GUI remain unverified because the approved browser path is still blocked.

### Fresh application state for every build

Keep the Ubuntu WSL appliance, Docker Engine, and pinned patched Wine/browser image installed. For each new Windows installer, create a fresh application session containing a new container, Wine prefix, registry/settings state, application user profile, WebView2 user-data directory, installation, output area, and viewer credential. Do not rebuild Wine, reinstall Docker, or reimport WSL for each pipeline build.

```text
build pipeline -> new Windows x64 installer
               -> Octane streams and hashes exact bytes
               -> new disposable container and Wine prefix
               -> fresh install, settings, WebView2 data, and profile
               -> actual Windows executable under Wine
               -> authenticated localhost browser viewer
```

The implemented everyday command is:

```powershell
octane open 'C:\Builds\Application-v2.4.0.exe'
```

For a generic target, supply the explicit profile and directory parameters shown in section 6. An installed appliance may use its validated default reference profile, but another target never falls back to Octane's binary or selectors. The major changing artifact is the new installer; the known-good WSL appliance and Wine/browser image remain cached.

### One active build by default

`open` now replaces the active build by default:

1. Build 101 starts in `octane-101`, with a fresh install and browser session.
2. When Build 102 is requested, Octane first records Build 101's identity, collects requested logs, screenshots, reports, and exports, and reports any collection failure.
3. Octane removes only Build 101's exact managed container, writable layer, Wine prefix, temporary application state, WebView2 data, per-run credential, and session-owned storage.
4. Build 102 then starts in a new container and clean application environment.

Never erase a failed build before evidence collection. A replacement failure must not silently fall back to the prior build or delete unrelated resources. The controller must use immutable run IDs and ownership labels, not name substrings.

| Resource | Replacement policy |
| --- | --- |
| Ubuntu WSL appliance | Keep |
| Docker Engine | Keep |
| Patched Wine/WebView2 browser image | Keep |
| Previous application container and writable layer | Delete after collection |
| Previous Wine prefix, settings, application data, and WebView2 data | Delete |
| Installer copy inside the previous session | Delete |
| Optional verified installer cache | Separate, bounded retention policy |
| Synthetic test-input library | Keep |
| Collected exports and evidence | Keep outside disposable state |
| Producer-pipeline installer | Governed by pipeline retention policy |

Docker documents that `docker rm -v` removes anonymous volumes but does not remove named volumes. Octane must therefore journal every session-owned mount or directory and remove only those exact resources. It does not need, and must never substitute, a global `docker system prune`. See [Docker container removal](https://docs.docker.com/reference/cli/docker/container/rm/).

`octane compare` retains the active build and starts an independently isolated comparison. It requires an explicit unused viewer port; the upload port is also explicit or adjacent. It allocates a separate container, prefix, ports, credential, application data, inputs/outputs, and evidence identity. The implementation is contract-tested; the live replacement transaction, not a parallel comparison, was exercised in this pass.

### WSL-backed file ingestion

Prefer the WSL Linux filesystem for Octane's intensive working data while letting the operator select permitted files and output destinations from Windows. Keep three trust and lifecycle zones separate:

```text
Windows operator input                 Implemented WSL-owned working state
C:\Octane\Input                       /var/lib/octane/sessions/octane-<run>/
                                         artifact/       read-only in target
                                         selected/       read-only in target
                                         upload/         write-only service / read-only target view
                                         home/.octane/
                                           prefix/       disposable
                                           output/       collected before cleanup
                                           evidence/     collected before cleanup

Wine-visible stable paths             Windows collection destination
profile-defined input path             C:\Octane\Output
profile-defined output path
```

The exact session root is journaled before container creation and carries a marker checked before deletion. The reference profile uses `C:\octane-input\selected`, `C:\octane-input\uploaded`, and `C:\octane-output` inside Wine. Wine's broad `Z:` mapping is available only while the immutable installer executes from its read-only Unix mount, then removed before the installed application launches.

Support two deliberately different ingestion methods:

1. **Windows folder staging.** The implemented launcher accepts `-InputDirectory` and `-OutputDirectory`. Octane validates the Windows paths, rejects traversal/reparse escapes, hashes inputs, copies them into WSL-native per-run staging, rehashes the copy, and presents input read-only where practical. Output uses a distinct writable location and is copied to the selected Windows destination during collection.
2. **Authenticated browser upload.** The Octane control outside the streamed viewport accepts explicitly selected files only after the noVNC credential succeeds. It enforces the exact viewer origin, bearer authentication using that in-memory per-run credential, a 512 MiB per-file cap, Windows-safe basenames, atomic completion, no overwrite, and SHA-256 manifests. It exposes no download, delete, or directory-management endpoint. The target sees uploaded files read-only under `C:\octane-input\uploaded`. Direct localhost protocol and Wine-path checks passed; a real browser click/upload remains NOT_RUN.

The installed Windows launcher uses PowerShell-native parameters:

```powershell
octane open 'C:\Builds\Application.exe' `
  -InputDirectory 'C:\Octane\Input' `
  -OutputDirectory 'C:\Octane\Output'
```

Docker bind mounts are resolved on the Docker daemon host, not the invoking client, and are writable by default. Octane converts/stages into explicit daemon-visible WSL paths and uses read-only mounts for the selected/artifact/application upload views. See [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/).

### Recommended physical placement

| Data type | Recommended location |
| --- | --- |
| WSL appliance and reusable Docker image | WSL virtual disk |
| Per-build Wine prefix, settings, and WebView2 state | Disposable WSL/container storage |
| Large active ingestion datasets | WSL ext4 storage |
| Installer downloaded from CI | Windows build folder, then immutable staged copy in WSL |
| Exported results | Per-run WSL staging, then collected to selected Windows output |
| Screenshots, logs, and machine-readable evidence | Persistent WSL evidence, optionally exported after redaction |

Microsoft recommends storing files in the WSL filesystem when Linux tools perform the intensive work, rather than repeatedly operating across `/mnt/c`. Windows can access Linux files through `\\wsl$\<DistroName>\...` or `\\wsl.localhost\<DistroName>\...`. See [working across Windows and Linux filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems) and [WSL interop](https://learn.microsoft.com/en-us/windows/dev-environment/wsl-interop).

The internal session root is intentionally controller-owned and normally accessed through Octane collection rather than edited in Explorer. For diagnosis it is reachable through the actual distro identity, for example:

```text
\\wsl.localhost\Octane\var\lib\octane\sessions\
```

`Octane` is the default appliance distribution name but can be changed at installation. Discover the installed distribution identity from Octane configuration rather than assuming it. Do not manually alter a live session tree and then claim integrity.

### Application and security contract

The staged files must behave like ordinary files on a stable Wine-accessible filesystem. A target-specific scenario should verify native-dialog selection; file content; folders and filenames containing spaces and Unicode; separate writable exports; cancellation and repeated use; unchanged inputs; and any explicitly approved network endpoint. These tests do not establish native Windows ACL, domain authentication, mapped-drive, client-certificate, device-compliance, or integrated-identity equivalence.

Destroy application settings and caches with the session. Preserve only deliberately separated inputs, verified installer cache entries, exports, and evidence according to their retention policies. Use approved test artifacts and permitted data. The WSL/container architecture must not bypass endpoint controls, organizational execution policy, data-handling rules, identity restrictions, or missing authorization.

The implemented non-browser lifecycle now proves: stage a new EXE identity, preserve the stable WSL/Docker/Wine foundation, collect/remove the exact previous run, start a fresh installation, expose selected/uploaded inputs through stable Wine paths, retain outputs/evidence, and clean only marker-owned state. It does not yet prove browser-delivered pixels/input/upload, the target workload/dialog/export path through noVNC, two distinct real application builds, or the required browser-specific 10/10 batch.
