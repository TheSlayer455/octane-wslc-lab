# Browser runtime-kit completion ledger

Reconciled 2026-11-15. This is the single A-I release-gate ledger. `PASS` is limited to the recorded artifact, lock, environment, and evidence. Historical RDP acceptance and final browser acceptance remain independent.

| Gate | Status | Evidence and exact meaning | Remaining boundary |
| --- | --- | --- | --- |
| A. Historical baseline preserved and recoverable | PASS | Historical lock SHA-256 `0137c535...`, image ID `0443029e...`, batch `qbatch-e2aaafff4b38`, v0.1.1, evidence, retained private assets, and the WSLC backup were not rewritten or deleted. | None for preservation. |
| B. Browser-only desktop from Windows without RDP | PASS | Windows-browser smoke `deb9c3adfc` displayed and controlled the real Octane client through authenticated noVNC/TigerVNC. The final path had no XRDP/FreeRDP process or listener. | The smoke is separate from unattended qualification. |
| C. Unchanged external-installer intake and generic profiles | PASS | The retained installer bytes were staged, rehashed, installed, discovered, and launched unchanged. Versioned data-only profiles, overlay generation, and validation do not require target source or producer-pipeline changes. A public independent target was then measured from two unchanged installers: 2.1.1 scenario PASS and 2.2.0 application FAIL. | The independent target is not qualified; no arbitrary target inherits the reference result. |
| D. AI-assisted onboarding from one document and kit | PASS for the reference contract | `docs/OCTANE-AI-HANDOFF.md` is self-contained and records the source conversation, architecture, schemas, daily commands, boundaries, troubleshooting, and a generic AI prompt. Its generated PDF is repository-tracked and both formats are included by runtime-kit and appliance-release builders. The kit excludes installer bytes, credentials, Git metadata, and provider dependencies. | External-app selectors and expectations require real one-time discovery. |
| E. Two-build replacement and approximately 400 MiB transport | PASS for lifecycle and transport | Live reference pair `750fc957af` to `603b83b9bf` proved validate-first replacement. Independent runs `21762b3de1` to `75b30d12b0` then proved two distinct real installer identities, collect/exact-remove-old, retained output/evidence, fresh state, and cleanup; the second application build correctly remained FAIL. Synthetic 440,401,920-byte evidence separately proved interruption rejection, same-name/different-content identity, immutable reuse, and cleanup. | Two-build routing is PASS, but the independent target's 2.2.0 application acceptance is FAIL. |
| F. File and network capabilities | PASS for declared generic scopes | Selected Windows input is hashed/staged to WSL-native storage and mounted read-only; upload is authenticated, exact-origin, bounded, atomic, no-overwrite, and read-only to the target; outputs are separate and collected. Controlled endpoint classification passed only for its declared probe. | Corporate identity, Wine/WebView2 protocol, certificates, shares, and target-specific authentication remain separate capabilities. |
| G. New 10/10 browser-only Octane batch | PASS | Batch `browser-qbatch-06f2a54afe0c` passed every gate in all ten predeclared fresh runs under lock SHA-256 `db5babdf...`. Browser frames/input, normal initial rendering, workload, dialogs, export, integrity, no-RDP, evidence, and exact cleanup passed without repaint, relaunch, hidden retry, manual action, or override. | Result does not transfer to another installer. |
| H. Failure recovery, exact cleanup, integrity, and security tests | PASS | Current suites pass: 83 browser/runtime assertions, 48 harness assertions, 12 qualification-policy assertions, 32 appliance assertions, 17 upload protocol assertions, 19 Node tests, and 4 Rust core tests plus doc tests. All final batch and onboarding resources were exactly cleaned; no global prune or WSL shutdown was used. | Raw sensitive evidence stays local/private. |
| I. Runtime kit, appliance/image recovery, shared commands, docs, and release integrity | PASS | The final 98-file package passed every declared hash, unique WSL import, exact image load, deep doctor, fresh unchanged-installer preview/components, collection, exact stop, distro unregister, and storage cleanup from an extracted path containing spaces and Unicode. Guide revision 13 is 48 visually inspected pages, SHA-256 `b19db848...`; the canonical 16-page AI handoff PDF is generated from its Markdown source, visually inspected, and has SHA-256 `108b0e3b...`; the v1.0.0 release's revision-12 PDF remains immutable. | Publication remains a hosting action, not a compatibility gate. |

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

