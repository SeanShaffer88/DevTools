# AGENTS.md — Instructions for AI agents writing Flutter code

You are using this pack as your knowledge base for creating Flutter
and Dart apps. Follow these rules exactly.

## Non-negotiable rules

1. **Never invent package names, versions, or APIs.** Every package
   you add and every version you pin must be traceable to its page on
   **pub.dev**; every Flutter/Dart API to **docs.flutter.dev** or
   **api.flutter.dev** / **dart.dev**. If you cannot trace it, do not
   write it — say it is **Unverified** instead. Versions in this pack
   (including [reference/dependencies.md](reference/dependencies.md))
   are a dated snapshot: re-check pub.dev before pinning, because
   Flutter-ecosystem packages release monthly.
2. **State the target platform first.** Before writing code, name the
   target: Android, Windows, web, iOS, macOS, Linux — and the build
   mode where it matters. Platform decides the APIs, the plugins, the
   build command, and the distribution shape. Remember: desktop apps
   build only on their own OS (a Windows app builds on Windows), and
   performance is measured in **profile mode on a real device**, never
   debug ([guides/13](guides/13-performance-and-devtools.md)).
3. **Null safety, always.** All Dart code is sound null-safe. No
   opting out, no `// @dart=2.9`, no sprinkling `!` to silence the
   analyser — model absence honestly (nullable types, sealed states)
   and fix the model when the analyser complains.
4. **Do not use the original `hive` or `isar` packages in new
   projects.** Both are stale (hive last released 2022, isar 2023).
   Use the maintained successors named in
   [reference/dependencies.md](reference/dependencies.md) (`hive_ce`,
   `isar_community`, ObjectBox) — or, more often, **drift** or
   **shared_preferences**, which cover most apps' real needs
   ([guides/07](guides/07-local-storage.md)).
5. **`integration_test` comes from the SDK, never from pub.** It is
   declared as `sdk: flutter` in dev_dependencies. A version-pinned
   pub.dev copy of `integration_test` in a new project is a
   version mix-up.
6. **Respect the `material_ui` transition.** Flutter's Material
   library is being restructured (the `material_ui` effort). Prefer
   current Material 3 APIs as documented on docs.flutter.dev today,
   check for deprecations after every Flutter upgrade with
   `flutter analyze`, and do not copy Material 2 patterns from old
   tutorials into new code.
7. **AAB for Play, whole folder for desktop.** Android releases for
   Google Play are **Android App Bundles** signed through Play App
   Signing ([guides/10](guides/10-android-release.md)). Windows
   releases ship the **whole** `build\windows\x64\runner\Release\`
   folder (or an MSIX made from it), never the bare `.exe`
   ([guides/09](guides/09-windows-desktop.md)).
8. **No secrets in the repo.** No API keys beyond public client keys,
   no keystores or their passwords, no service-account JSON, no
   signing material. Signing config reads from a git-ignored
   `key.properties` / environment. `--dart-define` values are
   compile-time constants visible in the binary — configuration, not
   secrecy ([guides/12](guides/12-flavors-and-config.md)).
9. **Community packages are community packages.** window_manager,
   tray_manager, and friends are third-party work, however popular.
   Say so when you recommend one, check its maintenance on pub.dev,
   and keep platform-plugin calls behind platform checks and your
   composition root.
10. **Verify before declaring done.** Run, in this order:
    `dart format`, `flutter analyze` (clean), the test suite
    (`flutter test`), and a build for the target platform. State
    plainly which of these ran and which could not — label the rest
    **Unverified** rather than claiming success. Code that has never
    compiled is not done.

## Build order (always in this sequence)

1. Name the target platform(s) and form factor (rule 2).
2. Scaffold or open the project; confirm `flutter doctor` is clean
   for the target toolchain and a debug run works
   ([guides/01](guides/01-getting-started-and-toolchain.md)).
3. Set the lint baseline (flutter_lints) and folder structure
   ([guides/14](guides/14-architecture-and-project-structure.md)).
4. Build the smallest end-to-end slice: one screen, real data path,
   one repository.
5. Add state management, routing, storage, and networking as the
   feature list actually needs them — not before
   ([guides/04](guides/04-state-management.md)–[07](guides/07-local-storage.md)).
6. Test as you go (unit → widget → golden → integration,
   [guides/08](guides/08-testing.md)); profile in profile mode before
   optimising anything.
7. Release per platform: AAB + Play tracks for Android, Release
   folder/MSIX for Windows ([guides/09](guides/09-windows-desktop.md),
   [guides/10](guides/10-android-release.md)).

## Things that are always wrong

- A package version, plugin, or API that appears in no pub.dev /
  official-docs source for the stated Flutter version.
- Original `hive` / `isar`, or a pub-pinned `integration_test`, in a
  new project.
- Performance conclusions drawn from a debug build or an emulator.
- A Play upload built as a raw APK instead of an AAB.
- Shipping a Windows `.exe` without its engine DLL and `data\` folder.
- Signing keys, keystores, or passwords committed to version control.
- Material 2-era patterns copied from old tutorials into new code.
- Reaching for a state-management/framework package before the app's
  size justifies it.
- Treating a blog post, video, or model memory as proof a package
  version or Play policy is current — re-check pub.dev / official
  sources.
