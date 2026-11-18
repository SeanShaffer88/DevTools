# 01 — Getting Started and the Toolchain

Flutter is Google's UI toolkit for building apps for Android, iOS,
Windows, macOS, Linux, and the web from one Dart codebase. This guide
gets a Windows machine from nothing to a running app, and explains
how to keep the toolchain pinned, healthy, and up to date.

Official starting point: https://docs.flutter.dev/get-started/install

## The versions in this guide

- **Flutter 3.50.0 stable** (released 2026-11-11) — this is the SDK
  version everything here assumes.
- **Dart 3.14.0** is the Dart version *bundled inside* Flutter 3.50.0.
- **Standalone Dart is 3.14.1** — that is a separate download for
  server/CLI Dart. Do not confuse the two numbers: inside a Flutter
  project you always use the Dart that came with Flutter, never a
  separately installed Dart.

Check what you actually have at any time:

```powershell
flutter --version
dart --version   # only meaningful inside / via the Flutter SDK
```

## Channels: which Flutter you are tracking

Flutter ships on channels, which are just git branches of the SDK:

| Channel | Cadence | Use it for |
|---|---|---|
| `stable` | Quarterly releases | Almost everyone, almost always |
| `beta` | Monthly | Previewing the next stable, CI early-warning |
| `main` | Continuous | Flutter contributors, checking if a bug is already fixed |

Switch and upgrade with:

```powershell
flutter channel stable
flutter upgrade
```

Stay on `stable` unless you have a named reason not to. A bug that
only reproduces on `beta` or `main` is a preview bug, not your app's
bug yet.

## Install route 1 (recommended): VS Code

On Windows this is the route the Flutter team recommends:

1. Install Visual Studio Code.
2. Install the **Flutter extension** for VS Code (it brings the Dart
   extension with it).
3. Open the Command Palette (`Ctrl+Shift+P`) and run
   **Flutter: New Project**. VS Code will offer to locate or download
   the Flutter SDK for you — accept, and pick a permanent home for
   it, for example `C:\dev\flutter`.
4. Let the extension add the SDK to your `PATH` when it asks.

Why this route wins: the extension handles SDK placement, PATH, and
first-run prompts, and it is the setup the official docs test first.

## Install route 2: manual SDK zip

1. Download the Flutter SDK zip for the current stable from
   https://docs.flutter.dev/get-started/install/windows — there is
   **no MSI installer**; anyone offering one is not official.
2. Unzip it to a folder you own, e.g. `C:\dev\flutter`.
   - Do **not** put it in `C:\Program Files` (permission prompts).
   - Do **not** put it in a path with spaces if you can avoid it.
   - Avoid very deep paths: Windows long-path limits bite Flutter
     builds. Keep the SDK and your projects on short paths such as
     `C:\dev\...`.
3. Add `C:\dev\flutter\bin` to your user `PATH`.
4. Open a **new** terminal and run `flutter doctor` (below).

## Pinning an exact SDK version

The Flutter SDK is a git checkout, so a version is a commit:

```powershell
cd C:\dev\flutter
git fetch
git checkout 3.50.0      # the tag for Flutter 3.50.0 stable
flutter doctor
```

Teams that need every machine and CI runner on the same Flutter
should pin this way (or with a version-manager tool) instead of
letting each developer float on "latest stable". Record the pinned
version in the project readme. `flutter upgrade` moves you forward
again when you deliberately unpin.

## flutter doctor: the health check

`flutter doctor` is the single most important command in Flutter.
It checks every target you might build for and tells you, in plain
text, what is missing. Run it verbosely when something looks wrong:

```powershell
flutter doctor -v
```

Work through it target by target — you only need the targets you
actually ship to.

### For Android

You need, all from Android Studio's SDK Manager:

- Android Studio itself (it provides the SDK manager and emulator UI)
- **SDK Platform for API 36** (the current compile target)
- Android SDK Command-line Tools (latest)
- Android Emulator
- Android SDK Platform-Tools (`adb` lives here)
- CMake
- NDK (Side by side)

Then accept the licences and verify:

```powershell
flutter doctor --android-licenses
flutter doctor
```

Create an emulator in Android Studio's Device Manager, or check
what is connected:

```powershell
flutter emulators
flutter devices
```

### For Windows desktop

Windows desktop builds are native C++ under the hood, so you need:

- **Visual Studio** (the full IDE, not just VS Code) with the
  **"Desktop development with C++"** workload installed.

That one workload is the whole requirement — without it, `flutter
doctor` reports the Windows toolchain as broken and desktop builds
fail before your Dart code is even read.

### For the web

A current Chrome is enough for development. No extra SDK is needed.

## Your first app

```powershell
flutter create my_app
cd my_app
flutter run
```

Useful flags while learning:

```powershell
flutter run -d windows    # pick the target explicitly
flutter run -d chrome
flutter devices           # list everything you can run on
```

Inside a running app: `r` = hot reload (keep state, apply code),
`R` = hot restart (reset state), `q` = quit. Hot reload is the
feature that makes Flutter development feel fast — structure your
work around it.

## Keeping the toolchain healthy

- Run `flutter doctor` after every SDK, Android Studio, or Visual
  Studio update.
- Run `flutter pub get` after changing `pubspec.yaml` or switching
  branches — stale `.dart_tool` state causes confusing errors.
- `flutter clean` deletes build output and forces a full rebuild.
  It fixes a surprising share of "impossible" build errors.
- Upgrade on purpose, on `stable`, and read the release notes at
  https://docs.flutter.dev/release/release-notes before you do —
  then run your tests before committing the upgrade.

## Common first-day problems

| Symptom | Likely cause |
|---|---|
| `flutter` not recognised in a new terminal | `bin` not on `PATH`, or the terminal predates the PATH change |
| Doctor: Android licence status unknown | Run `flutter doctor --android-licenses` |
| Doctor: Visual Studio incomplete | The C++ desktop workload is missing |
| Build fails with very long file paths | SDK or project path is too deep — move to a short path |
| Wrong Dart version reported | A standalone Dart install is shadowing Flutter's bundled Dart |

## Next

Language next: [02-dart-language-for-flutter.md](02-dart-language-for-flutter.md),
then UI: [03-widgets-and-ui.md](03-widgets-and-ui.md).
