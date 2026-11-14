# Browser preview checklist

This overlay is not operational until the NSIS arguments, executable filename, and window title have been verified for the unchanged installer.

- Confirm the viewer identifies the expected run and reports **VNC negotiated; application readiness unverified**.
- Confirm the real application client area renders normally on first launch.
- Use mouse, keyboard, scrolling, and focus through the viewer.
- Select controlled files from `C:\octane-input`; cancel and reopen the native dialog.
- Verify the application's observable ingestion result. Do not substitute a helper or direct backend call.
- Export through the real native save dialog to `C:\octane-output`.
- Confirm the application remains responsive after dialogs.
- Collect evidence and outputs, independently validate any application-specific result, then stop the exact run.

An operator-performed result is a manual smoke test, not an unattended qualification run.
