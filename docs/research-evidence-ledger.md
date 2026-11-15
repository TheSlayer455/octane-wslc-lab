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
- **Local outcome:** The historical Octane baseline had a matching `IDropTarget_Release` signature, but the later matched Wine 11.0 control/MR pair did not reproduce that crash. The 2026-11-14 Wine-Staging 11.21 control/candidate runs also showed no `IDropTarget_Release` crash; a focused `+ole` trace recorded `RegisterDragDrop` without the reported revoke/crash sequence before close. Equivalence is therefore **not established**. The final locked candidate later completed 10/10 Octane runs without this exception, but that does not identify the historical crash's cause.
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
- **Local outcome:** Locally reproduced on Linux `winex11`. Baseline Wine 11.0 reached rAF 13 and 23 interval callbacks; the Wine-Staging 11.21 control reached rAF 0 and 112 interval callbacks; the visible-region candidate reached rAF 0 and 114 interval callbacks. All three had a zero client-area pixel delta and a visually solid-white WebView client. The installed Octane host later presented normally without a repaint helper in a dedicated observer and ten locked runs, while the minimal host remained white. The hosts are therefore not interchangeable evidence, and the final Octane result is not a general WebView2 fix.
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
- **Local outcome:** Not run. The exact pinned candidate qualified Octane without changing the per-executable Windows version, so this workaround is no longer required for the declared contract. It remains an unverified historical lead rather than a promoted setting.
- **Confidence:** Medium as a bounded hypothesis; low as a general fix.

## Community implementations

### R08 — `solid-edge-wine-fixes`

