# App skeleton

A minimal, feature-first Flutter app skeleton: Material 3, one home
page fed by a small repository, one widget test. Versions pinned to
the verified Nov 2026 snapshot (Flutter 3.50.0, Dart 3.14.0,
flutter_lints 6.0.0).

## Layout

```text
lib/
  main.dart                     entry point — runApp only
  app.dart                      root widget: MaterialApp + theme
  data/
    sample_repository.dart      in-memory data seam (swap for API/DB)
  features/
    home/
      home_page.dart            the one feature page
test/
  widget_test.dart              home page widget tests
pubspec.yaml
analysis_options.yaml
```

## Turn it into a real project

The skeleton is not a runnable generated project on its own — it has
no platform folders (`android/`, `windows/`, …) because those must be
generated for your app name and organization. Two ways to use it:

### Option A — generate, then copy over (recommended)

```text
flutter create --org com.example --project-name my_app my_app
```

Then copy from this skeleton into the new project, overwriting:

- `pubspec.yaml` — then change `name:` to your project name and fix
  the `app_skeleton` import prefix in the test (Option B note below).
- `analysis_options.yaml`
- `lib/main.dart`, `lib/app.dart`, `lib/data/`, `lib/features/`
- `test/widget_test.dart`

Run `flutter pub get`, then `flutter analyze` and `flutter test`.

> The widget test imports `package:app_skeleton/...`. After renaming
> the package in `pubspec.yaml`, update those imports to your new
> package name (an IDE rename or a plain text replace of
> `app_skeleton` in `test/` and `lib/` does it).

### Option B — copy the folder, then generate the platforms in place

Copy this folder to your project location, rename it, then run:

```text
flutter create --org com.example --project-name my_app .
```

`flutter create` in an existing folder adds the missing platform
folders without overwriting your `lib/` code (review its output
before confirming overwrites of `pubspec.yaml` — keep this
skeleton's version if asked; you can re-apply the rename after).

## SDK constraint note

`pubspec.yaml` uses `sdk: ^3.14.0`. Dart SDK constraints accept the
caret form: `^3.14.0` means `>=3.14.0 <4.0.0`, the same range the
longhand `>=3.14.0 <4.0.0` spells out. Either form is fine; the
caret form is what current `flutter create` templates emit. The
important part is the floor: Dart 3.14.0 is the SDK bundled with
Flutter 3.50.0, so code in this skeleton can rely on that language
version.

## Next steps in a real project

- Pick a state-management approach and a router from the commented
  optional dependencies in `pubspec.yaml` (provider / Riverpod,
  go_router) — see the architecture and state guides in this pack.
- Replace `SampleRepository`'s in-memory list with a real source;
  the fixtures in `../../fixtures/` are shaped for tests of that
  swap.
