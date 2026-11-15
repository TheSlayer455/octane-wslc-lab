# Browser runtime-kit completion ledger

Reconciled 2026-11-15. This is the single A–I release-gate ledger for the browser/appliance candidate. `PASS` applies only to the named scope; browser acceptance cannot be inferred from an HTTP response, native X11 screenshot, component PASS, installer PASS, or upload-protocol PASS.

| Gate | Status | Evidence and exact meaning | Remaining item |
| --- | --- | --- | --- |
| A. Historical baseline preserved and recoverable | PASS | Historical lock SHA-256 `0137c535...`, image ID `0443029e...`, batch `qbatch-e2aaafff4b38`, v0.1.1, guide records, retained handoff container, and WSLC backup were not changed or deleted. | None for preservation. |
| B. Browser-only desktop from Windows without RDP | BLOCKED | Final executable candidate run `3ca7d5cbb6` passed exact X11 `:1`, 1280x800, authenticated loopback x11vnc, origin-checked Websockify, loopback viewer/upload publication, Wine `DISPLAY=:1`/`winex11.drv`, and no XRDP/FreeRDP process/listener. HTTP/component results are not framebuffer/input evidence. | Approved operator smoke or approved browser automation. |
| C. Unchanged external-installer intake and generic profiles | PASS | `schemas/application-profile.schema.json`, `New/Test-OctaneTarget`, immutable `Stage-OctaneArtifact`, and `Start-OctanePreview`. The retained external EXE SHA-256 `adde062d...` was rehashed inside fresh containers and one exact executable/WebView2 runtime was identified. | Another target remains separately UNTESTED. |
| D. AI-assisted onboarding from one document and kit | PASS for document/overlay/component scope; browser interaction BLOCKED | `docs/OCTANE-AI-HANDOFF.md` records the originating ChatGPT conversation and repository contracts. The source-independent package passed from a path containing spaces/Unicode with no source-tree runtime fallback. | Supply browser-attributable evidence. |
| E. Two-build replacement and ~400 MiB transport | PASS for replacement mechanics and transport; BLOCKED for two distinct real builds | Live pair `750fc957af` → `603b83b9bf` proved validate-first, collect/exact-remove-old, reuse ports, fresh state, active-journal transfer, and cleanup. Both used the same retained installer. Synthetic 420 MiB evidence `evidence/artifact-transport-moonshot-136944d` proved interruption rejection, same-name/different-content identities, immutable reuse, and exact cleanup. | Supply a second authorized real installer for two-distinct-build application validation. |
| F. File and network capabilities | PASS for selected/uploaded/output and declared generic network scopes | Selected Windows input is hashed/staged into WSL-native storage and mounted read-only. Authenticated upload enforces exact origin/bearer, 512 MiB/file, safe names, atomic completion, no overwrite/download/listing, SHA-256 manifest, and read-only target view. Run `3ca7d5cbb6` proved a Unicode upload visible at `C:\octane-input\uploaded`; browser-origin click and target ingestion remain NOT_RUN. Existing controlled Linux-curl reachable/unavailable endpoint classification remains valid only for that probe path. | Browser-origin upload/ingestion plus target-specific Wine/WebView2/network/auth paths. |
| G. New 10/10 browser-only Octane batch | BLOCKED | Candidate lock SHA-256 `5227a24f...`; planned browser runs remain 0/10. Historical RDP batch is explicitly excluded. | Approved browser-control path, then one frozen ten-run batch. |
| H. Failure recovery, exact cleanup, integrity, security tests | PASS for available scope | 48 browser/runtime assertions, 30 appliance assertions, 12 upload protocol assertions, 48 PowerShell harness assertions, 12 qualification-policy assertions, and 19 Node tests passed (169 counted assertions/tests across separate suites). Exploratory run `9500a6e5d0` retains the early-`Z:` installer failure; correction and cleanup retry are attributable. No global prune/WSL shutdown or security bypass was used. | Browser-specific framebuffer/input/auth failure cases require an approved browser. |
| I. Runtime kit, appliance/image recovery, shared commands, docs, release integrity | BLOCKED as a qualified release; refreshed component lifecycle PASS | New rootfs SHA-256 `1c8cb6e3...`; Docker-save SHA-256 `5ef18bde...`; compressed archive SHA-256 `bf47e58e...`; executable candidate image ID `a43c4441...`. Test `2164864404` passed source-independent import, internal Docker/image load, deep doctor, fresh preview/components, collection, stop, distro unregister, and storage cleanup from a spaces/Unicode path. | Browser qualification remains mandatory for a qualified release. |

