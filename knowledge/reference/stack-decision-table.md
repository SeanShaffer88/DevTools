# Stack decision table

One page: what you're building → the sanctioned route. Detail and
constraints live in [docs/02](../docs/02-tiers-and-stacks.md).

| Building | Tier | Default route | Alternates (constrained) |
|---|---|---|---|
| Background service / daemon | t1a | Rust (`windows-sys`), static CRT | C++20/MSVC |
| Tray or small GUI utility | t1b | Rust + native Win32/Slint | C# single-file publish; Tauri 2.x on system WebView2 |
| CLI tool or library | t2 | Rust | C++20; PowerShell (compiled XAML form for any UI) |
| Rich-render app (canvas, media, complex views) | t3 | Rust + Direct2D/Slint | Flutter `windows-release`; Tauri 2.x (system WebView2, no remote content) |
| WoW addon | t4 | Lua 5.1 subset against the target client's API — see the WowDev repo | — |
| Android app/game | t5 | The project's engine route — for Godot, see the GodotDevTools repo | Native Kotlin/Compose for non-game apps |

Hard rules that cut across the table:

- **WinUI 3 is banned.** Python ships only Nuitka-compiled. .NET
  ships only as a self-contained single file.
- A stack named directly in the owner's project brief supersedes
  this table for that project; record the deviation in the project
  rule sheet.
- Every desktop tier packages with SeanPak and (unless exempted)
  themes with TesselGUI.
