# Browser runtime-kit completion ledger

Reconciled 2026-11-14. This is the single A–I release-gate ledger for the browser candidate. `PASS` applies only to the named scope; browser acceptance cannot be inferred from a component PASS.

| Gate | Status | Evidence and exact meaning | Remaining item |
| --- | --- | --- | --- |
| A. Historical baseline preserved and recoverable | PASS | Historical lock SHA-256 `0137c535...`, image ID `0443029e...`, batch `qbatch-e2aaafff4b38`, v0.1.1, guide records, and WSLC backup were not changed or deleted. | None for preservation. |
| B. Browser-only desktop from Windows without RDP | BLOCKED | Final component bundle `evidence/octane-c71f9b509b-browser-components-20261114-202012` PASS: exact X11 `:1`, 1280x800, authenticated loopback x11vnc, origin-checked Websockify, one loopback publication, HTTP viewer, Wine process on `DISPLAY=:1` with `winex11.drv`, no XRDP/FreeRDP process/listener. Browser VNC negotiation, framebuffer, and input are NOT_RUN. | Approved operator smoke or approved browser automation. |
| C. Unchanged external-installer intake and generic profiles | PASS | `schemas/application-profile.schema.json`, `New/Test-OctaneTarget`, `Stage-OctaneArtifact`, and `Start-OctanePreview`. The imported appliance package staged retained external EXE SHA-256 `adde062d...`, installed it in a fresh container/prefix, identified one executable and WebView2, and cleaned exactly. | Another target remains separately UNTESTED. |
| D. AI-assisted onboarding from one document and kit | PASS for creation/extraction/component scope; browser interaction BLOCKED | `docs/OCTANE-AI-HANDOFF.md`; kit extracted under a path containing spaces and `ü`; overlay/profile/artifact/start/component/collect/stop commands ran without Git/source-tree fallback. | Operator/browser evidence from the extracted final kit. |
| E. Two-build replacement and ~400 MiB transport | BLOCKED for two real application builds; PASS for transport | Synthetic 420 MiB evidence `evidence/artifact-transport-d6e854b2d803`, result SHA-256 `c34a4f42...`: streamed copy/hash, same-name/different bytes, truncated producer-hash rejection, immutable reuse. Only one real retained installer was available. | Supply a second authorized real installer for application-level two-build validation. |
| F. File and network capabilities | PASS for declared generic copy/curl contracts | Host inputs are before/after hashed, reparse points rejected, container copy rehashed, outputs separated/collected. Controlled HTTP endpoint PASS evidence SHA-256 `3eb7c9...`; unavailable endpoint correctly FAIL evidence SHA-256 `e144dd...`. | Wine/WebView2/target protocol, corporate auth, shares, certificates, and integrated identity remain target-specific NOT_TESTED. |
| G. New 10/10 browser-only Octane batch | BLOCKED | Candidate lock SHA-256 `edea2b64...`; `profiles/candidates/browser-qualification-blocked-plan.json` declares ten rows, all NOT_RUN. Historical RDP batch is explicitly excluded. | Approved browser-control path, then a new frozen ten-run batch. |
| H. Failure recovery, exact cleanup, integrity, security tests | PASS for available scope | 35 browser/runtime assertions, 27 appliance-packaging assertions, 48 PowerShell harness assertions, 12 qualification-policy assertions, 19 Node tests; failed listener/build/network/appliance-boundary cases retained; exact containers/secrets/test distros removed; no global prune/WSL shutdown. Final manual candidate is deliberately retained and identified. | Browser-specific auth/input failure cases require an approved browser. |
| I. Runtime kit, appliance/image recovery, shared commands, docs, release integrity | BLOCKED as a qualified release; artifacts PASS as candidate | Importable 503,298,560-byte WSL rootfs SHA-256 `56f74456...`; separate 2,077,870,568-byte compressed image SHA-256 `a5876cac...`; package hash plan, live import/doctor/preview/components/collection/cleanup PASS; source-independent kit and shared commands maintained. | Browser qualification, normal unsandboxed default-path install, and authorized private release publication. |

## Candidate identity

- Runtime commit: `b227260e579bc4806cbd92659ea9956b06fbb253`.
- Image ID: `sha256:243cbc44326d000f26e26dbd0e769b3e300cc1ded51e7543a891d2aebecc15ba`.
- Candidate lock SHA-256: `edea2b6489601775489dbc2a5ac6aae4bc2572940632040e98baa053c5077234`.
- Installer: SHA-256 `adde062d79c2857cb2f5e676c5d6870986070252ac3cf7ca7a6b78c8d829080a`, 219,839,154 bytes.
- Current handoff run: `octane-c71f9b509b`, viewer `http://127.0.0.1:3005/octane.html`; availability must be rechecked with `Show-OctaneManualBrowserHandoff.ps1`.

## WSL appliance candidate result

- Executable harness commit: `b88db7bafdf129f9727921d27a434a3174998df7`.
- Rootfs source commit: `d8654e38f1db10f11c5a96c69502b784b2aebb3a`.
- Rootfs TAR: 503,298,560 bytes; SHA-256 `56f7445646c6442df301e39d5f4e325dae63b2e85d04a2e7f8d3c70b4cf3c5ae`.
- Compressed image: 2,077,870,568 bytes; SHA-256 `a5876cac7604c47c6e06bcb890f3bc4dedd81aabfb3906a53d9b73929caf8a0e`.
- Live test `3a42ee1ca3` / `octane-88c9d8c718`: install, deep doctor, preview components, collection, preview cleanup, and distro cleanup all PASS.
- Component checks: exact managed/image identity, loopback-only publication, read-only credential bind, no RDP process/listener, loopback-only raw VNC, X11/VNC display, authentication, Wine display identity, viewer HTTP, and bad-origin rejection all PASS.
- Browser VNC negotiation, framebuffer, input, and application readiness: NOT_RUN/BLOCKED.
- Evidence checksum manifest SHA-256: `a16e375d6e080414039a5574cf14abf48a4d4a4b5e888e02725237f818565061`.
- Cleanup: unique test distro/container/storage/port removed; original `Ubuntu-24.04`, port-3005 handoff, historical images/evidence, and unrelated containers retained.

## Release decision

Browser candidate implementation is preserved and component-tested. Mandatory browser acceptance and the ten-run browser batch are blocked, so the browser runtime kit is **not a qualified release** and no new qualified tag/release replaces v0.1.1.
