# Patch provenance

These files are experimental inputs, not silent replacements for packaged Wine modules.

| File | Source | Pinned identity | Local use |
| --- | --- | --- | --- |
| `0001-ole32-revoke-foreign-drop-targets-in-their-own-proce.patch` | Wine MR [!12477](https://gitlab.winehq.org/wine/wine/-/merge_requests/12477), Jason A. Donenfeld | head commit `22a16b053991f95e8bbf91e4784e73f833835b72` | Historical matched Wine 11.0 control/candidate experiment. Review/merge status remains unknown. |
| `0002-win32u-recheck-visrgn-for-cross-process-children.patch` | [`JustNotesa/solid-edge-wine-fixes`](https://github.com/JustNotesa/solid-edge-wine-fixes) | source commit `d3fd3268536ed43c7e5c616bc1c98eec07a9d154`; Git blob `6702247b808414f396c40da6b0d11434dccf3de1`; SHA-256 `f0ea7e56c4b86ce6e1f99940c4c18ac80f2bee86442c800bc58c2f36bde92752` | One-delta Wine 11.21/Staging 11.21 candidate. It addresses stale cross-process visible regions, not specifically initial WebView creation. |

The Solid Edge repository had no top-level license file at the pinned commit when inspected on 2026-11-14; only its vendored NanoSVG directory carried a license. That absence is recorded rather than interpreted as permission or prohibition. The candidate image is built and used locally for compatibility research and is not published by this project. Review redistribution terms before distributing the patch or a derived binary outside the private lab.

Wine source remains subject to Wine's own license. Every recipe builds a complete matched Wine tree from pinned source; it does not inject a precompiled DLL into a different Wine installation.
