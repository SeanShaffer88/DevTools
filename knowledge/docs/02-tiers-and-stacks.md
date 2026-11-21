# 02 — Tiers and stacks

Every project is classified into exactly one tier. Classification is
autonomous: inspect the project's files, declare the tier and the
rationale, and record both durably — a `.project-tier` file plus a
`## Project Manifest` block in the repo. Ask the owner only when the
evidence genuinely contradicts itself.

## The tiers

| Tier | What it is | Release shape |
|---|---|---|
| t1a | Headless daemons and services | Setup.exe + Portable.zip + SHA256SUMS.txt |
| t1b | GUI / tray utilities | Setup.exe + Portable.zip + SHA256SUMS.txt |
| t2 | CLI tools and libraries | Per-target-triple zips + SHA256SUMS.txt |
| t3 | Rich-render desktop apps | Setup.exe + Portable.zip + SHA256SUMS.txt |
| t4 | WoW addons | Addon zip + SHA256SUMS.txt (see the WowDev repo for t4 craft) |
| t5 | Android apps | apk / aab + SHA256SUMS.txt (see the GodotDevTools repo for the Godot route) |

Tier rules are inert outside their tier: a t2 library does not carry
t1b tray rules, and a t4 addon follows its platform's own format
rules where those mandate placement or shape.

## Primary stack

**Rust with `windows-sys`, or C++20/MSVC with a static CRT** —
native Win32 / Common Controls v6, Slint, or Direct2D for UI;
event-driven (no polling), low-priority workers, bounded caches,
raw Win32 preferred over heavy wrappers; RAII handle management;
native tray, theme, DPI, and single-instance (GUID mutex) handling.

Rust release profile: `opt-level` z or s, `lto`, `codegen-units = 1`,
`panic = abort`, stripped. `unwrap`/`expect` are banned in hot paths
and untrusted-input code; justified exceptions live in main/tests
only.

## Sanctioned alternates (hard publish constraints)

An alternate is compliant only inside its constraints:

| Alternate | Constraints |
|---|---|
| C# / .NET | Self-contained **single-file** publish only; never framework-dependent |
| WinUI 3 | **Banned** |
| Tauri 2.x | System WebView2 only; no remote content |
| Flutter | `windows-release` builds only |
| Python | Nuitka-compiled only |
| PowerShell | Compiled XAML form only |

A stack the owner specifies directly in a project brief supersedes
the default for that project (an Electron app briefed as Electron
ships as Electron). Record the deviation in the project's rule
sheet.

## Budgets (Class A — the owner confirms changes in-session)

- RAM: under 15 MB for t1a; under 40 MB for t1b/t3 — each with a
  stated measurement basis in the project docs.
- Per-stack RAM budgets apply to the alternates as recorded in the
  contract's classification companion.
- Performance regressions over 10% in a core workflow block a
  release unless waived in writing with a follow-up.
