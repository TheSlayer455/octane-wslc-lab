# Native Win32 WebView2 diagnostic

This is a deliberately small native Win32 host for separating WebView2/Wine failures from Octane and Tauri. It renders only an application-local HTML string with a changing counter, animated color, button, text input, and scrollable region. It is an additional diagnostic workload, not an Octane substitute.

The implementation follows Microsoft's Win32 WebView2 documentation and uses the pinned `Microsoft.Web.WebView2` SDK package. The official `MicrosoftEdge/WebView2Samples` `Win32_GettingStarted` project at commit `06d49d546ba5dc0e2773798ee5b982f68275af4c` was used as a reference; this diagnostic adds native status paint, local-only content, and process-failure evidence.

Environment variables:

- `OCTANE_DIAGNOSTIC_LOG`: Windows path for UTF-8 event logging.
- `OCTANE_WEBVIEW2_USER_DATA`: Windows path for the isolated WebView2 user-data directory.
- `OCTANE_WEBVIEW2_BROWSER_EXECUTABLE_FOLDER`: optional explicit Fixed Version runtime directory. Supplying a directory is a request, not proof of selection; verify the runtime version and child executable path in evidence.
- `OCTANE_WEBVIEW2_BROWSER_ARGS`: optional, experiment-specific `AdditionalBrowserArguments`. Requested arguments are recorded and must be compared with captured child command lines.
- `OCTANE_DIAGNOSTIC_STAGE_TIMEOUT_SECONDS`: environment/controller/navigation deadline, 5-600 seconds (default 45).
- `OCTANE_DIAGNOSTIC_RUN_SECONDS`: bounded duration after DOM-ready, 0-3600 seconds (default 0 means operator-controlled).

The log records initialization HRESULTs, requested runtime/arguments, loaded runtime version, browser PID, failure-report directory, navigation completion, JavaScript failures, request-animation-frame and interval telemetry, native window lifecycle, periodic native `ExecuteScript` snapshots, `ProcessFailed` kind/reason/exit code/description, `BrowserProcessExited`, stage timeouts, and controller shutdown.

DOM state and visible pixels are deliberately separate. A successful navigation, increasing interval counter, or returned script snapshot does not pass presentation. The container experiment runner must also capture the real X11 client area changing, and a human or equivalent native-window review must confirm that the expected page—not a spinner, error surface, or surrounding desktop—was displayed.

Build `Release|x64` with Visual Studio 2022, NuGet, and the Windows SDK from the repository root:

```powershell
./scripts/Build-WebView2Diagnostic.ps1
```

The same provider-neutral script is called by the private workflow, which publishes `WebView2Diagnostic-windows-x64` with a SHA-256 manifest. The diagnostic is not Octane acceptance and its artifact identity must remain separate from the installer identity.
