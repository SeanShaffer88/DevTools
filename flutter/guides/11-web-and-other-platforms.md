# 11 — Web and Other Platforms

Flutter targets six platforms from one codebase, but they are not all
equal and they do not all build from the same machine. This guide
covers web properly, then the honest state of iOS, macOS, and Linux.

**The one rule that governs everything below: a desktop or mobile app
builds only on its own operating system.** Windows apps build on
Windows, macOS and iOS apps build on macOS, Linux apps build on Linux.
Android and web are the exceptions — they build from any host.

Snapshot: **Flutter 3.50.0 / Dart 3.14.0**; Windows, macOS, and Linux
desktop are all **stable**.

## Flutter web

### The two renderers/build outputs

Current Flutter web builds compile your Dart to either:

- **WebAssembly (Wasm)** — the preferred modern target: better
  performance, smaller/faster code via Dart's Wasm compiler plus
  Skwasm rendering. Some packages and browser APIs are not yet
  Wasm-compatible, which is the usual reason a project cannot use it.
- **JavaScript** — the long-standing target: Dart compiled to JS with
  the CanvasKit (or HTML-era) rendering approach. Maximum
  compatibility, the fallback when Wasm blocks you.

```powershell
flutter build web --wasm        # Wasm build (preferred when it works)
flutter build web               # JavaScript build
flutter run -d chrome           # develop against Chrome
```

Output lands in `build/web/` — a static site folder you can host
anywhere (any static host, an S3 bucket, your own server). Try the
Wasm build first; if a dependency blocks it, the JS build is a
perfectly respectable ship, not a failure.

### Web realities to design for

- **It is an app, not a document.** Flutter web renders to canvas;
  text selection, find-in-page, screen-reader semantics, and SEO
  behave like an app platform, not like HTML pages. For content-first
  sites, Flutter web is usually the wrong tool; for app-like tools,
  dashboards, and companions to your mobile app, it is a good one.
- **URLs and navigation** need deliberate setup — use a routing
  package (see [guide 05](05-navigation-and-routing.md)) with URL
  strategies configured, or the back button will embarrass you.
- **Startup weight matters.** First load downloads the engine; keep
  the initial screen light, defer heavy assets, and measure on a
  throttled connection, not on localhost.
- **Browser testing is part of the platform:** Chrome is the dev
  default, but check Firefox and Safari before calling it done —
  Wasm support and performance differ per browser.

## iOS

- **Builds only on macOS**, with Xcode. There is no way around this;
  teams without a Mac use a Mac CI runner.
- Signing, provisioning, and App Store submission follow Apple's
  normal rules — Flutter does not abstract them away. Budget real
  time for the first submission (certificates, App Store Connect,
  review).
- `flutter build ipa` produces the archive for distribution once
  signing is configured in Xcode.

## macOS

- **Stable**, builds only on macOS. The runner is a native macOS app;
  distribution is a `.app` bundle — ship it inside a DMG or via the
  Mac App Store.
- Store distribution requires sandboxing and entitlements; a
  sandboxed build can break file-access features that worked in a
  loose build, so test the exact distribution build.
- Window/tray behaviour uses the same community packages as Windows
  (see [guide 09](09-windows-desktop.md)) — still community, not
  Flutter-team.

## Linux

- **Stable**, builds only on Linux. Needs the GTK/CMake/Ninja
  toolchain (`flutter doctor` lists the packages for your distro).
- Output is a bundle folder (binary + `lib/` + `data/`), shipped as a
  tarball, a distro package, or a Snap/Flatpak if you want store-style
  distribution. Like Windows, **ship the whole bundle folder**, not
  just the binary.
- The audience is smaller but the platform is well behaved — if your
  users are on Linux, the incremental cost over the other desktops is
  mostly testing.

## ChromeOS

ChromeOS can be both a **host** (Linux container running the Flutter
SDK for development) and an **Android target** (Flutter Android apps
run on Chromebooks). Treat Chromebook support as part of Android
testing: check keyboard/mouse, resizable windows, and large-screen
layouts rather than assuming phone-shaped behaviour.

## Choosing platforms honestly

| Platform | Stable? | Builds on | Distribution shape |
|---|---|---|---|
| Android | Yes | Any host | AAB via Play (guide 10) |
| iOS | Yes | macOS only | IPA via App Store |
| Windows | Yes | Windows only | Release folder / MSIX (guide 09) |
| macOS | Yes | macOS only | .app in DMG / Mac App Store |
| Linux | Yes | Linux only | Bundle folder / package / Snap / Flatpak |
| Web | Yes | Any host | Static files from `build/web/` |

Supporting a platform is a testing commitment, not a checkbox: every
platform you enable needs its build in CI (on the right OS runner),
its release shape tested, and its quirks in your checklists. Start
with the platforms your users are actually on; adding one later with
`flutter create --platforms=… .` is routine.

## Checklist

- [ ] Web: Wasm build tried; JS fallback only for a named reason
- [ ] Web: routing/URLs and a non-Chrome browser checked
- [ ] Each desktop OS builds on its own OS runner in CI
- [ ] iOS/macOS signing and entitlements tested in the distribution build
- [ ] Linux/Windows whole-bundle (not single-binary) distribution verified
