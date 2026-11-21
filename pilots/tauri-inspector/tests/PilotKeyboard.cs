using System;
using System.Runtime.InteropServices;

public static class PilotKeyboard {
    public static string CaptionDiagnostics { get; private set; }

    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW")]
    static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint message, UIntPtr wParam,
        IntPtr lParam, uint flags, uint timeout, out UIntPtr result);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] static extern uint SendInput(uint count, Input[] inputs, int size);

    [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after,
        int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll", EntryPoint = "GetMonitorInfoW")]
    static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(
        IntPtr window, System.Text.StringBuilder name, int maxCount);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr window, uint command);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr window, int index);
    [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr dialog, int id);
    [DllImport("user32.dll")] static extern bool IsChild(IntPtr parent, IntPtr child);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, WindowVisitor visitor, IntPtr state);
    [DllImport("user32.dll")] static extern bool IsWindowEnabled(IntPtr window);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(
        IntPtr window, System.Text.StringBuilder title, int maxCount);
    delegate bool WindowVisitor(IntPtr window, IntPtr state);
    [DllImport("user32.dll")] static extern bool EnumWindows(WindowVisitor visitor, IntPtr state);
    [DllImport("user32.dll")] static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] static extern bool GetGUIThreadInfo(uint threadId, ref GuiThreadInfo info);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);

    [StructLayout(LayoutKind.Sequential)] struct Rect { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct GuiThreadInfo {
        public uint size, flags;
        public IntPtr active, focus, capture, menuOwner, moveSize, caret;
        public Rect caretRect;
    }
    [StructLayout(LayoutKind.Sequential)] struct MonitorInfo {
        public uint size; public Rect monitor, work; public uint flags;
    }

    [StructLayout(LayoutKind.Sequential)] struct Keyboard {
        public ushort key, scan; public uint flags, time; public UIntPtr extra;
    }
    [StructLayout(LayoutKind.Sequential)] struct Mouse {
        public int x, y; public uint data, flags, time; public UIntPtr extra;
    }
    [StructLayout(LayoutKind.Explicit)] struct InputData {
        [FieldOffset(0)] public Keyboard keyboard;
        [FieldOffset(0)] public Mouse mouse;
    }
    [StructLayout(LayoutKind.Sequential)] struct Input {
        public uint type; public InputData data;
    }
    public static uint WindowProcess(IntPtr hwnd) {
        uint owner;
        return GetWindowThreadProcessId(hwnd, out owner) == 0 ? 0 : owner;
    }
    public static bool RequestForeground(IntPtr window, uint owner) {
        return WindowProcess(window) == owner && SetForegroundWindow(window);
    }

    public static bool WaitForActivationMessage(IntPtr window, uint owner, uint timeout) {
        const uint wmNull = 0;
        const uint abortIfHung = 0x0002;
        const uint errorOnExit = 0x0020;
        UIntPtr unused;
        return WindowProcess(window) == owner &&
            SendMessageTimeout(window, wmNull, UIntPtr.Zero, IntPtr.Zero,
                abortIfHung | errorOnExit, timeout, out unused) != IntPtr.Zero;
    }

    static bool KeysHeld() {
        // Mouse buttons, Tab, Shift, Ctrl, Alt and both Windows keys.
        foreach (int key in new[] { 1, 2, 4, 5, 6, 9, 0x10, 0x11, 0x12, 0x5b, 0x5c }) {
            if ((GetAsyncKeyState(key) & 0x8000) != 0) return true;
        }
        return false;
    }

    static bool PointerRoutingClear(IntPtr window, uint owner) {
        const int swapButton = 23; // SM_SWAPBUTTON
        if (GetSystemMetrics(swapButton) != 0) return false;
        return ThreadPointerTrackingClear(window, owner);
    }

    static bool ThreadPointerTrackingClear(IntPtr window, uint owner) {
        uint actualOwner;
        uint thread = GetWindowThreadProcessId(window, out actualOwner);
        if (thread == 0 || actualOwner != owner) return false;
        var info = new GuiThreadInfo { size = (uint)Marshal.SizeOf(typeof(GuiThreadInfo)) };
        return GetGUIThreadInfo(0, ref info) && PointerTrackingClear(info) &&
            GetGUIThreadInfo(thread, ref info) && PointerTrackingClear(info);
    }

    static bool PointerTrackingClear(GuiThreadInfo info) {
        return info.capture == IntPtr.Zero && info.menuOwner == IntPtr.Zero &&
            info.moveSize == IntPtr.Zero;
    }

    static bool CaptionHit(IntPtr window, uint owner, Point point) {
        if (WindowProcess(window) != owner || WindowFromPoint(point) != window ||
            point.x < short.MinValue || point.x > short.MaxValue ||
            point.y < short.MinValue || point.y > short.MaxValue) return false;
        var position = unchecked((int)(((uint)(ushort)point.y << 16) | (ushort)point.x));
        UIntPtr hit;
        return SendMessageTimeout(window, 0x84, UIntPtr.Zero, new IntPtr(position),
            0x0022, 40, out hit) != IntPtr.Zero && hit.ToUInt64() == 2; // WM_NCHITTEST / HTCAPTION
    }

    public static string ClickOwnedCaption(IntPtr window, uint owner) {
        return ClickOwnedCaption(window, owner, true);
    }

    static string ClickOwnedCaption(IntPtr window, uint owner, bool allowTemporaryRaise) {
        var diagnostic = new System.Text.StringBuilder();
        diagnostic.AppendFormat("target={0};foreground={1};visible={2};minimized={3};",
            window.ToInt64(), GetForegroundWindow().ToInt64(), IsWindowVisible(window), IsIconic(window));
        CaptionDiagnostics = diagnostic.ToString();
        var inputClock = System.Diagnostics.Stopwatch.StartNew();
        while (WindowProcess(window) == owner &&
            (KeysHeld() || !PointerRoutingClear(window, owner)) && inputClock.ElapsedMilliseconds < 600) {
            System.Threading.Thread.Sleep(40);
        }
        if (WindowProcess(window) != owner || KeysHeld() || !PointerRoutingClear(window, owner)) return "UnsafeInputState";
        var previousDpi = SetThreadDpiAwarenessContext(new IntPtr(-4)); // Per-monitor aware v2
        if (previousDpi == IntPtr.Zero) return "DpiContextUnavailable";
        try {
            const uint noSize = 0x0001, noMove = 0x0002, noActivate = 0x0010,
                noOwnerZOrder = 0x0200, asyncWindowPos = 0x4000;
            var flags = noSize | noMove | noActivate | noOwnerZOrder | asyncWindowPos;
            // HWND_TOP is zero and preserves the normal z-order band.
            if (WindowProcess(window) != owner ||
                !SetWindowPos(window, IntPtr.Zero, 0, 0, 0, 0, flags))
                return "RaiseDenied";
            WaitForActivationMessage(window, owner, 100);
            var scanClock = System.Diagnostics.Stopwatch.StartNew();
            int attempts = 0, candidates = 0, occluded = 0, offWork = 0;
            string occluder = "";
            while (scanClock.ElapsedMilliseconds < 1200) {
                if (WindowProcess(window) != owner || KeysHeld() || !PointerRoutingClear(window, owner))
                    return "UnsafeInputState";
                if (GetForegroundWindow() == window) return "AlreadyForeground";
                if (IsIconic(window) || !IsWindowVisible(window)) return "WindowNotVisible";
                if (++attempts > 1) {
                    if (!SetWindowPos(window, IntPtr.Zero, 0, 0, 0, 0, flags)) return "RaiseDenied";
                }
                Rect rect;
                var monitor = MonitorFromWindow(window, 0);
                var monitorInfo = new MonitorInfo { size = (uint)Marshal.SizeOf(typeof(MonitorInfo)) };
                if (!GetWindowRect(window, out rect) || monitor == IntPtr.Zero ||
                    !GetMonitorInfo(monitor, ref monitorInfo)) return "WindowGeometryUnavailable";
                var work = monitorInfo.work;
                int left = Math.Max(rect.left, work.left), right = Math.Min(rect.right, work.right);
                diagnostic.Length = 0;
                diagnostic.AppendFormat("target={0};foreground={1};visible={2};minimized={3};rect={4},{5},{6},{7};work={8},{9},{10},{11};",
                    window.ToInt64(), GetForegroundWindow().ToInt64(), IsWindowVisible(window), IsIconic(window),
                    rect.left, rect.top, rect.right, rect.bottom, work.left, work.top, work.right, work.bottom);
                foreach (int fraction in new[] { 5, 3, 7, 1, 9 }) {
                    foreach (int offset in new[] { 8, 14, 20, 28, 38, 50 }) {
                          if (scanClock.ElapsedMilliseconds >= 1200) break;
                        var point = new Point { x = left + (right - left) * fraction / 10, y = rect.top + offset };
                        if (left >= right || point.y < work.top || point.y >= work.bottom || point.y >= rect.bottom) {
                            offWork++; continue;
                          }
                    candidates++;
                    var hitWindow = WindowFromPoint(point);
                    if (hitWindow != window) {
                        occluded++;
                        if (occluder.Length == 0) {
                            var cls = new System.Text.StringBuilder(128);
                            GetClassName(hitWindow, cls, cls.Capacity);
                            Rect cover;
                            GetWindowRect(hitWindow, out cover);
                            occluder = String.Format("coverHwnd={0};coverPid={1};coverClass={2};coverTopmost={3};coverRect={4},{5},{6},{7};",
                                hitWindow.ToInt64(), WindowProcess(hitWindow), cls,
                                (GetWindowLongPtr(hitWindow, -20).ToInt64() & 8) != 0,
                                cover.left, cover.top, cover.right, cover.bottom);
                          }
                        continue;
                      }
                    if (!CaptionHit(window, owner, point)) continue;
                    diagnostic.AppendFormat("attempts={0};candidates={1};occluded={2};offWork={3};selected={4},{5};",
                        attempts, candidates, occluded, offWork, point.x, point.y);
                          CaptionDiagnostics = diagnostic.ToString() + occluder;
                    Point previous;
                    if (!GetCursorPos(out previous) || KeysHeld() || !SetCursorPos(point.x, point.y))
                        return "PointerUnavailable";
                    try {
                        Point current;
                        if (!GetCursorPos(out current) || current.x != point.x || current.y != point.y ||
                            KeysHeld() || !CaptionHit(window, owner, point) ||
                            WindowFromPoint(point) != window || WindowProcess(window) != owner ||
                            !GetCursorPos(out current) || current.x != point.x || current.y != point.y ||
                            KeysHeld() || !PointerRoutingClear(window, owner) || WindowFromPoint(point) != window)
                            return "CaptionChanged";
                        var clicks = new Input[2]; // INPUT_MOUSE, LEFTDOWN, LEFTUP
                        clicks[0].data.mouse.flags = 0x0002;
                        clicks[1].data.mouse.flags = 0x0004;
                        var sent = SendInput(2, clicks, Marshal.SizeOf(typeof(Input)));
                        if (sent == 1) {
                            // Finish an incomplete pair without pressing the button again.
                            SendInput(1, new[] { clicks[1] }, Marshal.SizeOf(typeof(Input)));
                          }
                        if (sent != 2) return "PointerInputDenied";
                        WaitForActivationMessage(window, owner, 100);
                        return "Sent";
                      } finally {
                        Point current;
                        if (WindowProcess(window) == owner && WindowFromPoint(point) == window &&
                            GetCursorPos(out current) && current.x == point.x && current.y == point.y)
                            SetCursorPos(previous.x, previous.y);
                      }
                    }
                }
                diagnostic.AppendFormat("attempts={0};candidates={1};occluded={2};offWork={3};", attempts, candidates, occluded, offWork);
                CaptionDiagnostics = diagnostic.ToString() + occluder;
                if (scanClock.ElapsedMilliseconds < 1200) System.Threading.Thread.Sleep(40);
            }
            if (allowTemporaryRaise && candidates > 0 && occluded == candidates &&
                WindowProcess(window) == owner && !KeysHeld() && PointerRoutingClear(window, owner)) {
                const long topmostStyle = 8;
                bool wasTopmost = (GetWindowLongPtr(window, -20).ToInt64() & topmostStyle) != 0;
                if (!wasTopmost) {
                    string priorDiagnostic = CaptionDiagnostics;
                    uint temporaryFlags = noSize | noMove | noActivate | noOwnerZOrder | asyncWindowPos;
                    try {
                        if (!SetWindowPos(window, new IntPtr(-1), 0, 0, 0, 0, temporaryFlags))
                            return "TemporaryRaiseDenied";
                        var raiseClock = System.Diagnostics.Stopwatch.StartNew();
                        while (WindowProcess(window) == owner &&
                            (GetWindowLongPtr(window, -20).ToInt64() & topmostStyle) == 0 &&
                            raiseClock.ElapsedMilliseconds < 200) System.Threading.Thread.Sleep(10);
                        if (WindowProcess(window) != owner ||
                            (GetWindowLongPtr(window, -20).ToInt64() & topmostStyle) == 0)
                            return "TemporaryRaiseUnavailable";
                        return ClickOwnedCaption(window, owner, false);
                    } finally {
                        if (WindowProcess(window) == owner) {
                            bool requested = SetWindowPos(window, new IntPtr(-2), 0, 0, 0, 0, temporaryFlags);
                            var restoreClock = System.Diagnostics.Stopwatch.StartNew();
                            while (WindowProcess(window) == owner &&
                                (GetWindowLongPtr(window, -20).ToInt64() & topmostStyle) != 0 &&
                                restoreClock.ElapsedMilliseconds < 200) System.Threading.Thread.Sleep(10);
                            bool restored = WindowProcess(window) != owner ||
                                (requested && (GetWindowLongPtr(window, -20).ToInt64() & topmostStyle) == 0);
                            CaptionDiagnostics = priorDiagnostic + "temporaryTopmost=True;restored=" +
                                restored + ";" + CaptionDiagnostics;
                            if (!restored)
                                throw new InvalidOperationException("Owned window z-order restoration failed.");
                        }
                    }
                }
            }
            return "CaptionUnavailable";
        } finally {
            SetThreadDpiAwarenessContext(previousDpi);
        }
    }


    public static bool IsOwnedFolderDialog(IntPtr dialog, IntPtr appWindow, uint owner) {
        const uint getOwner = 4;
        if (dialog == IntPtr.Zero || dialog == appWindow || WindowProcess(dialog) != owner)
            return false;
        IntPtr dialogOwner = GetWindow(dialog, getOwner);
        if (dialogOwner != IntPtr.Zero && dialogOwner != appWindow) return false;
        var className = new System.Text.StringBuilder(32);
        return GetClassName(dialog, className, className.Capacity) > 0 &&
            className.ToString() == "#32770";
    }

    public static IntPtr FindVisibleOwnedFolderDialog(IntPtr appWindow, uint owner) {
        IntPtr found = IntPtr.Zero;
        int visited = 0;
        bool complete = EnumWindows((window, state) => {
            if (++visited > 512) return false;
            if (!IsWindowVisible(window) || !IsOwnedFolderDialog(window, appWindow, owner)) return true;
            var title = new System.Text.StringBuilder(32);
            if (GetWindowText(window, title, title.Capacity) == 0 ||
                title.ToString() != "Select project folder") return true;
            if (found != IntPtr.Zero) return false;
            found = window;
            return true;
        }, IntPtr.Zero);
        return complete ? found : IntPtr.Zero;
    }

    static bool HasClass(IntPtr window, string expected) {
        var name = new System.Text.StringBuilder(32);
        return GetClassName(window, name, name.Capacity) > 0 &&
            String.Equals(name.ToString(), expected, StringComparison.OrdinalIgnoreCase);
    }

    static bool DialogReady(IntPtr dialog, IntPtr appWindow, uint owner) {
        return GetForegroundWindow() == dialog &&
            FindVisibleOwnedFolderDialog(appWindow, owner) == dialog;
    }

    static bool OwnedControl(IntPtr dialog, IntPtr control, uint owner, string expectedClass) {
        return control != IntPtr.Zero && WindowProcess(control) == owner &&
            IsChild(dialog, control) && IsWindowVisible(control) && HasClass(control, expectedClass);
    }

    public static string ConfirmOwnedFolder(IntPtr dialog, IntPtr appWindow, uint owner, string path) {
        if (String.IsNullOrEmpty(path) || path.Length > 4096 || path.IndexOf('\0') >= 0 ||
            !DialogReady(dialog, appWindow, owner)) return "DialogUnavailable";
        var folder = GetDlgItem(dialog, 1152);
        var confirm = GetDlgItem(dialog, 1);
        if (folder == IntPtr.Zero || WindowProcess(folder) != owner || !IsChild(dialog, folder))
            return "FolderControlUnavailable";

        var edit = OwnedControl(dialog, folder, owner, "Edit") ? folder : IntPtr.Zero;
        if (edit == IntPtr.Zero) {
            IntPtr found = IntPtr.Zero;
            bool ambiguous = false;
            int visited = 0;
            EnumChildWindows(folder, (candidate, state) => {
                if (++visited > 64) { ambiguous = true; return false; }
                if (OwnedControl(dialog, candidate, owner, "Edit")) {
                    if (found != IntPtr.Zero) { ambiguous = true; return false; }
                    found = candidate;
                }
                return true;
            }, IntPtr.Zero);
            if (!ambiguous) edit = found;
        }
        if (!OwnedControl(dialog, edit, owner, "Edit") ||
            !OwnedControl(dialog, confirm, owner, "Button")) return "ExpectedNativeControlsUnavailable";

        const uint setText = 0x000c, getText = 0x000d, click = 0x00f5;
        const uint flags = 0x0022; // SMTO_ABORTIFHUNG | SMTO_ERRORONEXIT
        int capacity = path.Length + 2;
        var text = Marshal.StringToHGlobalUni(path);
        var readBack = IntPtr.Zero;
        try {
            readBack = Marshal.AllocHGlobal(capacity * 2);
            UIntPtr result;
            if (!DialogReady(dialog, appWindow, owner) || !OwnedControl(dialog, edit, owner, "Edit") ||
                SendMessageTimeout(edit, setText, UIntPtr.Zero, text, flags, 200, out result) == IntPtr.Zero ||
                result == UIntPtr.Zero) return "SetFolderTextFailed";
            if (!DialogReady(dialog, appWindow, owner) || !OwnedControl(dialog, edit, owner, "Edit") ||
                SendMessageTimeout(edit, getText, new UIntPtr((uint)capacity), readBack, flags, 200, out result) == IntPtr.Zero ||
                result.ToUInt64() != (ulong)path.Length ||
                !String.Equals(Marshal.PtrToStringUni(readBack, path.Length), path, StringComparison.Ordinal))
                return "FolderTextMismatch";
            if (!DialogReady(dialog, appWindow, owner) || !OwnedControl(dialog, confirm, owner, "Button") ||
                !IsWindowEnabled(confirm)) return "ConfirmationUnavailable";
            // The controller verifies that the dialog closes and the exact path appears in the app.
            SendMessageTimeout(confirm, click, UIntPtr.Zero, IntPtr.Zero, 0x0002, 250, out result);
            return "ConfirmationSent";
        } finally {
            if (readBack != IntPtr.Zero) Marshal.FreeHGlobal(readBack);
            Marshal.FreeHGlobal(text);
        }
    }

    public static bool SendTab(IntPtr window, uint owner) {
        return SendWorkflowKey(window, owner, 0x09);
    }

    public static bool SendWorkflowKey(IntPtr window, uint owner, ushort key) {
        if (key != 0x09 && key != 0x0d && key != 0x1b) return false;
        if (KeysHeld() || (GetAsyncKeyState(key) & 0x8000) != 0) return false;
        var keys = new Input[2];
        keys[0].type = keys[1].type = 1; // INPUT_KEYBOARD
        keys[0].data.keyboard.key = keys[1].data.keyboard.key = key;
        keys[1].data.keyboard.flags = 2; // KEYEVENTF_KEYUP
        return WindowProcess(window) == owner && GetForegroundWindow() == window &&
            SendInput((uint)keys.Length, keys, Marshal.SizeOf(typeof(Input))) == keys.Length;
    }
}
