#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX

#include <windows.h>
#include <commdlg.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <shellapi.h>

#include <atomic>
#include <fstream>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr wchar_t kWindowClass[] = L"OctaneFileDialogProbeWindow";
constexpr UINT kRunDialogMessage = WM_APP + 1;
constexpr UINT kDialogCompleteMessage = WM_APP + 2;

struct Options {
    std::wstring mode = L"modern-open";
    std::wstring result_path = L"C:\\octane-dialog\\result.json";
    std::wstring events_path = L"C:\\octane-dialog\\events.jsonl";
    std::wstring owner_mode = L"none";
    std::wstring thread_mode = L"worker";
    DWORD timeout_seconds = 35;
};

struct Result {
    std::string outcome = "not-run";
    HRESULT hresult = E_PENDING;
    DWORD extended_error = 0;
    std::vector<std::wstring> selected_paths;
    bool timed_out = false;
};

Options g_options;
Result g_result;
HWND g_owner = nullptr;
DWORD g_process_id = 0;
DWORD g_ui_thread_id = 0;
DWORD g_dialog_thread_id = 0;
HRESULT g_ui_com_hresult = E_PENDING;
HRESULT g_dialog_com_hresult = E_PENDING;
std::atomic<bool> g_finished{false};
std::mutex g_log_mutex;

std::string WideToUtf8(const std::wstring& value) {
    if (value.empty()) return {};
    const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
    std::string output(static_cast<size_t>(size), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), output.data(), size, nullptr, nullptr);
    return output;
}

std::string JsonEscape(const std::string& value) {
    std::ostringstream out;
    for (const unsigned char ch : value) {
        switch (ch) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\b': out << "\\b"; break;
            case '\f': out << "\\f"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default:
                if (ch < 0x20) {
                    out << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(ch);
                } else {
                    out << ch;
                }
        }
    }
    return out.str();
}

std::string UtcNow() {
    SYSTEMTIME time{};
    GetSystemTime(&time);
    char buffer[40]{};
    std::snprintf(buffer, sizeof(buffer), "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ",
        time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute, time.wSecond, time.wMilliseconds);
    return buffer;
}

std::string HexValue(uintptr_t value) {
    std::ostringstream out;
    out << "0x" << std::hex << std::uppercase << value;
    return out.str();
}

std::string HresultHex(HRESULT value) {
    return HexValue(static_cast<uint32_t>(value));
}

std::string WindowClass(HWND window) {
    if (!window) return {};
    wchar_t buffer[256]{};
    GetClassNameW(window, buffer, static_cast<int>(std::size(buffer)));
    return WideToUtf8(buffer);
}

std::string WindowTitle(HWND window) {
    if (!window) return {};
    wchar_t buffer[512]{};
    GetWindowTextW(window, buffer, static_cast<int>(std::size(buffer)));
    return WideToUtf8(buffer);
}

void AppendEvent(const std::string& name, const std::string& detail = {}) {
    // Do not hold the log mutex while querying a window owned by another
    // thread. GetWindowTextW can synchronously message an in-process window;
    // the receiving UI thread may itself be trying to append an activation
    // event. Holding the mutex across that call creates a probe-only lock
    // inversion that looks exactly like a modal API failing to return.
    const HWND foreground = GetForegroundWindow();
    const HWND focus = GetFocus();
    const std::string foreground_class = WindowClass(foreground);
    const std::string foreground_title = WindowTitle(foreground);
    const std::string timestamp = UtcNow();
    const DWORD process_id = GetCurrentProcessId();
    const DWORD thread_id = GetCurrentThreadId();

    std::lock_guard<std::mutex> lock(g_log_mutex);
    std::ofstream file(WideToUtf8(g_options.events_path), std::ios::binary | std::ios::app);
    file << "{\"utc\":\"" << timestamp
         << "\",\"event\":\"" << JsonEscape(name)
         << "\",\"processId\":" << process_id
         << ",\"threadId\":" << thread_id
         << ",\"ownerHwnd\":\"" << HexValue(reinterpret_cast<uintptr_t>(g_owner))
         << "\",\"foregroundHwnd\":\"" << HexValue(reinterpret_cast<uintptr_t>(foreground))
         << "\",\"foregroundClass\":\"" << JsonEscape(foreground_class)
         << "\",\"foregroundTitle\":\"" << JsonEscape(foreground_title)
         << "\",\"focusHwnd\":\"" << HexValue(reinterpret_cast<uintptr_t>(focus))
         << "\",\"detail\":\"" << JsonEscape(detail) << "\"}\n";
}

