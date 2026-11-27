# 12 — Flavors and Configuration

A **flavor** (build configuration) is a named variant of your app —
`dev`, `staging`, `prod` — with its own app id, name, icon, and
settings, built from the same code. This guide covers how flavors
actually work per platform, and the simpler configuration tools
(`--dart-define`) that solve half the problems people reach for
flavors to solve.

Snapshot: **Flutter 3.50.0**. Platform support differs and matters:
Android flavors are mature; **Windows flavors need Flutter 3.47+**;
iOS/macOS flavors ride Xcode schemes/configurations.

## First: do you need flavors, or just configuration?

| Need | Tool |
|---|---|
| Different API URL / keys per environment, same app | `--dart-define` (below) — no flavor needed |
| Dev build installable next to prod on one device | Flavor (separate applicationId / bundle id) |
| Different app name/icon per environment | Flavor |
| White-label: same app, different branding per client | Flavor (+ per-flavor assets) |
| Feature toggles inside one build | Plain config in code / remote config — not flavors |

Flavors cost build-matrix time on every platform you support. Take
the cheaper tool when it does the job.

## --dart-define: compile-time configuration

```powershell
flutter run --dart-define=API_BASE=https://dev.example.com --dart-define=ENV=dev
flutter build appbundle --dart-define=API_BASE=https://api.example.com --dart-define=ENV=prod
```

Read it in code with the `String.fromEnvironment` family:

```dart
abstract final class AppConfig {
  static const env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const apiBase = String.fromEnvironment('API_BASE');
  static const isProd = env == 'prod';
}
```

Rules:

- Values are **compile-time constants**, baked into the build. They
  are not secrets — anyone with the binary can extract them. API
  *base URLs* and environment names are fine; private keys are not
  (there is no safe place for a private key inside a shipped app).
- For many values, use a JSON file instead of a long command line:
  `--dart-define-from-file=config/dev.json`.
- Keep one `AppConfig` as the only reader of `fromEnvironment`, so
  the rest of the app depends on a normal Dart class (testable,
  mockable) instead of scattered constants.

## The appFlavor constant

When flavors exist, Flutter/Gradle sets the flavor name at build
time and exposes it in Dart:

```dart
import 'package:flutter/foundation.dart';

// The flavor this build was compiled with, e.g. 'prod'; null if none.
final flavor = appFlavor;
```

Use it for flavour-level decisions (banner in dev builds, logging
level) — through your config class, not sprinkled across widgets.

## Android flavors (Gradle product flavors)

Defined in `android/app/build.gradle.kts`:

```kotlin
flavorDimensions += "env"
productFlavors {
    create("dev") {
        dimension = "env"
        applicationIdSuffix = ".dev"
        resValue("string", "app_name", "My App Dev")
    }
    create("prod") {
        dimension = "env"
    }
}
```

Build and run by name:

```powershell
flutter run --flavor dev -t lib/main_dev.dart
flutter build appbundle --release --flavor prod -t lib/main_prod.dart
```

Separate entry points (`main_dev.dart`, `main_prod.dart`) are the
standard pattern: each sets up its environment, then calls a shared
`runApp` with the real app widget. The `applicationIdSuffix` is what
lets dev and prod install side by side.

## iOS / macOS flavors

On Apple platforms a flavor = an **Xcode scheme + build
configuration** pair (dev/staging/prod schemes, each with its own
bundle id, name, and icon), created in Xcode. Flutter then honours
`--flavor <scheme name>`. It is more manual than Android's — budget
setup time, and name schemes exactly as you pass them on the command
line.

## Windows flavors

Windows flavor support arrived in **Flutter 3.47** (this pack's
snapshot, 3.50, includes it). Flavors are declared for the Windows
runner so `--flavor` selects the variant's name/icon/output. If you
are on an older Flutter, Windows has exactly one configuration —
upgrade rather than inventing workarounds.

## Icons per flavor

Different icons per flavor is the visible half of the pattern:

- Android: per-flavor `res` folders
  (`src/dev/res/mipmap-…`, `src/prod/res/mipmap-…`) — or generate all
  of them with the launcher-icons tooling per flavor config.
- Apple: separate app-icon asset catalogs per configuration, chosen
  by the scheme's build settings.
- Desktop: per-flavor icon files selected by the runner config.

A dev icon that is visibly different (banner, different colour) is a
safety feature, not decoration: it stops "I tested prod data with the
dev build" accidents.

## Putting it together: a sane default setup

- **Two flavors max to start** (`dev`, `prod`); add `staging` only
  when a real staging backend exists.
- Entry points per flavor, one shared app widget, one `AppConfig`.
- Environment values via `--dart-define-from-file`, one JSON per
  flavor, checked into the repo **without secrets** (public URLs and
  names only).
- CI builds each flavor on the platforms that support it, and the
  release pipeline only ever ships `prod` built from a clean checkout.

## Checklist

- [ ] Flavor-vs-dart-define decision made deliberately per need
- [ ] No secrets in dart-define values or flavor config files
- [ ] Dev and prod install side by side with visibly different icons
- [ ] One `AppConfig` class owns all environment reads
- [ ] Windows flavors only relied on with Flutter 3.47+
