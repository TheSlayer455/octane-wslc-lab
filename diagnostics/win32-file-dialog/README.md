# Native Win32 file-dialog probe

This x64 Windows executable isolates common-dialog behavior from Tauri,
WebView2, `rfd`, and Octane's Rust workload. It always creates a visible owner
window, then invokes one independently selectable API mode:

- `modern-open`: `IFileOpenDialog`
- `modern-save`: `IFileSaveDialog`
- `legacy-open`: `GetOpenFileNameW`
- `legacy-save`: `GetSaveFileNameW`

The default `--thread worker --owner none` shape matches retained Octane's
`rfd 0.15.4` call path: the synchronous dialog runs on a `spawn_blocking`
thread, initializes COM as STA with OLE1 DDE disabled, and supplies no parent
window handle. `--owner owned` and `--thread ui` are labeled diagnostic
comparisons, not claims about the retained application.

Every invocation writes a JSON result and a JSON Lines event trace containing
API HRESULTs, cancellation versus failure, process/thread identities, owner,
foreground and focus transitions, selected paths, and timeout state. A watchdog
bounds a stuck modal invocation.

Build from Windows PowerShell 7 using Docker Engine in the selected WSL2
distribution:

```powershell
./scripts/Build-FileDialogProbe.ps1 -WslDistro Ubuntu-24.04
```

The resulting executable and manifest are local generated artifacts beneath
`diagnostics/win32-file-dialog/artifacts/`; they are not an Octane acceptance
result.