- **Claim:** Solid Edge 2026's WebView2 start page rendered in a headless Ubuntu container using Wine-Staging 11.21, Xvfb/Openbox, and Mesa llvmpipe; a `win32u` visible-region patch addressed a later stale cross-process WebView image.
- **Classification:** Community application-specific implementation and screenshots.
- **Source / author / date:** [`JustNotesa/solid-edge-wine-fixes`](https://github.com/JustNotesa/solid-edge-wine-fixes), Gedanke, commit `d3fd3268536ed43c7e5c616bc1c98eec07a9d154`, 2026-11-01.
- **Version / platform:** Ubuntu 24.04, Wine-Staging 11.21, Xvfb/Openbox, llvmpipe, no GPU; fixed WebView2 156.0.4314.58.
- **Reported outcome:** Start page and new-part creation were checked; modeling was not. The recipe combines runtime selection, registry/policy arguments including `--no-sandbox`, and application-specific D2D/SVG and repaint changes.
- **Reproduction:** The Octane candidate copies only canonical blob `6702247b808414f396c40da6b0d11434dccf3de1` (SHA-256 `f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752`) onto the exact Wine/Staging pair. It does not import the D2D patch, Solid Edge registry keys, or sandbox bypass.
- **Local outcome:** Patch review, matched source/control compilation, and Docker/Wine execution completed. The candidate did not make the minimal native WebView2 probe render. The first three candidate runs required the then-current three-cycle resize/minimize/restore helper and completed the dialog/export contract only 1/3. Later state-based startup and foreground synchronization showed normal initial presentation and completed the final schema-v3 Octane contract 10/10 with the same patch and no repaint helper. The patch remains a maintenance condition and is not a general WebView2 fix.
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
- **Local outcome:** Source fetch, complete Staging application, shared control compilation, installation, and GUI execution completed on 2026-11-14. One fresh control run completed every application gate after a repaint nudge; the next remained black. The initial candidate series rendered Octane/workload in three fresh runs but completed every dialog/export gate in only one. After the harness defects were isolated, the same pinned candidate completed the stricter schema-v3 contract 10/10 without a repaint helper. The unpatched control remains unstable; the patched candidate is qualified only under the recorded lock.
- **Confidence:** High for provenance/build and the measured local runs; no claim beyond the tested profiles.

### R15 — Historical Wine 11.21 application comparison

- **Claim:** The initial Wine 11.21 comparison established conditional feasibility but did not yet establish repeatable acceptance.
- **Classification:** Locally reproduced experiment, not an upstream compatibility guarantee.
- **Source / author / date:** Octane run journals and evidence bundles for `17e5fdec70`, `615d1bca1e`, `d2cc660dbe`, `c5c34187fa`, and `aef06bc9fa`; Octane lab; 2026-11-14.
- **Version / platform:** Windows 11 build 26200.8875; WSL 3.0.1.0; Ubuntu-24.04 WSL2; kernel 6.18.40.1; Docker 29.6.2; Docker-Wine RDP/Xorgxrdp; `winex11`; Wine `2528aff...`; Staging `04414f...`; Evergreen WebView2 157.0.4341.60.
- **Reported outcome:** Not applicable; this entry records local measurements.
- **Reproduction:** Use the retained installer hash, a fresh container/prefix, one explicit profile, localhost RDP, `octane-lab install-silent`, then `Invoke-OctaneApplicationExperiment.ps1`; visually review native screenshots before running the reviewer and collector.
- **Local outcome:** The unpatched Staging control passed one full clean scenario and failed the next at visible presentation. In this historical series the visible-region candidate required three window-state repaint cycles in every fresh run; real UI/workload passed 3/3, but native-dialog plus no-overwrite acceptance passed 1/3. A reused-prefix debug run proved the improved synchronizer could repeat the overwrite-decline path, while Choose Files returned `Selection canceled` without a visible picker. That debug run is not clean acceptance. R16-R18 record the later localization and final qualification without rewriting these outcomes.
- **Confidence:** High for the recorded runs and artifact/profile identities; low for extrapolation beyond these versions or for production reliability.

### R16 — Retained Octane dialog path and isolated common-dialog probe

- **Claim:** The retained installer uses `rfd 0.15.4` synchronous modern Windows common-item dialogs from Tauri `spawn_blocking` threads without supplying a parent window; the same API shape is stable under the pinned Wine candidate both before and after Octane installation.
- **Classification:** Retained application source and lockfile, reviewed upstream source, and locally reproduced diagnostics.
- **Source / author / date:** Octane commit `7088eed9adb8403b9575afe1cc9e9c2984b29049`; `rfd` commit [`bac4bd3364f2befaabafa9f58ac77fd8925b2abf`](https://github.com/PolyMeilex/rfd/tree/bac4bd3364f2befaabafa9f58ac77fd8925b2abf), PolyMeilex, 2025-07-12; local review and runs 2026-11-14.
- **Version / platform:** `rfd 0.15.4`; `IFileOpenDialog` / `IFileSaveDialog`; STA with `COINIT_DISABLE_OLE1DDE`; null owner; worker thread; pinned Docker/Wine-Staging 11.21 visible-region candidate on `winex11`.
- **Reported outcome:** Upstream source creates `FileOpenDialog`/`FileSaveDialog`, sets `FOS_ALLOWMULTISELECT` for `pick_files`, initializes apartment-threaded COM with OLE1 DDE disabled, and calls `Show` with a null HWND when no parent is configured. Retained Octane source wraps `pick_files` and `save_file` in `tauri::async_runtime::spawn_blocking`.
- **Reproduction:** Build `diagnostics/win32-file-dialog`, then run `Invoke-FileDialogDiagnosticRun.ps1` with `-Phase CleanPrefix` and `-Phase PostInstall`, `-Suite AppMatch`. The probe records API return, exact selected paths, focus state, cancellation, and overwrite-decline integrity.
- **Local outcome:** Clean-prefix run `46953cece8` and post-install run `888f4aca2d` each passed 7/7. Both returned the exact `Space Ω` fixture paths, distinguished `0x800704C7` cancellation from failure, repeated open selection, returned two exact paths from one multi-select, and preserved the existing destination after overwrite decline. Their `dialog-suite.json` SHA-256 values are `36319fe3fadb19d7e49739dd819afbb9fbefda765f226bcbe7dfd8a7c90b146b` and `a07e7bfb14602da49f33ce52bab7a7ed410572509c31eac1e911ea668e6e6a4e`. A standalone probe pass is not an Octane dialog pass.
- **Confidence:** High for the exact API shape and measured probe cases; no claim for legacy APIs or arbitrary applications.

### R17 — Normal initial Octane presentation without the repaint helper

- **Claim:** The historical three-cycle resize/minimize/restore sequence was not required for initial presentation once startup was observed with bounded state-based waits.
- **Classification:** Locally reproduced diagnostic plus locked acceptance measurements.
- **Source / author / date:** Octane repaint observer `948d78d02c` and final batch `qbatch-e2aaafff4b38`, Octane lab, 2026-11-14.
- **Version / platform:** Retained installer and exact pinned candidate on XFCE/Xorgxrdp, `winex11`, 1280x800, Mesa llvmpipe, WebView2 157.0.4341.60.
- **Reported outcome:** Not applicable; this entry records local measurements.
- **Reproduction:** Launch the installed executable once, permit one ordinary foreground activation, forbid resize/minimize/restore/click/reconnect/retry before readiness, and sample the actual client area until the bounded deadline.
- **Local outcome:** The dedicated observer reached visible presentation at 17.615 seconds with 1,650 client colors and `forcedRepaintUsed=false`. All ten final runs presented at 19.000-19.084 seconds without the helper, hidden retry, or manual override, and later passed ordinary post-readiness resize/scroll/minimize/restore. This disproves the earlier assumption that the three-cycle sequence was a causal prerequisite in this exact profile; it does not identify which WebView2/startup event consumed the latency.
- **Confidence:** High for the measured configuration; low for extrapolation to the still-white minimal WebView2 probe or other hosts.

### R18 — Final schema-v3 unattended qualification

- **Claim:** The retained installed Octane artifact satisfies the declared full acceptance contract in ten sequential fresh containers and prefixes under one immutable lock.
- **Classification:** Locally reproduced qualification.
- **Source / author / date:** Lock `profiles/qualification/docker-wine-staging-11.21-visrgn.lock.json`, batch `qbatch-e2aaafff4b38`, harness commit `7181a47ee47ae1d63b3bcd4fa6a480d45b560ee3`, Octane lab, 2026-11-14.
- **Version / platform:** Windows 11 build 26200.8875; WSL 3.0.1.0; Ubuntu 24.04.4; kernel 6.18.40.1; Docker 29.6.2 inside WSL; image `sha256:0443029e26be1d0590fd37491d69ab8fc1e186ef7e80d4d75cb191628188259c`; Wine/Staging 11.21 plus visible-region patch; Evergreen WebView2 157.0.4341.60.
- **Reported outcome:** Not applicable; this entry records local measurements.
- **Reproduction:** Verify lock SHA-256 `0137c535f4eb0d15c12628801020b71f1952a18c65c524b7ac26874f6e6377c1`, then run `Invoke-OctaneQualificationBatch.ps1` with ten planned runs. Each run must create a fresh container/prefix/user-data state, install the retained SHA-256 `adde062d...` artifact, launch once, execute every gate, collect evidence, and remove its exact resource.
- **Local outcome:** 10/10 runs passed all ten gates: lock/runtime identity, fresh installation, normal presentation, continuing repaint/input, exact Unicode and missing-path contracts, real 8-file Rust workload, native open/save cancellation and repeated use, independently validated export/no-overwrite/input integrity, ordinary post-dialog resize/restore, and evidence/cleanup. Every run recorded `forcedRepaintUsed=false`, no hidden retry, and no manual override. Batch-summary SHA-256 is `ee890ddcf0b4f420cff10a2d5be33ef8c7d6695b1bcb34f10b872df9fd9fff2b`; the 1,853-entry checksum manifest verifies and has SHA-256 `e148ad2bb58998b62a54c2a0b131e49eaaaf86e11328b2580b8e576b751415e0`.
- **Confidence:** High for the exact installer, lock, schema, and recorded host. This does not qualify stock Wine, arbitrary Tauri applications, or an untested proprietary installer.

### R19 — noVNC/Websockify browser candidate and validation boundary

- **Claim:** noVNC can deliver a VNC framebuffer and normal input through a browser, but an HTTP viewer response or even a VNC `connect` event does not establish target application readiness or functional acceptance.
- **Classification:** Primary project documentation/source plus locally reproduced component checks; browser end-to-end application result remains unverified.
- **Source / author / date:** [`novnc/noVNC`](https://github.com/novnc/noVNC) commit `63107bd06d9e1f6136ff21aeda8cd62cbf0d433e`; [`novnc/websockify`](https://github.com/novnc/websockify) commit `e81894751365afc19fe64fc9d0e5c6fc52655c36`; [noVNC architecture](https://novnc.com/info.html); inspected and built 2026-11-14.
- **Version / platform:** Windows 11 / Ubuntu 24.04.4 WSL2 / Docker 29.6.2; browser layer over image `sha256:0443029e...`; final browser candidate image `sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba`; Xvfb/XFCE `:1`; x11vnc 0.9.16-10; noVNC/Websockify pinned commits above.
- **Reported outcome:** noVNC documents browser-based VNC access; its public RFB client emits supported connection/security/disconnect events. These events describe transport, not a Tauri/WebView2 application's pixels, backend, native dialogs, or export.
- **Reproduction:** Build `lab/Dockerfile.browser-novnc` only over the exact historical image; launch with one read-only per-run password file and one `127.0.0.1:PORT:3000` publication; run `Test-OctaneBrowserComponents.ps1`; then, through an approved browser, connect to `/octane.html`, verify actual application pixels and drive all input through noVNC.
- **Local outcome:** Final component run `c71f9b509b` passed exact container/image identity, loopback publication, credential mount, absence of RDP process/listener, raw VNC loopback-only listeners, X11/display identity, RFB password configuration, HTTP viewer content, and bad-origin rejection. The unchanged installer completed in a fresh prefix; one exact executable and loaded WebView2 157.0.4341.60 path/hash were recorded; a native X11 window existed. No approved browser control was available, so VNC negotiation, browser framebuffer, browser input, visible application readiness, workload, dialogs, export, and the 10/10 batch remain BLOCKED/NOT_RUN. A container-side screenshot is explicitly not browser evidence.
- **Confidence:** High for build/component/runtime observations; no confidence claim for browser-delivered application acceptance until manual or approved automated evidence exists.

### R20 — Docker port and bind semantics used by the candidate

- **Claim:** Docker port publication must name the loopback host address to avoid default all-interface exposure, and bind mounts are resolved by the daemon host rather than the client shell.
- **Classification:** Primary Docker documentation plus local implementation checks.
- **Source / author / date:** [Docker port publishing](https://docs.docker.com/engine/network/port-publishing/) and [Docker bind mounts](https://docs.docker.com/engine/storage/bind-mounts/), Docker, accessed 2026-11-14.
- **Version / platform:** Docker Engine 29.6.2 inside Ubuntu-24.04 WSL2; Windows PowerShell controller.
- **Reported outcome:** Omitting a host address publishes to all interfaces by default; daemon-side path resolution makes Windows-to-WSL conversion an explicit controller responsibility.
- **Reproduction:** Inspect `HostConfig.PortBindings`, listeners, mounts, selected Docker context/socket, and Windows reachability. Reject unexpected publications and any mount other than the exact read-only credential file in the browser profile.
- **Local outcome:** Final component checks observed exactly one `127.0.0.1` viewer publication, no raw VNC/RDP publication, and one exact read-only password-file bind converted for the selected WSL daemon. Installer and fixture data used `docker cp`; no broad host directory was mounted.
- **Confidence:** High.

### R21 — Generic artifact, file, and endpoint capability measurements

- **Claim:** The provider-neutral intake safely distinguishes same-name pipeline artifacts, handles approximately 400 MiB files without rebuilding the environment, preserves selected host input, and can classify explicitly declared Linux-container HTTP endpoints.
- **Classification:** Locally reproduced harness measurements; not target GUI or corporate-network acceptance.
- **Source / author / date:** Octane browser-runtime tests and evidence, 2026-11-14.
- **Version / platform:** Windows PowerShell 7 controller; NTFS source/cache; Docker Engine 29.6.2 in WSL2; final browser image for endpoint probes.
- **Reported outcome:** Not applicable; this entry records local results.
- **Reproduction:** Run `Test-OctaneArtifactTransport.ps1 -SizeMiB 420`; create a project-owned HTTP sidecar and invoke `octane-target probe-network` with one reachable and one unavailable profile endpoint; collect JSON before exact cleanup.
- **Local outcome:** A 440,401,920-byte synthetic fixture streamed and hashed in 1.548 seconds; same filename/different tail byte yielded a second immutable ID in 1.479 seconds; a 10 MiB truncation failed the authoritative full hash; identical bytes reused the verified cache. A controlled HTTP 200 endpoint passed with exit 0, and an unavailable port recorded `accepted:false` and returned exit 1. These prove transport and Linux-curl classification only. A second real installer and application-level network behavior were unavailable/NOT_TESTED.
- **Confidence:** High for the measured harness operations; none for an untested target or authentication path.

### R22 - Importable WSL appliance and separate Docker image recovery

- **Claim:** WSL supports importing a root-filesystem TAR as a named distribution at a selected install location, while Docker supports restoring image/tag data from an archive or standard input. Keeping the WSL management rootfs and Docker image archive separate is therefore a supported packaging composition rather than a populated Docker-data-directory transplant.
- **Classification:** Primary Microsoft/Docker documentation plus locally reproduced package lifecycle.
- **Source / author / date:** [Microsoft WSL basic commands](https://learn.microsoft.com/windows/wsl/basic-commands), [Microsoft custom-distro import guidance](https://learn.microsoft.com/windows/wsl/use-custom-distro), [Docker image load](https://docs.docker.com/reference/cli/docker/image/load/), Microsoft and Docker, accessed 2026-11-14.
- **Version / platform:** Windows 11 build 26200.8875; WSL 3.0.1.0; exported Ubuntu 24.04 rootfs; Docker CE 29.6.2, containerd 2.2.6, buildx 0.36.0, Compose 5.3.1 inside the imported distro; browser image `sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba`.
- **Reported outcome:** Microsoft documents `wsl --import <name> <location> <tar> --version 2` and custom default-user configuration in `/etc/wsl.conf`. Docker documents `docker image load` from a TAR archive or standard input and support for zstd-compressed input. These interfaces do not by themselves qualify an application or authorize host policy changes.
- **Reproduction:** Build `lab/Dockerfile.wsl-appliance` from the pinned Ubuntu digest; export its rootfs without `/var/lib/docker` state; separately zstd-compress and test the verified Docker-save archive; assemble the package; run `Install-Octane.ps1 -PlanOnly`; then execute `Test-OctaneAppliancePackage.ps1` with a unique distro, retained installer, WSL-visible state root, and exact cleanup enabled.
- **Local outcome:** Rootfs TAR 503,298,560 bytes / SHA-256 `56f7445646c6442df301e39d5f4e325dae63b2e85d04a2e7f8d3c70b4cf3c5ae`; compressed image 2,077,870,568 bytes / SHA-256 `a5876cac7604c47c6e06bcb890f3bc4dedd81aabfb3906a53d9b73929caf8a0e`; uncompressed Docker-save SHA-256 `6c1f4f9fd364ed970fc1ba1796a71952e2f917ae7603ea3cf10903d6209dbfb5`. The final package was copied to `Extracted Appliance ü`, passed its hash plan, and generated an operational generic overlay. Live package run `fd53638dc0` passed import, internal Docker, image ID, deep doctor, fresh unchanged-installer startup, native executable/WebView2 and browser component checks, collection, exact container stop, distro unregister, and storage cleanup. Browser VNC negotiation/framebuffer/input/application readiness were NOT_RUN, so browser acceptance remains BLOCKED.
- **Confidence:** High for the exact package bytes and measured component lifecycle; none for browser acceptance, another Windows application, an unsandboxed second machine, or organizational permission to import WSL distributions.

### R23 — Validate-before-replace clean-build lifecycle

- **Claim:** A new pipeline installer can be admitted immutably before the active application session is collected and removed, while retaining the reusable WSL/Docker/Wine foundation and creating a new prefix/application/WebView2 state.
- **Classification:** Locally reproduced lifecycle measurement.
- **Source / author / date:** Octane executable commit `136944da9e8b0ee4f3c6727613d062abbd958857`; replacement runs `750fc957af` and `603b83b9bf`; Octane lab, 2026-11-15.
- **Version / platform:** Windows 11 / Ubuntu-24.04 WSL2 / Docker 29.6.2; pinned Wine-Staging 11.21 visible-region browser candidate; same retained installer used for both sessions.
- **Reported outcome:** Not applicable; this entry records local results.
- **Reproduction:** Invoke `octane open` or `Start-OctanePreview.ps1 -LifecycleMode ReplaceActive` twice with the same immutable installer. Verify the second intake before prior collection, exact old marker/container/session removal, active-journal transfer, fresh home/prefix/WebView2 state, port reuse, and final cleanup.
- **Local outcome:** Both runs installed the retained executable in independent WSL-native session trees. The second run started only after the first evidence bundle was collected and exact resources were absent; the active journal moved to the second run and was absent after cleanup. Checksum-manifest SHA-256 values are `f2c2d20ec3d7377135b9bdf138685af7249cd3bd27631e0a794f7a35f84261a4` and `dad586d13ab5a7bf6053ddee31fc4882a8ef536296fbaa88198c3502282d90e5`. This proves replacement mechanics, not two-distinct-build application behavior.
- **Confidence:** High for the measured same-installer lifecycle; none for a second unavailable installer or browser application acceptance.

### R24 — Scoped authenticated browser-upload service and Wine path

- **Claim:** A per-run localhost upload service can accept explicit files without broad host mounts and expose them read-only to the installed Wine application under a stable path, while keeping browser-origin application ingestion as a separate gate.
- **Classification:** Locally reproduced protocol/component result; browser-origin interaction remains NOT_RUN.
- **Source / author / date:** `lab/browser/octane-upload-server`, `lab/browser/octane.html`, and run `3ca7d5cbb6`, executable commit `136944d`, Octane lab, 2026-11-15.
- **Version / platform:** Same browser candidate image `sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a`; service port 3002 mapped to an independent Windows loopback port.
- **Reported outcome:** Not applicable; this entry records local results.
- **Reproduction:** Start a fresh preview, authenticate with the per-run in-memory credential and exact viewer origin, upload one controlled file, compare the returned/manifest SHA-256, inspect `C:\octane-input\uploaded` through Wine, then collect and remove the exact session. Run `tests/upload-server.test.sh` for bad-origin, bad-auth, name, overwrite, size, and atomic-write cases.
- **Local outcome:** Twelve protocol assertions passed. Live file `pipeline input ü.csv` (21 bytes) produced SHA-256 `b98731ba15c769924bf53163485f71f855a3da2b3d50f4f94ff5dffc04c83fae`, matched the service manifest, and was visible through Wine. The installed app had no broad `Z:` mapping. Component and collection checksum-manifest SHA-256 values are `52747f5868cafeab3e2e24426974f6f60db20a829779750deb5141cf2b89eb86` and `58369ee228bcca30203371cda3333ca431929f2e3f479b15a8b3827c930e6e81`. No approved browser clicked the upload control or drove Octane ingestion, so those gates remain NOT_RUN.
- **Confidence:** High for the direct service, filesystem, and Wine-path observations; none for browser-originated interaction or target ingestion until measured.

### R25 — Refreshed source-independent WSL appliance lifecycle

- **Claim:** The refreshed appliance and separate image archive can reproduce the executable candidate's non-browser component lifecycle without relying on the development checkout at runtime.
- **Classification:** Locally reproduced package/component measurement.
- **Source / author / date:** Package version `1.0.0-browser-candidate.136944d`, test `2164864404`, Octane lab, 2026-11-15.
- **Version / platform:** Windows 11; package path `Octane Moonshot Extracted ü\Octane-v1`; unique imported Ubuntu 24.04 WSL2 distro; Docker 29.6.2; image `sha256:a43c4441d45ddd57e899c1d77e9461c22414c654213e17a27031be3347191f1a`.
- **Reported outcome:** Not applicable; this entry records local results.
- **Reproduction:** Verify the package/runtime checksum manifests, run `Test-OctaneAppliancePackage.ps1` with a unique port/distro and the retained external installer, require `-RemoveAfterTest`, then verify the distro, container, launcher/storage roots, and ports are absent.
- **Local outcome:** Package contained 84 files / 2,583,977,275 bytes. Import, internal Docker startup, exact image load, deep doctor, fresh preview, browser/upload/no-RDP component checks, collection, exact stop, distro unregister, and storage cleanup passed. Result SHA-256 is `8ad04f36734b35b2a22e7578791fd4cc81889fc7e35f457a9682a870b005073f`; component checksum-manifest SHA-256 is `7f023762d400fed8b43e4bf9e3348718a8597782a81f62ccefd460016f73e288`. The retained port-3005 handoff remained present. Browser negotiation/framebuffer/input and target acceptance through the viewer were NOT_RUN.
- **Confidence:** High for the exact local package/component lifecycle; none for browser acceptance, another target, a second laptop, organizational import approval, or native-Windows equivalence.