- Runtime-kit commit: `aced057ba3d3979a343247373e68aa7b6cb3a657`; rootfs source commit: `363846859bdfae09cfccd2478dfc5f040eecd3e6`.
- Rootfs: 503,298,560 bytes; SHA-256 `cf0350437b0864e1709f23cafafa07dff95ff83267cfdd4d3b85ba985ca24158`.
- Docker-save archive: 2,085,883,904 bytes; SHA-256 `4cbe35848b9cae5df19ac288e898fe14ac1c9628ab461107ecf898cca9d92dd9`.
- Compressed image: 2,080,012,879 bytes; SHA-256 `30aa7f68fa63c11fa5f9d3df878e0ef4340a2bda1a545f37f53ce35933204801`.
- Assembled package: 98 files, 2,586,061,421 bytes.
- Package manifest SHA-256: `02176b061918de85de755982ed085c41ee4c9d966d934d885a4492020d3fcbeb`.
- Package checksum-manifest SHA-256: `d8e38f1f57a4bba3fd629de7e645734226fc7f169815273d75f4c6364533de4c`.
- Runtime-kit checksum-manifest SHA-256: `04723002945c4e0d13356c930fc8d7f6e7346177ee97bf91c8525171ed07eca6`.
- Extracted package test: `87945a4f09`; all five lifecycle stages and cleanup PASS.
- Package-test result SHA-256: `2a662c0c35367e324cd25d48f3bef0f7903bc17c9a14b54099afcf1aedfa8886`.
- Package component-evidence checksum SHA-256: `e5063a03db168057e9169b365488e82c5595de195fa67141053c60aa136c9829`.
- New 440,401,920-byte transport result SHA-256: `5f1d2aea8ac757a77fd065a6ae7afdd84ff2d28d232469be8ba57edc3d4224e`; checksum manifest `83729f191824e181f3ed12af7c30765950c775eb3281734b991174fbbe8b6075`.
- Public v1.0.0 release: `https://github.com/TheSlayer455/octane-wslc-lab/releases/tag/v1.0.0`; release ID `446512455`; published 2026-11-16T01:36:28Z.
- GitHub reported all five assets `uploaded` and returned matching server-side SHA-256 digests for the runtime ZIP, guide, release manifest, rootfs, and image archive.

## Independent application onboarding evidence

- Data-only profile: `profiles/applications/jsonprism-2x.app.json`; published profile SHA-256 `f3a4ab93d006513134bc003663d0d5828852e5b56821fe588fc43634bcf39917`.
- 2.1.1 run `21762b3de1`: browser/application/workload/native dialogs/export/input integrity/cleanup PASS; evidence checksum-manifest SHA-256 `48b7e94888d8fab1e7354015250bd298cae8c99ed1cca82522ff9a0a0a391f38`.
- Replacement: new installer verified before prior collection/removal; `replacementCollected=true` and `replacementRemoved=true`; prior CSV/evidence retained.
- 2.2.0 run `75b30d12b0`: fresh install and viewer connection PASS; application FAIL with captured page-fault stack beginning `IDropTarget_Release` -> `RevokeDragDrop`; workload/dialog/export BLOCKED; input integrity and cleanup PASS; evidence checksum-manifest SHA-256 `53c088a7be9eb698fe0fa82fa71f24f502323ab4d6436011defcb22d3a777253`.
- Sanitized record: `docs/external-application-two-build-result.json`. Raw evidence/output stays local/private and outside ordinary Git history.

## Boundaries retained

- The minimal native Win32 WebView2 probe remains white.
- The custom Wine visible-region patch remains a maintenance condition.
- Stock Wine and arbitrary Tauri applications are not qualified. The independent target's 2.1.1 scenario passed, but its 2.2.0 build crashed before usable readiness.
- A Linux Playwright/Chromium client drove the unattended batch; the Windows in-app-browser smoke is recorded separately.
- The synthetic 420 MiB-plus transport fixture remains only a capacity/integrity test. Two distinct small real installers were subsequently routed; only the first completed its application scenario.
- Windows identity, domain authentication, certificates, mapped shares, device compliance, and proprietary target behavior are not inferred.

## Release decision

Historical Docker/Wine/RDP qualification is preserved for its original scope. Browser-only Octane acceptance is qualified for the exact final lock. All mandatory A-I product gates pass for the declared reference scope, the repository is public, and v1.0.0 is published without replacing v0.1.1. A separate public application has now been measured: 2.1.1 is scenario-tested PASS, clean replacement is PASS, and 2.2.0 has an application compatibility FAIL. That external target is not qualified and does not alter Octane v1's lock.
