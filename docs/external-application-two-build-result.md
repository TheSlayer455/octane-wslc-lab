# Independent application two-build result

Recorded 2026-11-16. This is a post-v1 application-onboarding result. It does not change or inherit the Octane reference application's 10/10 qualification.

## Target and scenario

The independently developed target was the public Apache-2.0 [JSONPrism](https://github.com/poli0981/jsonPrism) Tauri 2 application. Octane consumed two unchanged release installers as black-box inputs; it did not need target source at runtime, modify either installer, or change the producer pipeline.

The checked-in profile is `profiles/applications/jsonprism-2x.app.json` (SHA-256 `f3a4ab93d006513134bc003663d0d5828852e5b56821fe588fc43634bcf39917`). It records a verified x64 NSIS `/S` installation, `per-machine` scope, lowercase installed executable identity, the measured title, Evergreen WebView2 requirement, and the existing copy-based file bridge. The measured external overlay used the same operational values under generic id `example-app`, SHA-256 `64e467fedacf641071550b8cb9e0a98e033dde6c486e8a572274aa50ad68d24d`. Installer bytes remain outside Git.

The browser scenario used a synthetic JSON file named `people space ü.json`, selected it through the application's native open dialog, converted the three records to CSV, saved through the native save dialog, canceled and reopened the dialog, independently checked the CSV, and verified that the input hashes did not change. The first attempt to type the non-ASCII filename through synthetic noVNC key events omitted `ü`; list selection of the exact visible filename succeeded. This is an input-method boundary, not a claim that arbitrary synthesized Unicode typing is qualified.

## Results

| Build | Unchanged installer identity | Browser/UI | Ingestion and export | Cleanup | Result |
| --- | --- | --- | --- | --- | --- |
| 2.1.1 | 2,258,891 bytes; SHA-256 `40fcf6be703b3a68e7e1792b19f39b176cefd96d6ad44794a56a43e302cc55cb`; source tag commit `14f593c7a717526892fbda660a297a93b6be62b1` | Authenticated noVNC connected; the real client rendered; browser pointer/keyboard input reached the app | Native open/save/cancel/reopen PASS; selected the exact space/Unicode input; three records converted; 80-byte CSV SHA-256 `ae0383b0d1bbba926a2e8f2b9cc98b0035bdb13c92db883f3a9cbd9d96e899de`; input integrity PASS | PASS | `SCENARIO_TESTED` / PASS for this exact run |
| 2.2.0 | 2,261,487 bytes; SHA-256 `5fcb5abd7ea12b85b4ac670823cc86022063d296611c13e92367b5a570679ed4`; source tag commit `29d417ec93b8f9c34f826f2ff2b13581c4cd30a1` | Viewer connected and displayed the failure; installed client stayed white, then Wine's Program Error UI appeared | Workload, application dialogs, and application export BLOCKED | PASS | Application FAIL before usable readiness |

The 2.2.0 crash report records an unhandled read page fault whose first captured frames are `IDropTarget_Release` and `RevokeDragDrop`. That is the observed signature only. This result does not establish equivalence with Wine bug 60225 or prove a root cause.

## Replacement and state boundary

`ReplaceActive` staged and hashed the 2.2.0 installer before changing the active run. It then collected 2.1.1 output/evidence, removed only container `octane-21762b3de1` and its WSL-native disposable session storage, and created fresh run `octane-75b30d12b0`. The second run recorded `replacementCollected=true` and `replacementRemoved=true`; its container, prefix, installation, WebView2 data, and output directory were new. The first CSV and evidence remained intact.

This proves that Octane's two-build routing and state-replacement workflow can expose a real build-specific compatibility regression without silently reusing the prior installed build. It does not make the independent application qualified: 2.1.1 is scenario-tested, while 2.2.0 failed.

## Evidence and integrity

Raw evidence is local/private and intentionally excluded from normal Git history. The machine-readable sanitized record is `docs/external-application-two-build-result.json`.

| Run | Evidence bundle | Checksum-manifest SHA-256 | Output checksum-manifest SHA-256 |
| --- | --- | --- | --- |
| Discovery `5d82e6efeb` | `evidence/octane-5d82e6efeb-20261116-023156` | `8b1b63bd622b9a57d4d60acfe8ec23f6e0ba3a00a06454960fdae2a99b8bbdd1` | Preserved; no app output expected |
| 2.1.1 `21762b3de1` | `evidence/octane-21762b3de1-20261116-024009` | `48b7e94888d8fab1e7354015250bd298cae8c99ed1cca82522ff9a0a0a391f38` | `0a2da93dfa4aac258b45cb95ea394e001a7bc893e6b6f1e4273122328fd59c4d` |
| 2.2.0 `75b30d12b0` | `evidence/octane-75b30d12b0-20261116-024952` | `53c088a7be9eb698fe0fa82fa71f24f502323ab4d6436011defcb22d3a777253` | `a79c33db7c0af2f9ed6a43ed4fe454a7633a00b51161a46283152bc896ec21c1` |

The 2.2.0 diagnostic output contains a 13,294-byte crash report (SHA-256 `70a6628afcc43625e809fc1a99b42dd9fa6605eeddd381be967d5ca7207dad32`) and a captured desktop image (SHA-256 `4454eadf6b2cb86a0a8a82d2ea770c3ba5ffebfae8c932ed5792e1d41ca9f56b`). All three exact containers and disposable session-storage roots were removed. No global Docker prune, WSL shutdown, RDP fallback, repaint helper, application relaunch loop, or manual PASS override was used.

## Verdict

- Octane reference qualification: unchanged and still qualified for its exact lock.
- Reusable product usefulness beyond the reference app: demonstrated for intake, browser interaction, file ingestion/export, evidence, and clean replacement.
- Independent application build 2.1.1: `SCENARIO_TESTED` PASS for the exact installer/profile/run.
- Independent application build 2.2.0: application compatibility FAIL; later gates BLOCKED.
- Independent application qualification: NOT QUALIFIED.

The smallest next compatibility experiment is an attributable same-artifact control/candidate comparison for 2.2.0 against a narrowly reviewed OLE fix, with fresh prefixes and the working 2.1.1 run retained as a behavioral control. It must not modify the v1 qualified image or rewrite this failure.