void WriteSummary() {
    std::lock_guard<std::mutex> lock(g_log_mutex);
    std::ofstream file(WideToUtf8(g_options.result_path), std::ios::binary | std::ios::trunc);
    file << "{\n"
         << "  \"schemaVersion\": 1,\n"
         << "  \"mode\": \"" << JsonEscape(WideToUtf8(g_options.mode)) << "\",\n"
         << "  \"ownerMode\": \"" << JsonEscape(WideToUtf8(g_options.owner_mode)) << "\",\n"
         << "  \"threadMode\": \"" << JsonEscape(WideToUtf8(g_options.thread_mode)) << "\",\n"
         << "  \"apartment\": \"STA|COINIT_DISABLE_OLE1DDE\",\n"
         << "  \"processId\": " << g_process_id << ",\n"
         << "  \"uiThreadId\": " << g_ui_thread_id << ",\n"
         << "  \"dialogThreadId\": " << g_dialog_thread_id << ",\n"
         << "  \"ownerHwnd\": \"" << HexValue(reinterpret_cast<uintptr_t>(g_owner)) << "\",\n"
         << "  \"uiComHresult\": \"" << HresultHex(g_ui_com_hresult) << "\",\n"
         << "  \"dialogComHresult\": \"" << HresultHex(g_dialog_com_hresult) << "\",\n"
         << "  \"outcome\": \"" << JsonEscape(g_result.outcome) << "\",\n"
         << "  \"hresult\": \"" << HresultHex(g_result.hresult) << "\",\n"
         << "  \"commDlgExtendedError\": " << g_result.extended_error << ",\n"
         << "  \"timedOut\": " << (g_result.timed_out ? "true" : "false") << ",\n"
         << "  \"selectedPaths\": [";
    for (size_t index = 0; index < g_result.selected_paths.size(); ++index) {
        if (index) file << ',';
        file << "\n    \"" << JsonEscape(WideToUtf8(g_result.selected_paths[index])) << "\"";
    }
    if (!g_result.selected_paths.empty()) file << '\n';
    file << "  ]\n}\n";
}

std::wstring ParentDirectory(const std::wstring& path) {
    const auto separator = path.find_last_of(L"\\/");
    return separator == std::wstring::npos ? L"." : path.substr(0, separator);
}

void EnsureOutputDirectories() {
    SHCreateDirectoryExW(nullptr, ParentDirectory(g_options.result_path).c_str(), nullptr);
    SHCreateDirectoryExW(nullptr, ParentDirectory(g_options.events_path).c_str(), nullptr);
}

void CollectShellItem(IShellItem* item) {
    if (!item) return;
    PWSTR path = nullptr;
    const HRESULT hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
    if (SUCCEEDED(hr) && path) g_result.selected_paths.emplace_back(path);
    if (path) CoTaskMemFree(path);
}

HWND DialogOwner() {
    return g_options.owner_mode == L"owned" ? g_owner : nullptr;
}

HRESULT RunModernOpen() {
    IFileOpenDialog* dialog = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
    if (FAILED(hr)) return hr;
    const COMDLG_FILTERSPEC filters[] = {{L"All Files", L"*.*"}};
    dialog->SetFileTypes(1, filters);
    dialog->SetTitle(L"Octane modern open");
    // rfd 0.15.4 pick_files() replaces the option mask with this exact value.
    dialog->SetOptions(FOS_ALLOWMULTISELECT);
    AppendEvent("api-show-enter", "IFileOpenDialog::Show");
    hr = dialog->Show(DialogOwner());
    AppendEvent("api-show-return", HresultHex(hr));
    if (SUCCEEDED(hr)) {
        IShellItemArray* items = nullptr;
        hr = dialog->GetResults(&items);
        if (SUCCEEDED(hr) && items) {
            DWORD count = 0;
            items->GetCount(&count);
            for (DWORD index = 0; index < count; ++index) {
                IShellItem* item = nullptr;
                if (SUCCEEDED(items->GetItemAt(index, &item))) {
                    CollectShellItem(item);
                    item->Release();
                }
            }
            items->Release();
        }
    }
    dialog->Release();
    return hr;
}

