# Reference — flutter / dart Command Cheatsheet

Snapshot: Flutter **3.50.0** / Dart **3.14.0**. Commands are the same
on PowerShell, bash, and zsh unless noted. Run project commands from
the project root (where `pubspec.yaml` lives).

## Health and setup

| Command | What it does |
|---|---|
| `flutter doctor` | Checks every toolchain (add `-v` for the full detail) — first stop for any setup problem |
| `flutter doctor --android-licenses` | Accepts Android SDK licences (fixes a common doctor failure) |
| `flutter --version` | Flutter, framework, engine, and Dart versions in one shot |
| `flutter channel` | Shows channels; `flutter channel stable` switches to stable |
| `flutter upgrade` | Upgrades Flutter on the current channel |
| `flutter downgrade` | Steps back one release on the current channel (undo an upgrade) |
| `flutter config` | Lists/sets config (e.g. `--enable-windows-desktop` was needed in old versions; desktop is on by default now) |
| `flutter devices` | Lists connected devices/emulators/desktops Chrome included |
| `flutter emulators` | Lists AVDs; `--launch <id>` starts one |

## Create

| Command | What it does |
|---|---|
| `flutter create my_app` | New app project with default template and all default platforms |
| `flutter create --empty my_app` | Minimal project — no counter demo, just a bare app skeleton |
| `flutter create --platforms=windows,android my_app` | Only the named platforms' runners |
| `flutter create --org com.example my_app` | Sets the organisation (drives Android applicationId / bundle id prefixes) |
| `flutter create --project-name my_app .` | Creates into the current folder |
| `flutter create --platforms=windows .` | Adds the Windows runner to an **existing** project |
| `flutter create -t package my_lib` / `-t plugin my_plugin` | Library package / plugin templates instead of an app |

## Run and debug

| Command | What it does |
|---|---|
| `flutter run` | Debug run on the default device (hot reload: `r`, hot restart: `R`, quit: `q`) |
| `flutter run -d windows` | Run on Windows desktop (`-d chrome`, `-d <device-id>` likewise) |
| `flutter run --profile` | Profile-mode run — the only honest way to measure performance (guide 13) |
| `flutter run --release` | Release-mode run on a device (no profiling hooks) |
| `flutter run --flavor dev -t lib/main_dev.dart` | Run a flavor entry point (guide 12) |
| `flutter run --dart-define=ENV=dev` | Passes compile-time config (guide 12) |
| `flutter attach` | Attaches to an already-running app for hot reload/debug |
| `flutter logs` | Streams logs from a running app/device |

## Build

| Command | Output |
|---|---|
| `flutter build appbundle --release` | Android App Bundle → `build/app/outputs/bundle/release/app.aab` (Play upload, guide 10) |
| `flutter build apk --release` | Android APK (direct distribution/testing; `--split-per-abi` for per-ABI APKs) |
| `flutter build windows --release` | Windows app → whole `build\windows\x64\runner\Release\` folder (guide 09) |
| `flutter build macos --release` | macOS `.app` (macOS host only) |
| `flutter build linux --release` | Linux bundle folder (Linux host only) |
| `flutter build ios --release` / `flutter build ipa` | iOS build / distributable archive (macOS host only) |
| `flutter build web` | Web JS build → `build/web/` |
| `flutter build web --wasm` | Web WebAssembly build (preferred when dependencies allow, guide 11) |
| any build + `--flavor prod` | Builds that flavor where the platform supports flavors |

## Analyse, format, lint

| Command | What it does |
|---|---|
| `flutter analyze` | Static analysis with your lint set — must be clean before "done" |
| `dart format .` | Formats all Dart in the project (add `--set-exit-if-changed` in CI) |
| `dart fix --apply` | Applies automated fixes for common lint/deprecation issues |
| `flutter analyze --suggestions` | Environment/dependency suggestions for the project (where available) |

## Test

| Command | What it does |
|---|---|
| `flutter test` | All unit + widget tests under `test/` |
| `flutter test test/widget_test.dart` | One test file |
| `flutter test --update-goldens` | Regenerates golden (screenshot) test baselines — review the diff before committing |
| `flutter test integration_test/` | Integration tests on a device (with the SDK `integration_test` package) |
| `flutter test --coverage` | Coverage into `coverage/lcov.info` |
| `dart test` | Tests for a pure-Dart package (no Flutter) |

## Packages (pub)

| Command | What it does |
|---|---|
| `flutter pub add http` | Adds a dependency at the latest compatible version (writes pubspec + lockfile) |
| `flutter pub add --dev build_runner` | Adds a dev dependency |
| `flutter pub get` | Resolves/downloads dependencies after editing pubspec by hand |
| `flutter pub outdated` | What is behind, what is resolvable, what is blocked — run at every upgrade |
| `flutter pub upgrade` | Upgrades within pubspec constraints |
| `flutter pub upgrade --major-versions` | Upgrades across major versions (rewrites constraints — review the diff) |
| `flutter pub deps` | The resolved dependency tree (who pulled in what) |

## Code generation

| Command | What it does |
|---|---|
| `dart run build_runner build --delete-conflicting-outputs` | One-shot generation (freezed, json_serializable, riverpod_generator, go_router_builder) |
| `dart run build_runner watch --delete-conflicting-outputs` | Regenerates as you edit — the day-to-day form |
| `dart run msix:create` | Builds an MSIX from the Windows Release output (guide 09) |

## DevTools and performance

| Command | What it does |
|---|---|
| `flutter devtools` | Launches DevTools (also offered automatically by the IDE / `flutter run`) |
| `flutter run --profile` then open DevTools | The performance workflow from guide 13 |
| `flutter screenshot` | Captures a screenshot from a connected device |

## Housekeeping

| Command | What it does |
|---|---|
| `flutter clean` | Deletes `build/` and `.dart_tool/` — first fix for "impossible" build errors |
| `flutter pub cache repair` | Re-downloads pub cache entries (corrupt cache fix) |
| `flutter precache` | Pre-downloads platform artifacts for offline work |
