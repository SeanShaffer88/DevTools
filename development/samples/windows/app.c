#define UNICODE
#define _UNICODE
#include <windows.h>
static unsigned count;
static HWND label;
static LRESULT CALLBACK procedure(HWND window, UINT message, WPARAM w, LPARAM l) {
    if (message == WM_CREATE) {
        label = CreateWindowW(L"STATIC", L"Count: 0", WS_CHILD|WS_VISIBLE, 24, 24, 230, 30, window, NULL, NULL, NULL);
        CreateWindowW(L"BUTTON", L"Increment", WS_CHILD|WS_VISIBLE|WS_TABSTOP|BS_DEFPUSHBUTTON, 24, 70, 150, 38, window, (HMENU)1, NULL, NULL);
        return 0;
    }
    if (message == WM_COMMAND && LOWORD(w) == 1) {
        wchar_t text[64];
        if (count < 1000000) ++count;
        const WCHAR prefix[] = L"Count: ";
        WCHAR digits[10]; unsigned value = count; unsigned length = 0; unsigned at = 0;
        for (; at < 7; ++at) text[at] = prefix[at];
        do { digits[length++] = (WCHAR)(L'0' + value % 10); value /= 10; } while (value);
        while (length) text[at++] = digits[--length];
        text[at] = 0;
        SetWindowTextW(label, text);
        return 0;
    }
    if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(window, message, w, l);
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE previous,PWSTR command,int show) {
    (void)previous; (void)command;
    WNDCLASSW type={0}; type.lpfnWndProc=procedure;type.hInstance=instance;type.lpszClassName=L"DevToolsOfflineSample";
    type.hCursor=LoadCursorW(NULL,IDC_ARROW);type.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);
    if (!RegisterClassW(&type)) return 1;
    HWND window=CreateWindowW(type.lpszClassName,L"Offline Native Sample",WS_OVERLAPPEDWINDOW,CW_USEDEFAULT,CW_USEDEFAULT,360,210,NULL,NULL,instance,NULL);
    if (!window) return 2;
    ShowWindow(window,show);
    MSG message;
    int status;
    while ((status=GetMessageW(&message,NULL,0,0))>0) { if (!IsDialogMessageW(window,&message)) { TranslateMessage(&message); DispatchMessageW(&message); } }
    return status<0?3:(int)message.wParam;
}

void WINAPI WinMainCRTStartup(void) {
    ExitProcess((UINT)wWinMain(GetModuleHandleW(NULL), NULL, NULL, SW_SHOWDEFAULT));
}
