# 09 — Windows Desktop

Flutter's Windows desktop support is stable, and a Windows app is a
normal Flutter app whose runner happens to be a small native Win32/C++
program. You can only build the Windows app **on Windows** — desktop
apps always build on their own operating system (see
[guide 11](11-web-and-other-platforms.md)).

Snapshot this guide was written against: **Flutter 3.50.0 / Dart
3.14.0**. Windows **flavors** (separate build variants) need **Flutter
3.47 or newer** — see [guide 12](12-flavors-and-config.md).

## What you need installed

1. **Flutter SDK** (see [guide 01](01-getting-started-and-toolchain.md)).
2. **Visual Studio 2022** (not VS Code) with the **"Desktop development
   with C++" workload**. This is the part people miss: Flutter builds
   the Windows runner with Visual Studio's C++ toolchain and CMake.
   In the Visual Studio Installer, tick that workload; it brings the
   MSVC compiler, the Windows SDK, and CMake.
3. Run `flutter doctor` and fix everything it flags for Windows before
   you start. A clean `flutter doctor -v` for the Windows toolchain is
   the real "ready" signal.

## Creating and running a Windows app

```powershell
# New project with Windows enabled from the start
flutter create --platforms=windows,android my_app

# Add Windows to an existing project (run inside the project)
flutter create --platforms=windows .

# Run it on Windows
flutter run -d windows

# Build the release version
flutter build windows --release
```

## Where the build output lands

```
build\windows\x64\runner\Release\
```

That whole **Release folder is the app**. It contains:

| Item | What it is |
|---|---|
| `my_app.exe` | The runner executable (your app name) |
| `flutter_windows.dll` | The Flutter engine for Windows |
| `data\` | Your compiled Dart code (`app.so`), assets, fonts, and the ICU data file |
| Plugin DLLs | One `.dll` per native plugin your app uses |

**Ship the whole folder, never just the `.exe`.** The executable alone
does nothing — it needs the engine DLL and the `data\` folder next to
it. Copying only the exe is the most common Windows distribution
mistake.

## The runner folder, briefly

```
windows\
  CMakeLists.txt        Build definition for the native side
  runner\
    main.cpp            Entry point — creates the window, starts Flutter
    flutter_window.cpp  Hosts the Flutter view inside the Win32 window
    win32_window.cpp    Plain Win32 window plumbing
    Runner.rc / resources\app_icon.ico   App icon
  flutter\              Generated — do not edit by hand
```

You rarely touch `main.cpp`. The files you *will* touch: the icon
(`app_icon.ico`), and `Runner.rc` if you need to change version info or
the product name shown in Windows.

## Window size, title, and behaviour

Out of the box the window size and title come from the runner code.
For real control — minimum size, starting size, centering, title,
always-on-top, frameless, show/hide — the community standard is the
**`window_manager` package (0.7.0)**. Be clear about what it is:

- `window_manager` is a **community package** by leanflutter, **not a
  Flutter-team package**. It is widely used and actively maintained
  (0.7.0, published 2026-11-12), but it is a third-party dependency —
  check its pub.dev page before pinning it, per this pack's rules.
- It must be initialised before `runApp`, and the window shown
  explicitly, or the app can flash or start hidden.

```dart
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1100, 720),
    minimumSize: Size(720, 480),
    center: true,
    title: 'My App',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}
```

Keep window setup in one place (your composition root, see
[guide 14](14-architecture-and-project-structure.md)) so tests and
other platforms never depend on it — `window_manager` calls belong
behind a platform check (`Platform.isWindows` etc.), because the same
`main.dart` serves Android and web where they do not apply.

## System tray

There is no tray support in the Flutter SDK itself. The community
package is **`tray_manager` (0.9.0)** — also by leanflutter, also
**not a Flutter-team package** (published 2026-11-12; re-check on
pub.dev). It provides the tray icon, context menu, and click events.
Typical pattern:

- Add a tray icon with a context menu (Open / Quit).
- Decide what closing the window means: for a tray app, intercept the
  close (via `window_manager`'s listener) and **hide** instead of
  exiting; Quit in the tray menu does the real exit.
- Ship a proper `.ico` for the tray — a blurry tray icon is the first
  thing users see.

## Single instance

Flutter does not enforce a single instance for you. If a second launch
should focus the existing window instead of opening a duplicate,
handle it in the native runner or with a community single-instance
package — and decide this early, because retrofitting it after users
have two copies running is fiddly. For most tray/utility apps, single
instance is the right default.

## Distribution: folder or MSIX

Two honest options:

1. **Ship the Release folder.** Zip the whole
   `build\windows\x64\runner\Release\` folder, or feed that folder to
   any folder-based installer/packager you use (the pattern: installer
   takes a folder of files in, produces a setup program and a portable
   zip out). This is simple, transparent, and works everywhere. Users
   extract/install and run the exe; no store involved.
2. **MSIX for the Microsoft Store (or managed installs).** The
   community **`msix` package** turns the Release output into an
   `.msix`: add it as a dev dependency, put the `msix_config:` block
   in `pubspec.yaml` (identity, publisher, display name, logo), then:

   ```powershell
   dart run msix:create
   ```

   MSIX for the Store must be signed with your Store identity; a
   self-signed MSIX only installs where its certificate is trusted.
   Pick MSIX when you need the Store or clean per-user
   install/uninstall semantics — not by default.

Whichever route: bump `version:` in `pubspec.yaml` before building
(see [guide 10](10-android-release.md) — the same version string drives
every platform), test the packaged build on a machine (or VM) without
Flutter installed, and confirm the app starts from a cold folder copy.

## Windows-specific traps

- **Build only on Windows.** CI for Windows builds needs a Windows
  runner; the same repo can build Android on Linux and Windows on
  Windows in parallel jobs.
- **Debug builds are not shippable.** Always distribute `--release`
  (see build modes in [guide 13](13-performance-and-devtools.md)).
- **Antivirus false positives** happen occasionally with fresh unsigned
  executables; code signing is what fixes reputation over time, and
  the Store/MSIX route sidesteps some of it.
- **Long paths / spaces:** keep the project path short and plain
  (e.g. `C:\dev\my_app`) — native toolchains still trip over very long
  or exotic paths.

## Checklist

- [ ] Visual Studio C++ workload installed; `flutter doctor` clean
- [ ] `flutter build windows --release` succeeds
- [ ] The whole Release folder copied somewhere clean runs standalone
- [ ] Window size/minimum/title set deliberately (window_manager or runner)
- [ ] Tray behaviour (if any) decided: hide-on-close vs exit
- [ ] Single-instance behaviour decided
- [ ] Distribution route chosen: folder/installer or MSIX
