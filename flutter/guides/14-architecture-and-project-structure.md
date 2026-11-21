# 14 — Architecture and Project Structure

Flutter's official guidance now includes a full app-architecture
recommendation (docs.flutter.dev/app-architecture) — this guide is the
short, opinionated version of it, matched to the rest of this pack:
unidirectional data flow, a repository between your UI and your data
sources, immutable UI state, and dependencies wired up in exactly one
place.

Snapshot: **Flutter 3.50.0 / Dart 3.14.0**. Package versions cited
here are in [reference/dependencies.md](../reference/dependencies.md)
— re-check them on pub.dev before pinning.

## The shape, in one picture

```
UI layer          Widgets + a state holder per screen
                  (reads immutable UI state, emits user intents)
        ▲  state down, events up  ▼
Data layer        Repositories  →  Services (API, database, prefs)
                  (one repository per data kind; the only place
                   that knows where data comes from)
```

- **Unidirectional data flow:** state flows down, events flow up.
  Widgets never mutate shared state directly.
- **Single source of truth:** each kind of data has exactly one owner
  (its repository). Two widgets needing the same data read the same
  repository, not two copies.
- **Separation that pays rent:** the UI does not know what an HTTP
  client or a SQL table is; the data layer does not know what a
  widget is. Either side can be tested and changed without the other.

## UI state: immutable, modelled, boring

Represent each screen's state as one immutable class — a sealed class
for distinct phases, or a single class with a status field — usually
generated with **freezed** (see guide 06 / dependencies reference) so
copying, equality, and pattern matching are correct by construction:

```dart
@freezed
sealed class NotesState with _$NotesState {
  const factory NotesState.loading() = NotesLoading;
  const factory NotesState.ready(List<Note> notes) = NotesReady;
  const factory NotesState.error(String message) = NotesError;
}
```

Why this matters: a widget that renders `state.when(loading: …,
ready: …, error: …)` cannot forget a case, and a state holder whose
whole job is "turn repository data into these states" is trivial to
unit test (guide 08).

## Feature-first vs layer-first folders

Two honest layouts; pick per project size:

**Layer-first** (fine for small apps):

```
lib/
  main.dart
  ui/            widgets, screens, state holders
  data/          repositories, services, models
  config/        AppConfig, routing
```

**Feature-first** (better once an app has several distinct areas —
each feature carries its own UI + state, sharing only the data layer):

```
lib/
  main.dart
  features/
    notes/       notes_screen.dart, notes_state.dart, notes_controller.dart
    settings/    …
  data/          repositories + services shared by features
  core/          config, routing, shared widgets, theme
```

Rule of thumb: start layer-first; the day one folder (usually `ui/`)
becomes a junk drawer, split by feature. Do not start a two-screen
app with a framework-grade folder cathedral.

## The repository pattern in practice

```dart
class NotesRepository {
  NotesRepository(this._api, this._db);
  final NotesApi _api;        // service: talks HTTP
  final NotesDao _db;         // service: talks the local database

  Stream<List<Note>> watchNotes() => _db.watchAll();   // UI reads local truth
  Future<void> refresh() async {                        // sync is the repo's job
    final remote = await _api.fetchNotes();
    await _db.replaceAll(remote);
  }
}
```

The UI watches the local source and asks for refreshes; caching,
offline behaviour, and "which source wins" live in exactly one class.
This is the same offline-first shape as [guide 07](07-local-storage.md)
describes — architecture and storage are the same decision.

## Dependency injection: one composition root

However you provide dependencies (provider, Riverpod, bloc, get_it —
see [guide 04](04-state-management.md) and the dependencies
reference), wire them in **one composition root**: `main.dart` (or a
`bootstrap.dart` it calls) constructs services → repositories → state
holders, in that order, and hands them to the app. Nothing else in
the codebase calls a constructor for a shared service or reaches into
a global locator mid-widget. Benefits you feel immediately:

- Tests substitute a fake repository at the root (guide 08).
- Platform setup (window manager on desktop, guide 09) and flavor
  config (guide 12) live at the root too, not scattered.
- "Where does this object come from?" always has the same answer.

## When NOT to add a package

The most valuable architecture skill is refusal:

- **Don't add a state-management package** for an app whose state is
  two screens and a settings flag — `StatefulWidget` + `ValueNotifier`
  / provider basics cover it; graduate when the pain is real
  (guide 04 helps you choose when it is).
- **Don't add a framework** (routing, DI, forms, all-in-one kits) to
  avoid learning the platform pieces this pack covers; every
  framework is a dependency you now track forever.
- **Don't abstract a service you have one implementation of** behind
  an interface "for later" — abstract at the second implementation
  or at the test boundary, whichever comes first.
- **Don't add code generation** (freezed/json_serializable are worth
  it — guide 06) for three hand-written models; add it when the
  model count makes hand-writing the error-prone option.
- **Check maintenance before anything:** a package whose last release
  is years old (the dependencies reference flags the famous ones) is
  a liability, however many blog posts recommend it.

Every package you *do* add: pin it in pubspec, note why in the commit,
and re-check it at upgrade time with `flutter pub outdated`
(reference/commands.md).

## Growing without collapsing

- Keep `main.dart` thin: bootstrap, then `runApp`.
- One routing definition for the whole app (guide 05).
- Shared widgets graduate to `core/` only when a second feature needs
  them — not on first use, not "just in case".
- Let the analyser be the architecture police: strict lints on
  (guide 01), no bypassing with ignore-comments as a habit.
- Re-read this guide at each new feature and ask: which layer does
  this belong to, and who owns its data? If the answer is unclear,
  the structure — not the feature — is the work.

## Checklist

- [ ] Data flows one way: state down, events up; one owner per data kind
- [ ] Screen states are immutable modelled classes (freezed where it pays)
- [ ] Repositories are the only place that know data sources
- [ ] All wiring happens in one composition root
- [ ] Folder layout matches project size (layer-first small, feature-first grown)
- [ ] Every package in pubspec has a reason; stale packages refused
