# Flutter pack — tools

Python 3 tools for the Flutter pack. Standard library only, nothing to
install, all offline. Each tool has `--help`-style usage in its header
and meaningful exit codes.

| Tool | What it does |
|---|---|
| [check-flutter-project.py](check-flutter-project.py) | Validates a Flutter project folder: `pubspec.yaml` (name/version parse), `lib/main.dart`, `analysis_options.yaml`, platform folders, sdk constraint, stale `hive`/`isar` warnings, `integration_test` pinned from pub instead of the SDK. Prints PASS/WARN/FAIL lines; exit 1 if any FAIL. |
| [pubspec-audit.py](pubspec-audit.py) | Compares a `pubspec.yaml`'s dependencies against the bundled snapshot (below): PASS for current-or-newer, WARN for older, STALE for the unmaintained originals (`hive`, `isar`), INFO for packages not in the snapshot. Exit 1 if anything is older or stale. |
| [build-ai-bundle.py](build-ai-bundle.py) | Regenerates this pack's `manifest.json` (file map + reading order) and `ai-bundle.md` (guides + reference in one file) in the `flutter/` folder. Run it after any pack content change. |
| [package-snapshot.json](package-snapshot.json) | The verified November 2026 version snapshot `pubspec-audit.py` compares against: Flutter 3.50.0, Dart 3.14.0, and the pack's recommended packages. Data, not code — refreshed by the pack maintenance flow (see `scripts/Update-FlutterPack.ps1`). |

## Usage

```bash
python3 tools/check-flutter-project.py path/to/project
python3 tools/pubspec-audit.py path/to/project/pubspec.yaml
python3 tools/build-ai-bundle.py            # writes flutter/manifest.json + flutter/ai-bundle.md
```

The snapshot is a point-in-time record, not live data: a PASS means
"at least as new as the November 2026 snapshot", not "latest on
pub.dev". Re-check versions on pub.dev before starting a new project.
