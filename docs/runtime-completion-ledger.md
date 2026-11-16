# Browser runtime-kit completion ledger

Reconciled 2026-11-15. This is the single A-I release-gate ledger. `PASS` is limited to the recorded artifact, lock, environment, and evidence. Historical RDP acceptance and final browser acceptance remain independent.

| Gate | Status | Evidence and exact meaning | Remaining boundary |
| --- | --- | --- | --- |
| A. Historical baseline preserved and recoverable | PASS | Historical lock SHA-256 `0137c535...`, image ID `0443029e...`, batch `qbatch-e2aaafff4b38`, v0.1.1, evidence, retained private assets, and the WSLC backup were not rewritten or deleted. | None for preservation. |
| B. Browser-only desktop from Windows without RDP | PASS | Windows-browser smoke `deb9c3adfc` displayed and controlled the real Octane client through authenticated noVNC/TigerVNC. The final path had no XRDP/FreeRDP process or listener. | The smoke is separate from unattended qualification. |
| C. Unchanged external-installer intake and generic profiles | PASS | The retained installer bytes were staged, rehashed, installed, discovered, and launched unchanged. Versioned data-only profiles, overlay generation, and validation do not require target source or producer-pipeline changes. | Another target remains independently `UNTESTED`. |
| D. AI-assisted onboarding from one document and kit | PASS for the reference contract | `docs/OCTANE-AI-HANDOFF.md` is self-contained and records the source conversation, architecture, schemas, daily commands, boundaries, troubleshooting, and a generic AI prompt. The runtime kit excludes installer bytes, credentials, Git metadata, and provider dependencies. | External-app selectors and expectations require real one-time discovery. |
| E. Two-build replacement and approximately 400 MiB transport | PASS for lifecycle and transport | Live pair `750fc957af` to `603b83b9bf` proved validate-first, collect/exact-remove-old, reuse ports, fresh state, active-journal transfer, and cleanup. Synthetic 440,401,920-byte evidence proved interruption rejection, same-name/different-content identity, immutable reuse, and cleanup. | A second distinct executable installer was unavailable and is `NOT_TESTED`. |
| F. File and network capabilities | PASS for declared generic scopes | Selected Windows input is hashed/staged to WSL-native storage and mounted read-only; upload is authenticated, exact-origin, bounded, atomic, no-overwrite, and read-only to the target; outputs are separate and collected. Controlled endpoint classification passed only for its declared probe. | Corporate identity, Wine/WebView2 protocol, certificates, shares, and target-specific authentication remain separate capabilities. |
| G. New 10/10 browser-only Octane batch | PASS | Batch `browser-qbatch-06f2a54afe0c` passed every gate in all ten predeclared fresh runs under lock SHA-256 `db5babdf...`. Browser frames/input, normal initial rendering, workload, dialogs, export, integrity, no-RDP, evidence, and exact cleanup passed without repaint, relaunch, hidden retry, manual action, or override. | Result does not transfer to another installer. |
| H. Failure recovery, exact cleanup, integrity, and security tests | PASS | Current suites pass: 82 browser/runtime assertions, 48 harness assertions, 12 qualification-policy assertions, 30 appliance assertions, 16 upload protocol assertions, 19 Node tests, and 4 Rust core tests plus doc tests. All final batch resources were exactly cleaned; no global prune or WSL shutdown was used. | Raw sensitive evidence stays local/private. |
| I. Runtime kit, appliance/image recovery, shared commands, docs, and release integrity | PASS | The final 98-file package passed every declared hash, unique WSL import, exact image load, deep doctor, fresh unchanged-installer preview/components, collection, exact stop, distro unregister, and storage cleanup from an extracted path containing spaces and Unicode. Guide revision 12 is 48 visually inspected pages, SHA-256 `602f6f09...`. | Publication remains a hosting action, not a compatibility gate. |

## Qualified browser identity

