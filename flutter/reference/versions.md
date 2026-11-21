# Reference — Flutter / Dart Versions

Verified **November 2026**. Flutter ships several stable releases a
year; treat this table as a dated snapshot and re-verify with the
method at the bottom before quoting a "latest" anywhere.

## Current snapshot

| Thing | Version |
|---|---|
| Flutter (stable) | **3.50.0** |
| Dart bundled with Flutter 3.50 | **3.14.0** |
| Dart standalone SDK | **3.14.1** |

The bundled Dart is the one Flutter projects actually use — when a
project's behaviour differs from standalone-Dart documentation, the
bundled version wins. A standalone Dart install is for pure-Dart
packages, servers, and CLI tools.

## Recent stable releases

| Flutter | Bundled Dart | Era notes |
|---|---|---|
| **3.50.0** | **3.14.0** | This pack's snapshot (Nov 2026) |
| 3.49.x | 3.13.x line | — |
| 3.48.x | 3.13.x line | — |
| 3.47.x | 3.12.x line | **Windows flavors land** (guide 12); **Widget Previews become stable** (guide 13) |
| 3.46.x | 3.12.x line | — |
| 3.45.x | 3.11.x line | — |
| 3.44.x | 3.11.x line | — |
| 3.43.x | 3.10.x line | — |
| 3.42.x | 3.10.x line | — |
| 3.41.x | 3.9.x line | — |

Rows below 3.47 are given as Dart *lines* rather than exact patch
numbers on purpose: the patch-level pairing for older releases should
be read from the releases manifest (below) rather than trusted from
any secondary table — including this one. Exact pairings for the
current release and the two feature landmarks (3.47) were verified
for this snapshot.

## Channels, in plain words

| Channel | What it is | Who should use it |
|---|---|---|
| **stable** | Tested, versioned releases only | Almost everyone, almost always — all production work |
| **beta** | Pre-release of the next stable; feature-frozen-ish | Trying an announced feature a few weeks early, on a branch |
| **main** (formerly master) | The live development tip, unversioned | Flutter contributors and people testing a fix that just landed |

Switch with `flutter channel <name>` then `flutter upgrade`. An app
should record the Flutter version it was built with (CI pins it), and
"works on my machine" differences between teammates are usually a
channel/version difference — `flutter --version` settles it.

## How versions gate features in this pack

| Feature | Needs |
|---|---|
| Windows flavors | Flutter **3.47+** |
| Widget Previews (stable) | Flutter **3.47+** |
| Current lint baseline | flutter_lints **6.0.0** (see dependencies reference) |
| Play target API 36 era alignment | Current-era Flutter defaults (guide 10) — verify the built bundle's effective target after upgrading |

## How to re-verify this table

1. **The releases manifest** (machine-readable, official):
   - Windows: https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json
   - macOS: …/releases_macos.json · Linux: …/releases_linux.json
   It lists every release with its version, channel, Dart SDK version,
   and hashes. The newest `stable` entry is the current stable.
2. **Release notes:** https://docs.flutter.dev/release/release-notes
   — human-readable changes and breaking-change guides per release.
3. **Your own install:** `flutter --version` — the ground truth for
   what a given machine will actually build with.

If this table and the manifest disagree, the manifest is right and
this table is stale — update it (and the snapshot notes in the
guides) in the same change.
