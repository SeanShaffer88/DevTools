# Flutter — App and Desktop Development Pack

## TL;DR

A self-contained resource pack for building apps with **Flutter and
Dart** — Android, Windows desktop, and the other platforms Flutter
targets — written for humans and for AI assistants working locally.
It holds 14 guides, quick-reference tables, ready-to-run scripts,
project templates, test fixtures, and small tools. Snapshot:
**Flutter 3.50.0 / Dart 3.14.0** (November 2026). Version-sensitive
facts carry a "re-check" note instead of pretending to be eternal.

## What is here

### Guides

| # | Guide | What it covers |
|---|---|---|
| 01 | [Getting started and toolchain](guides/01-getting-started-and-toolchain.md) | Installing Flutter, `flutter doctor`, SDK layout, IDE setup, lint baseline |
| 02 | [The Dart language](guides/02-dart-language-for-flutter.md) | Null safety, records/patterns, async, isolates — Dart as Flutter uses it |
| 03 | [Widgets and UI](guides/03-widgets-and-ui.md) | Widget tree, layout, Material 3, theming, responsive/adaptive design |
| 04 | [State management](guides/04-state-management.md) | setState → provider → Riverpod/bloc: choosing honestly per app size |
| 05 | [Navigation and routing](guides/05-navigation-and-routing.md) | Navigator, go_router, deep links, typed routes |
| 06 | [Networking and data](guides/06-networking-and-data.md) | http/dio, JSON with code generation, error handling, caching |
| 07 | [Local storage](guides/07-local-storage.md) | shared_preferences, drift/SQLite, file storage — and which stale packages to avoid |
| 08 | [Testing](guides/08-testing.md) | Unit, widget, golden, and integration tests; mocking; CI |
| 09 | [Windows desktop](guides/09-windows-desktop.md) | C++ toolchain, runner anatomy, window/tray, folder vs MSIX distribution |
| 10 | [Android release](guides/10-android-release.md) | Upload key + Play App Signing, AAB, R8, flavors, Play tracks |
| 11 | [Web and other platforms](guides/11-web-and-other-platforms.md) | Web Wasm/JS builds; iOS/macOS/Linux rules (build on their own OS) |
| 12 | [Flavors and configuration](guides/12-flavors-and-config.md) | Per-platform flavors, `--dart-define`, `appFlavor`, per-flavor icons |
| 13 | [Performance and DevTools](guides/13-performance-and-devtools.md) | Build modes, DevTools suite, jank hunting, const discipline |
| 14 | [Architecture and project structure](guides/14-architecture-and-project-structure.md) | Official architecture guidance, repositories, DI composition root, when not to add packages |

### Reference

| File | What it is |
|---|---|
| [reference/dependencies.md](reference/dependencies.md) | The package directory: verified versions, when to use each, and the avoid list |
| [reference/commands.md](reference/commands.md) | flutter/dart CLI cheatsheet |
| [reference/versions.md](reference/versions.md) | Flutter/Dart release table and how to re-verify it |

### Working material

| Folder | What it holds |
|---|---|
| [scripts/](scripts/) | Helper scripts for setup, builds, and release chores (see its README) |
| [templates/](templates/) | Starting projects and drop-in pieces (see its README) |
| [fixtures/](fixtures/) | Test data and sample payloads for the guides' examples (see its README) |
| [tools/](tools/) | Small standalone tools that support Flutter work (see its README) |

## Versions snapshot (November 2026)

| Thing | Version | Note |
|---|---|---|
| Flutter | **3.50.0** | Stable channel |
| Dart (bundled with Flutter) | **3.14.0** | Standalone Dart SDK is 3.14.1 — the bundled one is what Flutter uses |
| flutter_lints | **6.0.0** | The recommended lint baseline |
| very_good_analysis | 11.0.0 | Stricter lint option, if you want it |
| Windows flavors | Flutter 3.47+ | Older releases have a single Windows configuration |

Full release history and how to verify it lives in
[reference/versions.md](reference/versions.md); package versions in
[reference/dependencies.md](reference/dependencies.md). **Re-check
both against pub.dev / the Flutter releases manifest before pinning
anything** — versions move monthly.

## Using this pack with an AI locally

This pack is part of a repository that is built to be downloaded and
used offline:

1. Download the repo (Code → Download ZIP) and unzip it anywhere.
2. Point the AI at the folder. It should start with
   **`flutter/manifest.json`** (the machine-readable file map and
   reading order for this pack) and **`flutter/AGENTS.md`** (the
   rules for writing Flutter code from this pack), then read in the
   manifest's order.
3. No time to load a folder? Upload **`flutter/ai-bundle.md`**
   instead — this pack's guides and references concatenated into one
   markdown file.

Everything is plain text/markdown with relative links; nothing here
needs a server, an account, or this repository's website.

## Ground rules this pack follows

- Official docs first (docs.flutter.dev, dart.dev, pub.dev) — see
  [SOURCES.md](SOURCES.md).
- Community packages are labelled as community packages, never
  presented as Flutter-team work.
- Anything that could not be verified is marked **Unverified** rather
  than repeated as fact.
