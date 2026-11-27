# SOURCES.md — Where this pack's facts come from

Every claim in this pack traces back to one of these sources. When
sources disagree, the order is: **pub.dev / official docs for the
exact version in question** first, this pack second, everything else
(blogs, videos, old tutorials, model memory) last. Entries marked
**re-check on pub.dev** are version-sensitive: look at the live page
before relying on the number.

## Official — Flutter and Dart

| Source | URL | Why it matters |
|---|---|---|
| Flutter documentation | https://docs.flutter.dev | The primary reference: install, platform guides, release guides, the official app-architecture guidance behind guide 14 |
| Flutter API reference | https://api.flutter.dev | Exact widget/framework API signatures for the current stable |
| Dart documentation | https://dart.dev | Language tour, null safety, async, tooling (`dart format`, `dart analyze`) |
| Dart API reference | https://api.dart.dev | Core library APIs |
| Flutter releases manifest | https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json (swap OS name for macOS/Linux) | Machine-readable list of every release + bundled Dart version — how [reference/versions.md](reference/versions.md) is re-verified |
| Flutter release notes / what's new | https://docs.flutter.dev/release/release-notes | Per-release changes, breaking changes, deprecations (incl. the `material_ui` transition) |
| Flutter DevTools docs | https://docs.flutter.dev/tools/devtools | The profiling suite behind guide 13 — DevTools ships with the SDK |
| Dart/Flutter GitHub | https://github.com/flutter/flutter · https://github.com/dart-lang/sdk | Issue trackers and changelogs when docs lag a release |

## pub.dev — the package source of truth

| Source | URL | Why it matters |
|---|---|---|
| pub.dev | https://pub.dev | Every package's real current version, publisher, maintenance signals, and licence. **Re-check on pub.dev** before pinning anything in [reference/dependencies.md](reference/dependencies.md) |
| Flutter favorites | https://pub.dev/flutter/favorites | The Flutter team's curated quality signal for packages |
| Package layout / scoring docs | https://dart.dev/tools/pub | How pub scores, platforms, and versioning work |

## Samples and starting points

| Source | URL | Why it matters |
|---|---|---|
| flutter/samples | https://github.com/flutter/samples | The Flutter team's own sample apps — the first place to look for a working pattern |
| Flutter cookbook | https://docs.flutter.dev/cookbook | Task-shaped official recipes |
| Very Good CLI / templates (Very Good Ventures) | https://cli.vgv.dev · https://pub.dev/packages/very_good_analysis | Community (VGV) project generator and the strict lint set in the dependencies reference — well maintained, but **community, not Flutter-team**; re-check on pub.dev |
| Flutter gallery / official demos in the SDK | `flutter create` samples + https://github.com/flutter/gallery (archived — history only) | Useful patterns; the gallery repo is archived, treat as read-only reference |

## Platform and store sources

| Source | URL | Why it matters |
|---|---|---|
| Google Play Console help | https://support.google.com/googleplay/android-developer | Target API requirements, App Bundle and Play App Signing rules behind guide 10 — policy moves yearly, re-check |
| Android developer site | https://developer.android.com | Gradle/Android behaviour under Flutter's Android build |
| Microsoft Store / MSIX docs | https://learn.microsoft.com/windows/msix | MSIX packaging rules behind guide 09's Store route |
| Apple developer | https://developer.apple.com | iOS/macOS signing, entitlements, App Store rules behind guide 11 |

## Communities and learning

| Source | Why it matters |
|---|---|
| Flutter Community (fluttercommunity.dev) + its package org | Maintains several widely used plus/community plugins; check publisher on pub.dev per package |
| r/FlutterDev (Reddit), FlutterDev Discord, Stack Overflow `flutter` tag | Where working developers answer platform-specific questions; answers age fast — verify against docs |
| Official Flutter YouTube channel ("Decoding Flutter", "Widget of the Week") | Short, accurate, version-aware explainers from the team |
| Very Good Ventures blog / Shorebird blog | High-quality engineering deep dives (community/commercial voices, labelled as such) |

## Games-adjacent

Flutter is an app framework first; for games in this ecosystem the
honest sources are the **Flame engine** (https://flame-engine.org,
pub.dev: `flame` — **re-check on pub.dev**) and the **Bonfire** RPG
toolkit built on it. Anything heavier than 2D/casual scope should
also read the dedicated game-development material elsewhere in this
repository before choosing Flutter as the engine.

## Verification note

Package and SDK versions in this pack were verified against the
sources above in **November 2026**. That is a snapshot, not a
promise: Flutter ships new stable releases several times a year and
popular packages release monthly. The re-check habit — pub.dev for
packages, the releases manifest for the SDK — is part of the pack's
method, not an afterthought.