## Executable candidate identity

- Runtime commit: `136944da9e8b0ee4f3c6727613d062abbd958857`.
- Image reference: `octane-lab:browser-appliance-v1-136944d`.
- Image ID: `sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a`.
- Base image ID: `sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c`.
- Candidate lock: `profiles/candidates/docker-wine-staging-11.21-visrgn-browser-appliance-136944d.candidate.lock.json`.
- Candidate lock SHA-256: `5227a24f4279a599679ff6adb00138776b93fd5205e8627ef11780b26acb4fff`.
- Installer: SHA-256 `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`, 219,839,154 bytes.
- Final executable run: `3ca7d5cbb6`; component checksum manifest SHA-256 `52747f5868cafeab3e2e24426974f6f60db20a829779750deb5141cf2b89eb86`; collection manifest SHA-256 `58369ee228bcca30203371cda3333ca431929f2e3f479b15a8b3827c930e6e81`.
- Historical operator handoff run `octane-c71f9b509b` remains deliberately retained; it is not the final executable candidate and must be rechecked before use.

## Implemented lifecycle and file result

- `open` defaults to `ReplaceActive`: immutable intake succeeds before the prior active run is collected or removed.
- `compare` is explicit and keeps an independently isolated run with separate viewer/upload ports.
- Every run gets a marker-journaled `/var/lib/octane/sessions/octane-<id>` tree, fresh Wine home/prefix/WebView2/application/output state, and exact cleanup.
- Selected input and installer mounts are read-only. Upload staging is writable only to the upload service and read-only in the target view. Collected output/evidence has a separate lifecycle.
- Wine `Z:` is available while NSIS executes, then removed before the installed target starts. The preserved `9500a6e5d0` failure proves why those phases must remain distinct.
- The live replacement pair used identical installer bytes; it validates lifecycle behavior, not application behavior across two builds.

## Refreshed local appliance artifacts

- Rootfs TAR: 503,298,560 bytes; SHA-256 `1c8cb6e36a880dcf491aaa12dc1d52c0819824902a2b272b36d3837c451e3368`.
- Docker-save TAR: 2,083,894,784 bytes; SHA-256 `5ef18bde39da0d3d56b48b416300034ef0f0a92355468e012ec21a8960039ebe`.
- Compressed image: 2,078,023,379 bytes; SHA-256 `bf47e58e50ef56396ee3e1d43fdecda5de0426ede6c37342609c01c154240b05`.
- Assembled package: 84 files, 2,583,977,275 bytes; manifest SHA-256 `c7793d91bddeb39857661aa0ff350a1303a7dca999aedbd92a9fa0479d0601c9`; top-level checksum manifest SHA-256 `78ca4892559cce8c2a6b5339602affd0fee9116140637e0514df0ec7fcf9b514`.
- Live package test `2164864404`, container `octane-3fd2c8f429`: all five lifecycle stages and final cleanup PASS. Result SHA-256 `8ad04f36734b35b2a22e7578791fd4cc81889fc7e35f457a9682a870b005073f`; browser-component checksum manifest SHA-256 `7f023762d400fed8b43e4bf9e3348718a8597782a81f62ccefd460016f73e288`.
- The unique test distro and state root are absent after cleanup; retained `octane-c71f9b509b` remains present. These are local candidate artifacts, not published binaries and not proof of browser acceptance.

## Release decision

The historical RDP qualification remains valid for its exact scope. The browser/appliance candidate is implemented and component-tested, including replacement and file-bridge behavior. Mandatory browser framebuffer/input acceptance and the ten-run browser batch are blocked, so this is **not a qualified browser release** and no new qualified tag/release replaces v0.1.1.
