# Reference — Dependencies (the package directory)

Verified **November 2026** against pub.dev. Versions move monthly —
**re-check on pub.dev before pinning any of these**; the version is a
snapshot, the "when to use" guidance is the durable part. Licence is
as shown on pub.dev where known; where it says "check pub.dev", look
at the licence tab before adopting it in a project with licence
requirements.

Add with: `flutter pub add <package>` (or `dart pub add` for pure
Dart). Dev-only tools go in `dev_dependencies`.

## State management

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| provider | 6.1.5+1 | The simple default: InheritedWidget made pleasant. Small-to-medium apps, dependency provision + lightweight state | MIT |
| flutter_riverpod | 3.5.0 | Compile-safe provider graph, no BuildContext needed; the scalable default for new medium/large apps | MIT |
| riverpod_generator | 4.0.10 | Code generation for Riverpod (dev dependency; pair with build_runner) — use when you want generated providers | MIT |
| bloc | 9.2.1 | Pure-Dart state machines (events → states); use with flutter_bloc | MIT |
| flutter_bloc | 9.1.1 | Bloc/Cubit widgets for Flutter; predictable, testable, verbose — good for teams and regulated flows | MIT |
| signals_flutter | 7.1.0 | Fine-grained reactive signals; worth evaluating for local, high-frequency state | check pub.dev |
| get_it | 9.3.0 | Service locator for dependency injection when you are not using Riverpod/bloc's provision; wire it only at the composition root | MIT |

Pick **one** primary approach per app (see guide 04). Mixing three
state systems is an architecture smell, not flexibility.

## Navigation

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| go_router | 18.1.4 | Declarative routing with deep links and URL support (web/desktop); the default router for new apps | BSD-3-Clause |
| go_router_builder | 4.5.3 | Typed routes via code generation for go_router (dev dependency) — use when route arguments multiply | BSD-3-Clause |

## Networking and JSON

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| http | 1.6.0 | The baseline HTTP client (Dart team). Enough for most apps | BSD-3-Clause |
| dio | 5.11.1 | Interceptors, cancellation, form data, richer error model — when http gets awkward | MIT |
| freezed | 4.0.3 | Immutable model/state classes with unions and pattern matching (dev/codegen; pair with freezed_annotation) | MIT |
| freezed_annotation | 3.1.0 | Runtime annotations half of freezed — this one ships in dependencies | MIT |
| json_serializable | 6.15.2 | JSON (de)serialisation codegen for plain model classes (dev dependency) | BSD-3-Clause |
| build_runner | 2.17.1 | The code-generation runner behind freezed/json_serializable/riverpod_generator (dev dependency) | BSD-3-Clause |

## Local storage

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| drift | 2.35.4 | Type-safe SQL (SQLite) with streams and migrations — the default real database for Flutter apps | MIT |
| sqflite | 2.4.6 | Direct SQLite access without codegen; fine for simple stores and existing sqflite codebases | BSD-3-Clause |
| shared_preferences | 2.5.6 | Small key-value settings (flags, choices) — not a database | BSD-3-Clause |

## Lint and code quality

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| flutter_lints | 6.0.0 | The recommended lint baseline (dev dependency) — every project, from day one | BSD-3-Clause |
| very_good_analysis | 11.0.0 | Much stricter lint set (Very Good Ventures, community) — adopt deliberately, it will flag a lot | MIT |

## Windows desktop (community — not Flutter-team)

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| window_manager | 0.7.0 | Window size/position/title/show-hide control on desktop (leanflutter, community; published 2026-11-12) | check pub.dev |
| tray_manager | 0.9.0 | System tray icon + menu on desktop (leanflutter, community; published 2026-11-12) | check pub.dev |
| msix | — (re-check) | Builds an MSIX from the Windows Release output for Store/managed installs (community; see guide 09) | check pub.dev |

## Testing

| Package | Version | Purpose / when to use | Licence |
|---|---|---|---|
| mocktail | 1.0.5 | Mocking without code generation for unit/widget tests (dev dependency) | MIT |
| integration_test | **SDK only** | Integration testing — declare as `sdk: flutter` in dev_dependencies, **never** a pinned pub version | SDK |

## Avoid for new projects

| Package | Stuck at | Problem | Use instead |
|---|---|---|---|
| hive | 2.2.3 (2022) | Original package unmaintained since 2022 | **hive_ce 2.23.3** (community-edition fork), or drift for relational data |
| isar | 3.1.0+1 (2023) | Original package unmaintained since 2023 | **isar_community 3.4.1** (community fork) or **ObjectBox 5.3.2** |
| integration_test (pub-pinned) | any | Version conflicts with the SDK's own copy | The SDK declaration: `integration_test: sdk: flutter` |

The avoid list is the highest-value table in this file: old tutorials
still recommend hive and isar constantly, and both ecosystems moved
to community forks years ago. If a project's storage needs are
ordinary, drift + shared_preferences usually beat adopting a fork at
all — see guide 07.

## Rules for adding any package

1. Check pub.dev: version, last-published date, publisher, platforms,
   licence — in that order.
2. Prefer Flutter-team / verified-publisher / Flutter Favorite
   packages when two options tie.
3. One package per job; note *why* in the commit that adds it.
4. Run `flutter pub outdated` at every Flutter upgrade and deal with
   what it surfaces.