- Harness commit: `ad1ba74644bdab49a17ccc40caf26f477d848a6a`.
- Image reference: `octane-lab:browser-xvnc-ad1ba74`.
- Image ID: `sha256:6e77b89e7d5f8d3f9472998bd33859413b6982038c9cc64054a9eb035b25e786`.
- Base image: `octane-lab:browser-appliance-v1-136944d`, ID `sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a`.
- Browser lock: `profiles/qualification/docker-wine-staging-11.21-visrgn-browser-xvnc.lock.json`.
- Lock SHA-256: `db5babdf10bb9c3aef12731c398a75437d280385799512e1b92838f028d68249`.
- Installer source commit: `7088eed9adb8403b9575afe1cc9e9c2984b29049`.
- Installer: 219,839,154 bytes; SHA-256 `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`.
- Batch: `browser-qbatch-06f2a54afe0c`.
- Batch summary SHA-256: `9254405b6f211314a25092f32ddaa5e369ad83d8ed9c841cf9e55502d02b15c0`.
- Batch checksum-manifest SHA-256: `37c5b7459ced5c393c990b43f295412e9f1d20fb5132718f7e08fe993d45dd07`.
- Windows-browser manual smoke: `deb9c3adfc`, separately classified and not counted in the unattended batch.

## Ten-run matrix

| Run | Scenario | Components | Report | Evidence | Cleanup |
| --- | --- | --- | --- | --- | --- |
| `513b6385f0` | PASS | PASS | PASS | PASS | PASS |
| `1bb8a0ec9f` | PASS | PASS | PASS | PASS | PASS |
| `23367b15c9` | PASS | PASS | PASS | PASS | PASS |
| `1c2750d422` | PASS | PASS | PASS | PASS | PASS |
| `5fd8ba417d` | PASS | PASS | PASS | PASS | PASS |
| `89019ca3ed` | PASS | PASS | PASS | PASS | PASS |
| `3f42f907d7` | PASS | PASS | PASS | PASS | PASS |
| `e103eef43d` | PASS | PASS | PASS | PASS | PASS |
| `f9f807aa18` | PASS | PASS | PASS | PASS | PASS |
| `a164c028eb` | PASS | PASS | PASS | PASS | PASS |

## Final appliance and transport evidence

- Package source commit: `363846859bdfae09cfccd2478dfc5f040eecd3e6`.
- Rootfs: 503,298,560 bytes; SHA-256 `cf0350437b0864e1709f23cafafa07dff95ff83267cfdd4d3b85ba985ca24158`.
- Docker-save archive: 2,085,883,904 bytes; SHA-256 `4cbe35848b9cae5df19ac288e898fe14ac1c9628ab461107ecf898cca9d92dd9`.
- Compressed image: 2,080,012,879 bytes; SHA-256 `30aa7f68fa63c11fa5f9d3df878e0ef4340a2bda1a545f37f53ce35933204801`.
- Assembled package: 98 files, 2,586,055,481 bytes.
- Package manifest SHA-256: `edd693df0eb398d20bc300e3937791f98c2febba62ffef911f437f09d417bec4`.
- Package checksum-manifest SHA-256: `57055ac31d8fe7449411f7989a67164452415921dd6570be16c59dfe82507192`.
- Extracted package test: `8739fdeafa`; all five lifecycle stages and cleanup PASS.
- Package-test result SHA-256: `242ead6a13e203bcb8e330dbd85cd04dbdeab26eebe849aaed85689f465898fc`.
- Package component-evidence checksum SHA-256: `86468f435448267f77f33f4ae0661c3475def5a832d1ad294caa2927f36a017b`.
- New 440,401,920-byte transport result SHA-256: `5f1d2aea8ac757a77fd065a6ae7afdd84ff2d28d232469be8ba57edc3d4224e`; checksum manifest `83729f191824e181f3ed12af7c30765950c775eb3281734b991174fbbe8b6075`.

## Boundaries retained

- The minimal native Win32 WebView2 probe remains white.
- The custom Wine visible-region patch remains a maintenance condition.
- Stock Wine and arbitrary Tauri applications are not qualified.
- A Linux Playwright/Chromium client drove the unattended batch; the Windows in-app-browser smoke is recorded separately.
- The synthetic 420 MiB-plus transport fixture is not a second real installer or application pass.
- Windows identity, domain authentication, certificates, mapped shares, device compliance, and proprietary target behavior are not inferred.

## Release decision

Historical Docker/Wine/RDP qualification is preserved for its original scope. Browser-only Octane acceptance is qualified for the exact final lock. All mandatory A-I product gates pass for the declared reference scope. Another application remains untested until its own unchanged installer, profile, scenario, and evidence are measured.
