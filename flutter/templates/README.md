# Templates

Copy-and-start material for Flutter projects. Versions match the
verified Nov 2026 snapshot used across this resource pack
(Flutter 3.50.0, Dart 3.14.0, flutter_lints 6.0.0); re-check pub.dev
before pinning any optional dependency in a long-lived project.

| Template | What it is | How to use it |
|---|---|---|
| [app-skeleton/](app-skeleton/) | Minimal feature-first app: `pubspec.yaml`, `analysis_options.yaml`, `lib/` (entry point, root widget, data seam, one home feature), one widget test | See [app-skeleton/README.md](app-skeleton/README.md) — generate platform folders with `flutter create`, then copy the skeleton over them |
| [gitignore-flutter](gitignore-flutter) | Standard Flutter `.gitignore`, plus a secrets block (keystores, `key.properties`, Firebase config, `.env`) | Copy to a project root as `.gitignore` |
| [github-workflows/flutter-ci.yml](github-workflows/flutter-ci.yml) | GitHub Actions: analyze + format check + test on Ubuntu and Windows, then an Android App Bundle build (Ubuntu) and a Windows release build (Windows), each uploaded as an artifact | Copy to `.github/workflows/flutter-ci.yml` in a real repo |
| [msix-config.yaml.example](msix-config.yaml.example) | Example `msix_config:` section for packaging a Flutter Windows app as MSIX with the `msix` pub package, for Microsoft Store or signed self-distribution | Copy the section into the project's `pubspec.yaml`, replace the placeholders, follow the comments in the file |

## Notes

- The app skeleton's `pubspec.yaml` carries the optional
  dependencies (provider / Riverpod, go_router, dio / http, drift,
  freezed / json_serializable, build_runner, mocktail) as comments
  with their verified versions, so enabling one is an uncomment, not
  a version hunt.
- The skeleton's SDK constraint is `sdk: ^3.14.0`. Dart accepts the
  caret form for SDK constraints — `^3.14.0` means
  `>=3.14.0 <4.0.0`, identical to the longhand range. The floor
  matters (Dart 3.14.0 is bundled with Flutter 3.50.0); the form
  does not.
- Nothing in these templates contains secrets, signing keys, or
  machine-specific paths. Release signing belongs in CI secrets /
  Play App Signing, never in a template.
