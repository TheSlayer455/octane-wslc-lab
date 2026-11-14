#include <windows.h>
#include <wrl.h>
#include <WebView2.h>

#include <string>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

namespace {

constexpr wchar_t kWindowClass[] = L"OctaneWebView2DiagnosticWindow";
constexpr wchar_t kWindowTitle[] = L"Octane WebView2 Diagnostic";
constexpr LONG kNativeStatusHeight = 56;

HWND g_window = nullptr;
HANDLE g_log = INVALID_HANDLE_VALUE;
SRWLOCK g_log_lock = SRWLOCK_INIT;
std::wstring g_status = L"native host starting";
ComPtr<ICoreWebView2Environment> g_environment;
ComPtr<ICoreWebView2Controller> g_controller;
ComPtr<ICoreWebView2> g_webview;

const wchar_t kDiagnosticHtml[] = LR"HTML(
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  :root { color-scheme: light; font-family: "Segoe UI", sans-serif; }
  body { margin: 0; background: #f5f8fb; color: #10283b; }
  main { max-width: 900px; margin: 24px auto; padding: 0 24px 40px; }
  h1 { margin: 0 0 8px; font-size: 30px; }
  .sub { color: #49667b; margin-bottom: 20px; }
  .grid { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 16px; }
  .card { background: white; border: 1px solid #c9d8e3; border-radius: 12px; padding: 18px; box-shadow: 0 2px 8px #17384d18; }
  .label { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: #54748b; }
  #counter { font-size: 44px; font-variant-numeric: tabular-nums; font-weight: 700; }
  #pulse { height: 88px; border-radius: 10px; background: hsl(195 72% 48%); transition: background-color .18s linear; }
  button { border: 0; border-radius: 8px; padding: 11px 17px; color: white; background: #006f9f; font-weight: 700; cursor: pointer; }
  input { box-sizing: border-box; width: 100%; margin-top: 10px; padding: 10px 12px; border: 1px solid #9bb3c4; border-radius: 7px; font-size: 16px; }
  #mirror { min-height: 24px; margin-top: 8px; font-weight: 600; }
  #scrollbox { height: 160px; overflow-y: scroll; border: 1px solid #9bb3c4; border-radius: 8px; background: linear-gradient(#dff5ff,#fff4ce,#e7dfff); }
  #scrollcontent { height: 700px; padding: 14px; }
  #bottom { margin-top: 600px; font-weight: 700; }
  @media (max-width: 650px) { .grid { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<main>
  <h1>Native Win32 WebView2 diagnostic</h1>
  <div class="sub">Local content only. Visible motion, input, click, and scroll are independent acceptance signals.</div>
  <div class="grid">
    <section class="card"><div class="label">Repaint counter</div><div id="counter">0</div></section>
    <section class="card"><div class="label">Animated color</div><div id="pulse"></div></section>
    <section class="card">
      <div class="label">Input and click</div>
      <button id="action" type="button">Change panel</button>
      <input id="entry" aria-label="Diagnostic text" placeholder="Type here">
      <div id="mirror">Waiting for input</div>
    </section>
    <section class="card">
      <div class="label">Scrollable area</div>
      <div id="scrollbox"><div id="scrollcontent">Scroll down<div id="bottom">Bottom reached</div></div></div>
    </section>
  </div>
</main>
<script>
(() => {
  const send = value => window.chrome.webview.postMessage(value);
  const counter = document.getElementById('counter');
  const pulse = document.getElementById('pulse');
  const action = document.getElementById('action');
  const entry = document.getElementById('entry');
  const mirror = document.getElementById('mirror');
  const scrollbox = document.getElementById('scrollbox');
  let ticks = 0;
  let clicks = 0;
  send('dom-ready');
  setInterval(() => {
    ticks += 1;
    counter.textContent = String(ticks);
    pulse.style.backgroundColor = `hsl(${(ticks * 17) % 360} 72% 48%)`;
    if (ticks === 4 || ticks % 20 === 0) send(`repaint-tick:${ticks}`);
  }, 250);
  action.addEventListener('click', () => {
    clicks += 1;
    document.body.style.backgroundColor = clicks % 2 ? '#fff6df' : '#f5f8fb';
    action.textContent = `Panel changed ${clicks}`;
    send(`button-click:${clicks}`);
  });
  entry.addEventListener('input', () => {
    mirror.textContent = entry.value || 'Waiting for input';
    send(`input-length:${entry.value.length}`);
  });
  scrollbox.addEventListener('scroll', () => {
    if (scrollbox.scrollTop > 450) send(`scroll-bottom:${Math.round(scrollbox.scrollTop)}`);
  }, { passive: true });
})();
</script>
</body>
</html>
)HTML";

std::wstring GetEnvironmentValue(const wchar_t* name) {
    const DWORD required = GetEnvironmentVariableW(name, nullptr, 0);
    if (required == 0) return {};
    std::wstring value(required, L'\0');
    const DWORD written = GetEnvironmentVariableW(name, value.data(), required);
    if (written == 0 || written >= required) return {};
    value.resize(written);
    return value;
}

std::wstring HresultText(HRESULT value) {
    wchar_t buffer[16]{};
    swprintf_s(buffer, L"0x%08X", static_cast<unsigned int>(value));
    return buffer;
}

std::wstring Number(long long value) {
    return std::to_wstring(value);
}

std::string Utf8(const std::wstring& value) {
    if (value.empty()) return {};
    const int required = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    if (required <= 0) return {};
    std::string result(static_cast<size_t>(required), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), required, nullptr, nullptr);
    return result;
}

void Log(const std::wstring& event, const std::wstring& detail = {}) {
    SYSTEMTIME now{};
    GetSystemTime(&now);
    wchar_t timestamp[40]{};
    swprintf_s(
        timestamp,
        L"%04u-%02u-%02uT%02u:%02u:%02u.%03uZ",
        now.wYear,
        now.wMonth,
        now.wDay,
        now.wHour,
        now.wMinute,
        now.wSecond,
        now.wMilliseconds);
    std::wstring line = timestamp;
    line += L"\tevent=" + event;
    line += L"\tpid=" + Number(GetCurrentProcessId());
    line += L"\ttid=" + Number(GetCurrentThreadId());
    if (!detail.empty()) line += L"\t" + detail;
    line += L"\r\n";
    const std::string encoded = Utf8(line);
    if (g_log == INVALID_HANDLE_VALUE || encoded.empty()) return;
    AcquireSRWLockExclusive(&g_log_lock);
    DWORD written = 0;
    WriteFile(g_log, encoded.data(), static_cast<DWORD>(encoded.size()), &written, nullptr);
    FlushFileBuffers(g_log);
    ReleaseSRWLockExclusive(&g_log_lock);
}

void SetStatus(const std::wstring& status) {
    g_status = status;
    if (g_window) {
        const std::wstring title = std::wstring(kWindowTitle) + L" - " + status;
        SetWindowTextW(g_window, title.c_str());
        InvalidateRect(g_window, nullptr, TRUE);
    }
    Log(L"status", L"value=" + status);
}

void ResizeWebView() {
    if (!g_controller || !g_window) return;
    RECT bounds{};
    GetClientRect(g_window, &bounds);
    bounds.top = kNativeStatusHeight;
    if (bounds.bottom < bounds.top) bounds.bottom = bounds.top;
    const HRESULT hr = g_controller->put_Bounds(bounds);
    if (FAILED(hr)) Log(L"controller-bounds-failed", L"hresult=" + HresultText(hr));
}

void ConfigureWebView() {
    ComPtr<ICoreWebView2Settings> settings;
    HRESULT hr = g_webview->get_Settings(&settings);
    if (SUCCEEDED(hr) && settings) {
        settings->put_IsScriptEnabled(TRUE);
        settings->put_AreDefaultScriptDialogsEnabled(TRUE);
        settings->put_IsWebMessageEnabled(TRUE);
    } else {
        Log(L"settings-failed", L"hresult=" + HresultText(hr));
    }

    EventRegistrationToken process_failed_token{};
    hr = g_webview->add_ProcessFailed(
        Callback<ICoreWebView2ProcessFailedEventHandler>(
            [](ICoreWebView2*, ICoreWebView2ProcessFailedEventArgs* args) -> HRESULT {
                COREWEBVIEW2_PROCESS_FAILED_KIND kind = COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED;
                args->get_ProcessFailedKind(&kind);
                std::wstring detail = L"kind=" + Number(static_cast<int>(kind));
                ComPtr<ICoreWebView2ProcessFailedEventArgs2> args2;
                if (SUCCEEDED(args->QueryInterface(IID_PPV_ARGS(&args2))) && args2) {
                    COREWEBVIEW2_PROCESS_FAILED_REASON reason = COREWEBVIEW2_PROCESS_FAILED_REASON_UNEXPECTED;
                    int exit_code = 0;
                    LPWSTR description = nullptr;
                    args2->get_Reason(&reason);
                    args2->get_ExitCode(&exit_code);
                    args2->get_ProcessDescription(&description);
                    detail += L"\treason=" + Number(static_cast<int>(reason));
                    detail += L"\texit_code=" + Number(exit_code);
                    if (description) {
                        detail += L"\tdescription=" + std::wstring(description);
                        CoTaskMemFree(description);
                    }
                }
                Log(L"process-failed", detail);
                SetStatus(L"process failure observed");
                return S_OK;
            }).Get(),
        &process_failed_token);
    Log(L"add-process-failed", L"hresult=" + HresultText(hr));

    EventRegistrationToken navigation_token{};
    hr = g_webview->add_NavigationCompleted(
        Callback<ICoreWebView2NavigationCompletedEventHandler>(
            [](ICoreWebView2*, ICoreWebView2NavigationCompletedEventArgs* args) -> HRESULT {
                BOOL success = FALSE;
                COREWEBVIEW2_WEB_ERROR_STATUS error = COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
                UINT64 navigation_id = 0;
                args->get_IsSuccess(&success);
                args->get_WebErrorStatus(&error);
                args->get_NavigationId(&navigation_id);
                Log(
                    L"navigation-completed",
                    L"success=" + Number(success) + L"\terror=" + Number(static_cast<int>(error)) +
                        L"\tnavigation_id=" + Number(static_cast<long long>(navigation_id)));
                if (success) SetStatus(L"local page navigated");
                return S_OK;
            }).Get(),
        &navigation_token);
    Log(L"add-navigation-completed", L"hresult=" + HresultText(hr));

    EventRegistrationToken message_token{};
    hr = g_webview->add_WebMessageReceived(
        Callback<ICoreWebView2WebMessageReceivedEventHandler>(
            [](ICoreWebView2*, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                LPWSTR message = nullptr;
                const HRESULT message_hr = args->TryGetWebMessageAsString(&message);
                if (SUCCEEDED(message_hr) && message) {
                    const std::wstring value(message);
                    Log(L"web-message", L"value=" + value);
                    if (value == L"dom-ready") SetStatus(L"DOM ready and messaging");
                    CoTaskMemFree(message);
                } else {
                    Log(L"web-message-failed", L"hresult=" + HresultText(message_hr));
                }
                return S_OK;
            }).Get(),
        &message_token);
    Log(L"add-web-message", L"hresult=" + HresultText(hr));

    ResizeWebView();
    hr = g_webview->NavigateToString(kDiagnosticHtml);
    Log(L"navigate-to-string", L"hresult=" + HresultText(hr));
    if (FAILED(hr)) SetStatus(L"NavigateToString failed " + HresultText(hr));
}

void InitializeWebView() {
    const std::wstring user_data = GetEnvironmentValue(L"OCTANE_WEBVIEW2_USER_DATA");
    Log(L"environment-create-request", user_data.empty() ? L"user_data=default" : L"user_data=" + user_data);
    const HRESULT immediate_hr = CreateCoreWebView2EnvironmentWithOptions(
        nullptr,
        user_data.empty() ? nullptr : user_data.c_str(),
        nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [](HRESULT result, ICoreWebView2Environment* environment) -> HRESULT {
                Log(L"environment-created", L"hresult=" + HresultText(result));
                if (FAILED(result) || !environment) {
                    SetStatus(L"environment failed " + HresultText(result));
                    return S_OK;
                }

                g_environment = environment;
                LPWSTR version = nullptr;
                if (SUCCEEDED(environment->get_BrowserVersionString(&version)) && version) {
                    Log(L"runtime-version", L"value=" + std::wstring(version));
                    CoTaskMemFree(version);
                }

                ComPtr<ICoreWebView2Environment11> environment11;
                if (SUCCEEDED(environment->QueryInterface(IID_PPV_ARGS(&environment11))) && environment11) {
                    LPWSTR failure_path = nullptr;
                    const HRESULT path_hr = environment11->get_FailureReportFolderPath(&failure_path);
                    if (SUCCEEDED(path_hr) && failure_path) {
                        Log(L"failure-report-folder", L"path=" + std::wstring(failure_path));
                        CoTaskMemFree(failure_path);
                    } else {
                        Log(L"failure-report-folder-failed", L"hresult=" + HresultText(path_hr));
                    }
                } else {
                    Log(L"failure-report-folder-unavailable");
                }

                ComPtr<ICoreWebView2Environment5> environment5;
                if (SUCCEEDED(environment->QueryInterface(IID_PPV_ARGS(&environment5))) && environment5) {
                    EventRegistrationToken browser_exit_token{};
                    const HRESULT exit_hr = environment5->add_BrowserProcessExited(
                        Callback<ICoreWebView2BrowserProcessExitedEventHandler>(
                            [](ICoreWebView2Environment*, ICoreWebView2BrowserProcessExitedEventArgs* args) -> HRESULT {
                                COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND kind = COREWEBVIEW2_BROWSER_PROCESS_EXIT_KIND_NORMAL;
                                UINT32 process_id = 0;
                                args->get_BrowserProcessExitKind(&kind);
                                args->get_BrowserProcessId(&process_id);
                                Log(
                                    L"browser-process-exited",
                                    L"kind=" + Number(static_cast<int>(kind)) + L"\tbrowser_pid=" + Number(process_id));
                                return S_OK;
                            }).Get(),
                        &browser_exit_token);
                    Log(L"add-browser-process-exited", L"hresult=" + HresultText(exit_hr));
                } else {
                    Log(L"browser-process-exited-unavailable");
                }

                SetStatus(L"environment ready");
                const HRESULT controller_hr = environment->CreateCoreWebView2Controller(
                    g_window,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [](HRESULT controller_result, ICoreWebView2Controller* controller) -> HRESULT {
                            Log(L"controller-created", L"hresult=" + HresultText(controller_result));
                            if (FAILED(controller_result) || !controller) {
                                SetStatus(L"controller failed " + HresultText(controller_result));
                                return S_OK;
                            }
                            g_controller = controller;
                            const HRESULT webview_hr = controller->get_CoreWebView2(&g_webview);
                            Log(L"get-core-webview2", L"hresult=" + HresultText(webview_hr));
                            if (FAILED(webview_hr) || !g_webview) {
                                SetStatus(L"CoreWebView2 failed " + HresultText(webview_hr));
                                return S_OK;
                            }
                            SetStatus(L"controller ready");
                            ConfigureWebView();
                            return S_OK;
                        }).Get());
                Log(L"controller-create-request", L"hresult=" + HresultText(controller_hr));
                if (FAILED(controller_hr)) SetStatus(L"controller request failed " + HresultText(controller_hr));
                return S_OK;
            }).Get());
    Log(L"environment-create-return", L"hresult=" + HresultText(immediate_hr));
    if (FAILED(immediate_hr)) SetStatus(L"environment request failed " + HresultText(immediate_hr));
}

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
    case WM_SIZE:
        ResizeWebView();
        return 0;
    case WM_PAINT: {
        PAINTSTRUCT paint{};
        HDC device = BeginPaint(window, &paint);
        RECT status_rect{};
        GetClientRect(window, &status_rect);
        status_rect.bottom = kNativeStatusHeight;
        HBRUSH background = CreateSolidBrush(RGB(17, 42, 61));
        FillRect(device, &status_rect, background);
        DeleteObject(background);
        SetBkMode(device, TRANSPARENT);
        SetTextColor(device, RGB(235, 246, 252));
        status_rect.left += 18;
        DrawTextW(device, g_status.c_str(), -1, &status_rect, DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);
        EndPaint(window, &paint);
        return 0;
    }
    case WM_CLOSE:
        Log(L"window-close-request");
        DestroyWindow(window);
        return 0;
    case WM_DESTROY:
        Log(L"window-destroy-begin");
        if (g_controller) {
            const HRESULT close_hr = g_controller->Close();
            Log(L"controller-close-return", L"hresult=" + HresultText(close_hr));
        }
        g_webview.Reset();
        g_controller.Reset();
        g_environment.Reset();
        Log(L"window-destroy-complete");
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(window, message, wparam, lparam);
    }
}

bool OpenLog() {
    std::wstring log_path = GetEnvironmentValue(L"OCTANE_DIAGNOSTIC_LOG");
    if (log_path.empty()) {
        wchar_t temporary[MAX_PATH]{};
        if (GetTempPathW(MAX_PATH, temporary) == 0) return false;
        log_path = temporary;
        log_path += L"OctaneWebView2Diagnostic.log";
    }
    g_log = CreateFileW(
        log_path.c_str(),
        FILE_APPEND_DATA,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        nullptr,
        OPEN_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nullptr);
    return g_log != INVALID_HANDLE_VALUE;
}

} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show_command) {
    OpenLog();
    Log(L"process-start");
    const HRESULT com_hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    Log(L"coinitialize", L"hresult=" + HresultText(com_hr));
    if (FAILED(com_hr) && com_hr != RPC_E_CHANGED_MODE) return 2;

    WNDCLASSEXW window_class{};
    window_class.cbSize = sizeof(window_class);
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.lpfnWndProc = WindowProcedure;
    window_class.hInstance = instance;
    window_class.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    window_class.lpszClassName = kWindowClass;
    window_class.hIconSm = LoadIconW(nullptr, IDI_APPLICATION);
    if (!RegisterClassExW(&window_class)) {
        Log(L"register-class-failed", L"win32=" + Number(GetLastError()));
        return 3;
    }

    g_window = CreateWindowExW(
        0,
        kWindowClass,
        kWindowTitle,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        1080,
        820,
        nullptr,
        nullptr,
        instance,
        nullptr);
    if (!g_window) {
        Log(L"create-window-failed", L"win32=" + Number(GetLastError()));
        return 4;
    }

    ShowWindow(g_window, show_command);
    UpdateWindow(g_window);
    SetStatus(L"native host ready");
    InitializeWebView();

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    Log(L"message-loop-exit", L"code=" + Number(message.wParam));
    if (SUCCEEDED(com_hr)) CoUninitialize();
    Log(L"process-exit");
    if (g_log != INVALID_HANDLE_VALUE) CloseHandle(g_log);
    return static_cast<int>(message.wParam);
}