HRESULT RunModernSave() {
    IFileSaveDialog* dialog = nullptr;
    HRESULT hr = CoCreateInstance(CLSID_FileSaveDialog, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
    if (FAILED(hr)) return hr;
    const COMDLG_FILTERSPEC filters[] = {{L"JSON", L"*.json"}};
    dialog->SetDefaultExtension(L"json");
    dialog->SetFileTypes(1, filters);
    dialog->SetFileName(L"octane-report.json");
    AppendEvent("api-show-enter", "IFileSaveDialog::Show");
    hr = dialog->Show(DialogOwner());
    AppendEvent("api-show-return", HresultHex(hr));
    if (SUCCEEDED(hr)) {
        IShellItem* item = nullptr;
        hr = dialog->GetResult(&item);
        if (SUCCEEDED(hr) && item) {
            CollectShellItem(item);
            item->Release();
        }
    }
    dialog->Release();
    return hr;
}

HRESULT RunLegacy(bool save) {
    std::vector<wchar_t> buffer(32768, L'\0');
    OPENFILENAMEW details{};
    details.lStructSize = sizeof(details);
    details.hwndOwner = DialogOwner();
    details.lpstrFile = buffer.data();
    details.nMaxFile = static_cast<DWORD>(buffer.size());
    details.lpstrFilter = save ? L"JSON\0*.json\0\0" : L"All Files\0*.*\0\0";
    details.lpstrTitle = save ? L"Octane legacy save" : L"Octane legacy open";
    details.Flags = OFN_EXPLORER | OFN_PATHMUSTEXIST | (save ? OFN_OVERWRITEPROMPT : (OFN_FILEMUSTEXIST | OFN_ALLOWMULTISELECT));
    details.lpstrDefExt = save ? L"json" : nullptr;
    if (save) std::wcscpy(buffer.data(), L"octane-report.json");
    AppendEvent("api-show-enter", save ? "GetSaveFileNameW" : "GetOpenFileNameW");
    const BOOL accepted = save ? GetSaveFileNameW(&details) : GetOpenFileNameW(&details);
    g_result.extended_error = CommDlgExtendedError();
    AppendEvent("api-show-return", accepted ? "TRUE" : "FALSE");
    if (!accepted) return g_result.extended_error == 0 ? HRESULT_FROM_WIN32(ERROR_CANCELLED) : HRESULT_FROM_WIN32(g_result.extended_error);
    if (save) {
        g_result.selected_paths.emplace_back(buffer.data());
    } else {
        const std::wstring first = buffer.data();
        const wchar_t* cursor = buffer.data() + first.size() + 1;
        if (*cursor == L'\0') {
            g_result.selected_paths.push_back(first);
        } else {
            while (*cursor) {
                g_result.selected_paths.push_back(first + L"\\" + cursor);
                cursor += std::wcslen(cursor) + 1;
            }
        }
    }
    return S_OK;
}

void RunDialogCore() {
    g_dialog_thread_id = GetCurrentThreadId();
    AppendEvent("dialog-thread-start", WideToUtf8(g_options.mode));
    const bool modern = g_options.mode.rfind(L"modern-", 0) == 0;
    if (modern) {
        g_dialog_com_hresult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
        AppendEvent("dialog-com-initialize", HresultHex(g_dialog_com_hresult));
        if (FAILED(g_dialog_com_hresult)) {
            g_result.outcome = "init-failure";
            g_result.hresult = g_dialog_com_hresult;
        } else {
            g_result.hresult = g_options.mode == L"modern-open" ? RunModernOpen() : RunModernSave();
            if (g_result.hresult == HRESULT_FROM_WIN32(ERROR_CANCELLED)) g_result.outcome = "canceled";
            else if (FAILED(g_result.hresult)) g_result.outcome = "api-failure";
            else g_result.outcome = "selected";
            CoUninitialize();
        }
    } else {
        g_result.hresult = RunLegacy(g_options.mode == L"legacy-save");
        if (g_result.hresult == HRESULT_FROM_WIN32(ERROR_CANCELLED)) g_result.outcome = "canceled";
        else if (FAILED(g_result.hresult)) g_result.outcome = "api-failure";
        else g_result.outcome = "selected";
    }
    AppendEvent("dialog-thread-complete", g_result.outcome);
    g_finished = true;
}

BOOL CALLBACK CloseProbeWindows(HWND window, LPARAM) {
    DWORD process_id = 0;
    GetWindowThreadProcessId(window, &process_id);
    if (process_id == g_process_id && window != g_owner) PostMessageW(window, WM_CLOSE, 0, 0);
    return TRUE;
}

void Watchdog() {
    for (DWORD elapsed = 0; elapsed < g_options.timeout_seconds * 10 && !g_finished; ++elapsed) Sleep(100);
    if (g_finished) return;
    g_result.timed_out = true;
    g_result.outcome = "timeout";
    g_result.hresult = HRESULT_FROM_WIN32(ERROR_TIMEOUT);
    AppendEvent("stage-timeout", std::to_string(g_options.timeout_seconds));
    EnumWindows(CloseProbeWindows, 0);
    for (int wait = 0; wait < 20 && !g_finished; ++wait) Sleep(100);
    if (!g_finished) {
        WriteSummary();
        TerminateProcess(GetCurrentProcess(), 124);
    }
}

LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_CREATE: AppendEvent("owner-created"); return 0;
        case WM_SHOWWINDOW: AppendEvent("owner-show", wparam ? "visible" : "hidden"); break;
        case WM_ACTIVATE: AppendEvent("owner-activate", LOWORD(wparam) == WA_INACTIVE ? "inactive" : "active"); break;
        case WM_ENABLE: AppendEvent("owner-enable", wparam ? "enabled" : "disabled"); break;
        case WM_SETFOCUS: AppendEvent("owner-focus", "set"); break;
        case WM_KILLFOCUS: AppendEvent("owner-focus", "lost"); break;
        case WM_PAINT: {
            PAINTSTRUCT paint{};
            HDC dc = BeginPaint(window, &paint);
            RECT rect{};
            GetClientRect(window, &rect);
            SetBkMode(dc, TRANSPARENT);
            SetTextColor(dc, RGB(25, 47, 62));
            const std::wstring text = L"Octane native file-dialog probe\nMode: " + g_options.mode +
                L"\nThread: " + g_options.thread_mode + L"; owner: " + g_options.owner_mode;
            DrawTextW(dc, text.c_str(), -1, &rect, DT_CENTER | DT_VCENTER | DT_WORDBREAK);
            EndPaint(window, &paint);
            return 0;
        }
        case kRunDialogMessage:
            RunDialogCore();
            PostMessageW(window, kDialogCompleteMessage, 0, 0);
            return 0;
        case kDialogCompleteMessage:
            WriteSummary();
            DestroyWindow(window);
            return 0;
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
        default: break;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

bool ParseArguments() {
    int count = 0;
    LPWSTR* values = CommandLineToArgvW(GetCommandLineW(), &count);
    if (!values) return false;
    for (int index = 1; index < count; ++index) {
        const std::wstring key = values[index];
        auto next = [&]() -> std::wstring { return ++index < count ? values[index] : L""; };
        if (key == L"--mode") g_options.mode = next();
        else if (key == L"--result") g_options.result_path = next();
        else if (key == L"--events") g_options.events_path = next();
        else if (key == L"--owner") g_options.owner_mode = next();
        else if (key == L"--thread") g_options.thread_mode = next();
        else if (key == L"--timeout-seconds") g_options.timeout_seconds = std::wcstoul(next().c_str(), nullptr, 10);
        else { LocalFree(values); return false; }
    }
    LocalFree(values);
    const bool valid_mode = g_options.mode == L"modern-open" || g_options.mode == L"modern-save" ||
        g_options.mode == L"legacy-open" || g_options.mode == L"legacy-save";
    return valid_mode && (g_options.owner_mode == L"none" || g_options.owner_mode == L"owned") &&
        (g_options.thread_mode == L"worker" || g_options.thread_mode == L"ui") &&
        g_options.timeout_seconds >= 5 && g_options.timeout_seconds <= 300;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int show) {
    if (!ParseArguments()) return 2;
    EnsureOutputDirectories();
    {
        std::ofstream truncate(WideToUtf8(g_options.events_path), std::ios::binary | std::ios::trunc);
    }
    g_process_id = GetCurrentProcessId();
    g_ui_thread_id = GetCurrentThreadId();
    g_ui_com_hresult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    WNDCLASSW window_class{};
    window_class.hInstance = instance;
    window_class.lpfnWndProc = WindowProc;
    window_class.lpszClassName = kWindowClass;
    window_class.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    window_class.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    if (!RegisterClassW(&window_class)) return 3;

    const std::wstring title = L"Octane File Dialog Probe - " + g_options.mode;
    g_owner = CreateWindowExW(0, kWindowClass, title.c_str(), WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 720, 420, nullptr, nullptr, instance, nullptr);
    if (!g_owner) return 4;
    ShowWindow(g_owner, show);
    UpdateWindow(g_owner);
    AppendEvent("probe-start", "owner visible before dialog invocation");

    std::thread dialog_thread;
    if (g_options.thread_mode == L"worker") {
        dialog_thread = std::thread([] {
            Sleep(750);
            RunDialogCore();
            PostMessageW(g_owner, kDialogCompleteMessage, 0, 0);
        });
    } else {
        PostMessageW(g_owner, kRunDialogMessage, 0, 0);
    }
    std::thread watchdog(Watchdog);

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    if (dialog_thread.joinable()) dialog_thread.join();
    g_finished = true;
    if (watchdog.joinable()) watchdog.join();
    if (SUCCEEDED(g_ui_com_hresult)) CoUninitialize();
    return g_result.outcome == "selected" || g_result.outcome == "canceled" ? 0 : 1;
}
