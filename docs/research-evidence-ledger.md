# WebView2/Wine evidence ledger

Last reconciled: 2026-11-14 UTC. This ledger separates statements made by application reporters from primary documentation, reviewed source, and Octane's own measurements. `Local outcome` never upgrades a community screenshot or an installation result into Octane acceptance.

Confidence means confidence that the source says what is summarized, not confidence that the same result applies to Octane.

## OLE and drag/drop

### R01 — Wine bug 60225 cross-process `IDropTarget_Release`

- **Claim:** A Tauri/WebView2 host crashed when its process called `RevokeDragDrop` on a window whose raw `OleDropTargetInterface` pointer had been registered by a different process.
- **Classification:** Upstream community reporter; not a Wine maintainer finding or Microsoft statement.
- **Source / author / date:** [Wine bug 60225 mailing-list comment](https://list.winehq.org/hyperkitty/list/wine-bugs@list.winehq.org/message/XD2YRCEPBVISXCXVRK7ZUKUOQO6COAWV/), germanshtyrov, 2026-08-23.
- **Version / platform:** Wine 11.0; reporter's Tauri/WebView2 application. Display backend was not established in the retained comment.
- **Reported outcome:** `WINEDEBUG=+ole` showed WebView2 registering and the host revoking the same HWND from different processes. An ownership check prevented that reporter's crash; the reporter also noted a possible reference leak.
- **Reproduction:** Capture `+ole`, process IDs, HWND, pointer, and exception stack through register/revoke/close.
- **Local outcome:** The historical Octane baseline had a matching `IDropTarget_Release` signature, but the later matched Wine 11.0 control/MR pair did not reproduce that crash. The 2026-11-14 Wine-Staging 11.21 control/candidate runs also showed no `IDropTarget_Release` crash; a focused `+ole` trace recorded `RegisterDragDrop` without the reported revoke/crash sequence before close. Equivalence is therefore **not established**, and the current blocker is presentation/dialog repeatability rather than the historical exception.
- **Confidence:** High for the reporter's trace; low for generalization to all Tauri applications or to Octane's current blank-window failure.

### R02 — `G6rm0k/wine-ole32-fix`

- **Claim:** Release the raw pointer only when the current process owns the window, while retaining the rest of `RevokeDragDrop` cleanup.
- **Classification:** Community proof of concept.
- **Source / author / date:** [`G6rm0k/wine-ole32-fix`](https://github.com/G6rm0k/wine-ole32-fix), G6rm0k, commit `c1dfd5bc4af310a955d636fe26b9c9f1369419cf`, 2026-08-23.
- **Version / platform:** Wine tag `wine-11.0`; platform/display not demonstrated by the repository.
- **Reported outcome:** The README says **Verified: Not yet**. It does not replace all of `RevokeDragDrop` with `S_OK`; it adds an ownership check before releasing the raw pointer.
- **Reproduction:** Apply the source transformation to the exact Wine 11.0 tree and build matched control/candidate artifacts.
- **Local outcome:** Reviewed, not adopted. The more complete upstream MR candidate had already been tested in a matched pair and did not restore rendering.
- **Confidence:** High for repository content; no confidence claim for Octane compatibility.

### R03 — Wine MR !12477

- **Claim:** Revoke foreign drop targets in the apartment that registered them rather than dereferencing a foreign-process raw pointer.
- **Classification:** Upstream Wine source proposal; review/merge state unverified because the GitLab review page/API was access-blocked.
- **Source / author / date:** [Wine MR !12477](https://gitlab.winehq.org/wine/wine/-/merge_requests/12477), Jason A. Donenfeld, head `22a16b053991f95e8bbf91e4784e73f833835b72`, 2026-10-29.
- **Version / platform:** Proposal against Wine source; it adds a private `IWineDropTarget` COM path and apartment-side cleanup.
- **Reported outcome:** Source describes compatibility with Windows behavior for an out-of-process WebView2 drop target. The commit is absent from the inspected Wine 11.0, Wine 11.21, and then-current Wine master snapshots.
- **Reproduction:** Build unpatched and MR-head variants from the same source/toolchain, then compare OLE traces and rendering.
- **Local outcome:** Historical matched Wine 11.0 control and MR-head runs both avoided the older host crash and both failed visible WebView2 rendering. The MR did not repair Octane rendering in that pair.
- **Confidence:** High for inspected patch content and local pair; unknown for upstream review/merge status.

## Rendering, composition, and windowing

### R04 — WebView2Feedback issue 5720

- **Claim:** On the reporter's macOS/CrossOver path, WebView2 generated one initial animation frame and then stopped presenting; GL selection and the WARP/DirectComposition path were separate obstacles. A follow-up reported several WebView2 applications rendering through Wine's X11 driver on Linux.
- **Classification:** Community issue and follow-up reports; no Microsoft maintainer conclusion was present when inspected.
- **Source / author / date:** [MicrosoftEdge/WebView2Feedback #5720](https://github.com/MicrosoftEdge/WebView2Feedback/issues/5720), opened by `andyhsu6` on 2026-09-18; full thread inspected through 2026-11-14.
- **Version / platform:** Reporter used WebView2 153 and fixed 149 on macOS/CrossOver; follow-up described Linux/Wine X11. This is not a universal Linux result.
- **Reported outcome:** The thread corrects “zero frames” to one frame; `--use-angle=swiftshader` alone was stale/insufficient; disabling DirectComposition did not establish a working path. A CDP/DOM result can diverge from native-window pixels.
- **Reproduction:** Record requested and effective child arguments, ANGLE backend, rAF and timer progress, actual client-area pixels, and display driver.
- **Local outcome:** Locally reproduced on Linux `winex11`. Baseline Wine 11.0 reached rAF 13 and 23 interval callbacks; the Wine-Staging 11.21 control reached rAF 0 and 112 interval callbacks; the visible-region candidate reached rAF 0 and 114 interval callbacks. All three had a zero client-area pixel delta and a visually solid-white WebView client. The installed Octane UI nevertheless sometimes rendered after three resize/minimize/restore cycles, so the minimal host and Tauri host are not interchangeable evidence.
- **Confidence:** High for thread content; medium for its diagnostic analogy; low for direct applicability across macOS, Wayland, and Linux X11.

### R05 — Wine bugs 35456 and 60263

- **Claim:** Cross-process child-window presentation has failed in Wine's macOS-specific paths.
- **Classification:** Upstream community bug reports, unconfirmed when inspected.
- **Source / author / date:** [Wine bug 35456](https://bugs.winehq.org/show_bug.cgi?id=35456) and [Wine bug 60263](https://bugs.winehq.org/show_bug.cgi?id=60263); reporter-authored records, accessed 2026-11-14. Exact reporter/date metadata could not be independently recovered through the Bugzilla challenge page.
- **Version / platform:** macOS `winemac`; bug 60263 discusses a cross-process Metal swapchain.
- **Reported outcome:** Relevant to presentation architecture, not evidence that Linux X11 has the same defect.
- **Reproduction:** Only compare after confirming `winemac` or the precise shared-window path involved.
- **Local outcome:** Not reproduced; Octane's measured Docker path is Linux `winex11`.
- **Confidence:** Medium for conceptual relevance; low for Octane causality.

### R06 — Wine bug 59370

- **Claim:** A Linux/Wine WebView2 109 blank-window case was traced by its reporter toward D3D11/shared-texture behavior.
- **Classification:** Upstream community reporter; unconfirmed when inspected.
- **Source / author / date:** [Wine bug 59370](https://bugs.winehq.org/show_bug.cgi?id=59370), reporter `stan`, Wine 11.1/Linux; accessed 2026-11-14. Exact creation timestamp could not be independently recovered through the Bugzilla challenge page.
- **Version / platform:** Wine 11.1, Linux; WebView2 109.
- **Reported outcome:** Detailed reporter analysis, not a Wine maintainer root-cause finding and not evidence that a GPU restart necessarily means hardware-GPU failure.
- **Reproduction:** Match runtime and Wine versions, then capture the precise D3D/shared-resource call and error before changing flags.
- **Local outcome:** Not yet reproduced at the failing API level. Octane used WebView2 157, so the version delta is material.
- **Confidence:** Medium for a useful lead; low for direct causality.

### R07 — Wine bugs 58921/58922 Windows-version workaround

- **Claim:** A Linux reporter said WebView2 applications rendered under Wine 10.18 when `msedgewebview2.exe` was configured as Windows 7/8, avoiding the Windows 8.1+ DirectComposition path.
- **Classification:** Upstream community report; not a maintained WebView2 compatibility guarantee.
- **Source / author / date:** [Wine bug archive](https://list.winehq.org/hyperkitty/list/wine-bugs@list.winehq.org/), bugs 58921 and 58922, reporter-authored in 2025/2026; inspected 2026-11-14.
- **Version / platform:** Wine 10.18, Linux/X11; application/runtime versions differ from Octane's retained artifact.
- **Reported outcome:** Per-executable Windows-version selection was reported to alter the rendering path.
- **Reproduction:** In a fresh prefix, change only the AppDefaults Windows version for `msedgewebview2.exe`, preserve all artifacts, and capture the effective setting and child command lines.
- **Local outcome:** Not yet run. It is the smallest remaining Linux/X11-specific experiment if the pinned Wine pair still fails.
- **Confidence:** Medium as a bounded hypothesis; low as a general fix.

## Community implementations

### R08 — `solid-edge-wine-fixes`

- **Claim:** Solid Edge 2026's WebView2 start page rendered in a headless Ubuntu container using Wine-Staging 11.21, Xvfb/Openbox, and Mesa llvmpipe; a `win32u` visible-region patch addressed a later stale cross-process WebView image.
- **Classification:** Community application-specific implementation and screenshots.
- **Source / author / date:** [`JustNotesa/solid-edge-wine-fixes`](https://github.com/JustNotesa/solid-edge-wine-fixes), Gedanke, commit `d3fd3268536ed43c7e5c616bc1c98eec07a9d154`, 2026-11-01.
- **Version / platform:** Ubuntu 24.04, Wine-Staging 11.21, Xvfb/Openbox, llvmpipe, no GPU; fixed WebView2 156.0.4314.58.
- **Reported outcome:** Start page and new-part creation were checked; modeling was not. The recipe combines runtime selection, registry/policy arguments including `--no-sandbox`, and application-specific D2D/SVG and repaint changes.
- **Reproduction:** The Octane candidate copies only canonical blob `6702247b808414f396c40da6b0d11434dccf3de1` (SHA-256 `f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752`) onto the exact Wine/Staging pair. It does not import the D2D patch, Solid Edge registry keys, or sandbox bypass.
- **Local outcome:** Patch review, matched source/control compilation, and Docker/Wine execution completed. The candidate did not make the minimal native WebView2 probe render. The installed Octane UI and real 8-file workload became visible in 3/3 fresh candidate runs only after three resize/minimize/restore cycles, but the complete dialog/export contract passed only 1/3. The patch is therefore a conditional application-specific lead, not a general WebView2 fix or a repeatable Octane acceptance result.
- **Confidence:** High for repository content and patch provenance; medium-low for relevance to Octane startup rendering.

### R09 — `wuwa-tappo-wine`

- **Claim:** A Tauri 2/WebView2 pet rendered using a prefix-local blanket `RevokeDragDrop` no-op, repeated `SetWindowPos` nudges, fixed runtime, and Proton/container flags.
- **Classification:** Community application-specific implementation.
- **Source / author / date:** [`khoipm06/wuwa-tappo-wine`](https://github.com/khoipm06/wuwa-tappo-wine), Khoi Pham Minh, commit `2b3abec18e5f00e4a0c6a02b9d13fd289169bec8`, 2026-11-02.
- **Version / platform:** Tested against a named DW-Proton setup and Steam/Flatpak containment, not the Octane Docker/Wine stack.
- **Reported outcome:** Repository says the pet renders and animates; it uses exact binary patches and a timed window-nudge sidecar.
- **Reproduction:** Review verified-byte patching and sidecar behavior in an isolated prefix before considering a bounded diagnostic.
- **Local outcome:** Reviewed only. Proton/Steam are out of scope; a blanket `RevokeDragDrop` no-op and repaint helper were not adopted as defaults.
- **Confidence:** High for repository content; low for transferability to normal Octane repaint behavior.

### R10 — Adventure Land Proton discussion

- **Claim:** Adventure Land documents a Proton path as experimental/unsupported.
- **Classification:** Project documentation/community compatibility report.
- **Source / author / date:** [Adventure Land Steam Deck/Linux page](https://adventure.land/steamdeck), project documentation accessed 2026-11-14.
- **Version / platform:** Proton/Linux, not the pinned Docker/Wine implementation.
- **Reported outcome:** It neither proves universal WebView2 failure nor a complete Octane-like acceptance pass.
- **Reproduction:** None adopted; Proton is explicitly out of scope.
- **Local outcome:** Research context only.
- **Confidence:** High for the narrow project statement; none for Octane compatibility.

## Primary documentation and local controls

### R11 — Evergreen versus Fixed Version WebView2

- **Claim:** Evergreen installation and a Fixed Version directory are distinct distribution models; extracting a fixed archive does not by itself make an application select it.
- **Classification:** Primary Microsoft documentation.
- **Source / author / date:** [WebView2 distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution) and [Evergreen versus Fixed Version](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/evergreen-vs-fixed-version), Microsoft, accessed 2026-11-14.
- **Version / platform:** WebView2 SDK/runtime; platform-independent distribution guidance.
- **Reported outcome:** The host must pass/select the intended browser executable folder for a Fixed Version comparison and record the actual loaded path/version.
- **Reproduction:** Use a separately hashed runtime archive and explicit `CreateCoreWebView2EnvironmentWithOptions` browser folder; capture child paths and loaded version.
- **Local outcome:** Diagnostic support is implemented. No Fixed Version runtime result is claimed yet.
- **Confidence:** High.

### R12 — Official native Win32 sample and process events

- **Claim:** A minimal Win32 WebView2 host requires STA COM initialization, an active message loop, ordered asynchronous environment/controller creation, and event registration after the relevant interfaces exist.
- **Classification:** Primary Microsoft documentation/sample.
- **Source / author / date:** [Win32 getting started](https://learn.microsoft.com/en-us/microsoft-edge/webview2/get-started/win32), [process-related events](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-related-events), and [`MicrosoftEdge/WebView2Samples`](https://github.com/MicrosoftEdge/WebView2Samples) commit `06d49d546ba5dc0e2773798ee5b982f68275af4c`, Microsoft, sample commit 2026-11-05.
- **Version / platform:** Native Windows x64, SDK 1.0.3856.49 in Octane's probe.
- **Reported outcome:** `ProcessFailed`, `BrowserProcessExited`, runtime version, and failure-report paths are diagnostic signals; none alone proves visible presentation.
- **Reproduction:** Build with the provider-neutral script and run the hashed executable in a fresh Wine prefix/user-data directory.
- **Local outcome:** The enhanced x64 probe built from source commit `0228527` with SDK 1.0.3856.49; executable SHA-256 `82cd1cab4930ffeb940a27898fabdb30322decd84f681ef3d15264c51e86f5b5`. It ran in fresh baseline, Staging-control, and visible-region-candidate prefixes. Environment/controller creation, local navigation, DOM messages, input events, and timers succeeded, while reviewed native client pixels stayed white. `ProcessFailed` was observed; the probe result is FAIL for visible presentation.
- **Confidence:** High for API use; runtime behavior under Wine remains experimental.

### R13 — Octane historical matched OLE experiment

- **Claim:** The upstream OLE proposal alone did not resolve Octane's rendering failure.
- **Classification:** Locally reproduced historical experiment.
- **Source / author / date:** Repository evidence and `docs/validation.json`, Octane lab, measured 2026-11-13/14.
- **Version / platform:** Wine 11.0 control versus MR `22a16b...`; identical WineGUI digest, installer SHA-256 `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`, WebView2 157.0.4341.60, fresh prefixes.
- **Reported outcome:** Both variants registered/revoked drop targets, exited without the old host crash, and failed visible rendering identically.
- **Reproduction:** Use the retained profiles and evidence procedure; do not relabel the installer as a current implementation artifact.
- **Local outcome:** FAIL for visible rendering; workload/dialog/export BLOCKED.
- **Confidence:** High within the measured pair.

### R14 — Pinned Wine/Staging source pair

- **Claim:** Wine 11.21 and Wine-Staging 11.21 are real, matching releases suitable for a controlled source build.
- **Classification:** Primary upstream source plus locally reproduced build.
- **Source / author / date:** Wine commit `2528aff26208257fdbf980666a4f0e66d47563ce` (Alexandre Julliard, 2026-10-30) and Wine-Staging commit `04414fee61f7d283072d40905816b928875b2d4b` (Alistair Leslie-Hughes, 2026-10-31).
- **Version / platform:** Ubuntu 24.04 builder; unified i386/x86_64 source build; target Docker-Wine Ubuntu 24.04/X11 environment.
- **Reported outcome:** Staging's `upstream-commit` exactly matches the Wine release commit. The recipe records ordered staging patch hashes and the optional candidate patch hash.
- **Reproduction:** Build `lab/Dockerfile.wine-staging-11.21` with one named `WINE_VARIANT`; required commits and patch checksums are hard failures.
- **Local outcome:** Source fetch, complete Staging application, shared control compilation, installation, and GUI execution completed on 2026-11-14. One fresh control run completed every application gate after a repaint nudge; the next remained black after the same bounded procedure. The visible-region candidate rendered Octane/workload in three fresh runs but completed every dialog/export gate in only one. Both profiles are non-repeatable, and neither qualifies as a maintained default.
- **Confidence:** High for provenance/build and the measured local runs; no claim beyond the tested profiles.

### R15 — Local Wine 11.21 application comparison

- **Claim:** The unchanged installed Octane artifact can present its real Tauri/WebView2 client and invoke the Rust backend under a pinned Docker/Wine-Staging 11.21 environment, but the measured behavior is not yet repeatable enough for acceptance.
- **Classification:** Locally reproduced experiment, not an upstream compatibility guarantee.
- **Source / author / date:** Octane run journals and evidence bundles for `17e5fdec70`, `615d1bca1e`, `d2cc660dbe`, `c5c34187fa`, and `aef06bc9fa`; Octane lab; 2026-11-14.
- **Version / platform:** Windows 11 build 26200.8875; WSL 3.0.1.0; Ubuntu-24.04 WSL2; kernel 6.18.40.1; Docker 29.6.2; Docker-Wine RDP/Xorgxrdp; `winex11`; Wine `2528aff...`; Staging `04414f...`; Evergreen WebView2 157.0.4341.60.
- **Reported outcome:** Not applicable; this entry records local measurements.
- **Reproduction:** Use the retained installer hash, a fresh container/prefix, one explicit profile, localhost RDP, `octane-lab install-silent`, then `Invoke-OctaneApplicationExperiment.ps1`; visually review native screenshots before running the reviewer and collector.
- **Local outcome:** The unpatched Staging control passed one full clean scenario and failed the next at visible presentation. The visible-region candidate required three window-state repaint cycles in every fresh run; real UI/workload passed 3/3, but native-dialog plus no-overwrite acceptance passed 1/3. A reused-prefix debug run proved the improved synchronizer could repeat the overwrite-decline path, while Choose Files returned `Selection canceled` without a visible picker. That debug run is not clean acceptance.
- **Confidence:** High for the recorded runs and artifact/profile identities; low for extrapolation beyond these versions or for production reliability.
