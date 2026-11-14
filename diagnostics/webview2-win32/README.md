# Native Win32 WebView2 diagnostic

This is a deliberately small native Win32 host for separating WebView2/Wine failures from Octane and Tauri. It renders only an application-local HTML string with a changing counter, animated color, button, text input, and scrollable region. It is an additional diagnostic workload, not an Octane substitute.

The implementation follows Microsoft's Win32 WebView2 documentation and uses the pinned `Microsoft.Web.WebView2` SDK package. The official `MicrosoftEdge/WebView2Samples` `Win32_GettingStarted` project at commit `06d49d546ba5dc0e2773798ee5b982f68275af4c` was used as a reference; this diagnostic adds native status paint, local-only content, and process-failure evidence.

Environment variables:

- `OCTANE_DIAGNOSTIC_LOG`: Windows path for UTF-8 event logging.
- `OCTANE_WEBVIEW2_USER_DATA`: Windows path for the isolated WebView2 user-data directory.

The log records initialization HRESULTs, loaded runtime version, failure-report directory, navigation completion, web messages proving DOM activity/repaint ticks, `ProcessFailed` kind/reason/exit code/description, `BrowserProcessExited`, and whether controller shutdown returned.

Build `Release|x64` with Visual Studio 2022 after restoring `packages.config`. The private workflow produces `WebView2Diagnostic-windows-x64` and a SHA-256 manifest.
