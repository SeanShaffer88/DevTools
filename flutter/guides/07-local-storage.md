# 07 — Local Storage

Local storage is three different jobs that get confused constantly:
remembering a few settings, storing structured app data, and
keeping files. Each job has a right tool — and the NoSQL job has a
trap this guide flags in capital letters.

Storage docs: https://docs.flutter.dev/data-and-backend

## Job 1: a few small settings — shared_preferences

`shared_preferences` (**2.5.6**) wraps the platform key-value
stores (Android SharedPreferences, iOS UserDefaults). It is for
*small, simple* values only: flags, a theme choice, the last tab.

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('seen_onboarding', true);
await prefs.setString('theme', 'dark');

final seen = prefs.getBool('seen_onboarding') ?? false;
```

Hard limits to respect:

- Strings, bools, ints, doubles, and string lists — nothing else.
- **Not** a database: no queries, no transactions, no large blobs.
  Storing your app's data here as JSON strings is the classic
  mistake this section exists to prevent.
- **Not secure:** values are readable on a rooted/jailbroken
  device. Never store tokens or secrets here (see the end).

## Job 2: structured data — a real database

### drift — the default recommendation

`drift` (**2.35.4**) is a reactive persistence library on top of
SQLite, and it is the default choice for new Flutter apps that
store structured local data. You declare tables in Dart, drift
generates type-safe queries, and queries can be *watched* as
streams so the UI updates when the data changes:

```dart
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get priceCents => integer().nullable()();
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  Stream<List<Item>> watchItems() => select(items).watch();
  Future<int> addItem(ItemsCompanion entry) => into(items).insert(entry);
}
```

Generation runs through `build_runner`, same as guide 06. Drift
brings compile-time-checked SQL, migrations with tests, and web/
desktop support. If you are choosing one database today, choose
this one.

### sqflite — the older direct-SQL route

`sqflite` (**2.4.6**) gives you raw SQLite with hand-written SQL
strings. It is mature and fine in existing apps. In new apps it
mostly survives where a team wants zero code generation and is
disciplined about SQL — accepting that a typo'd column name is a
runtime error instead of a compile error, which is precisely the
trade drift exists to remove.

## Files: path_provider + dart:io

Documents, downloads, cached images, exports — anything that is a
file belongs in a platform directory you ask for, never a
hard-coded path:

```dart
import 'package:path_provider/path_provider.dart';

final docs = await getApplicationDocumentsDirectory();  // survives, backed up
final cache = await getTemporaryDirectory();            // system may clear it

final file = File('${docs.path}/export.csv');
await file.writeAsString(csvText);
```

Rule: documents directory for data the user would miss, temporary
directory for anything you can recreate. On desktop, the same API
returns the platform-appropriate folders.

## WARNING: Hive and Isar — the originals are stale

This is the most expensive trap in Flutter storage, because old
tutorials still recommend both packages as defaults:

- **`hive` 2.2.3 has not been meaningfully updated since 2022.**
- **`isar` 3.1.0+1 has not been meaningfully updated since 2023.**

Do **not** start a new project on the original `hive` or `isar`
packages. If you want that style of embedded NoSQL store, use the
maintained community forks instead:

- **`hive_ce`** — the community edition continuing Hive.
- **`isar_community`** — the community fork continuing Isar.

…or use **ObjectBox**, a separately maintained embedded database
with a Flutter package, if its model fits your data.

Whichever you pick, say so in the project readme with the reason —
the next developer will otherwise "helpfully" migrate you back to
the stale originals that search results still rank first.

Honest framing: for most apps this whole NoSQL category is
optional. drift over SQLite covers the structured-data job with
the strongest tooling, and choosing it means one less dependency
betting on fork maintenance.

## Secrets: neither of the above

Tokens, refresh credentials, and API keys are not "settings" and
not "data". Store them in the platform keystore/keychain through
a secure-storage package (search pub.dev for the current
maintained option and verify it before adopting), keep them out
of `shared_preferences` and out of the database, and keep them out
of source control entirely. A secret that ships inside the app
binary is a published secret — design APIs accordingly.

## Choosing, in one table

| Job | Tool |
|---|---|
| A handful of flags/settings | shared_preferences 2.5.6 |
| Structured app data, queries, reactive UI | **drift 2.35.4** (default) |
| Existing raw-SQL codebase | sqflite 2.4.6 |
| Files, exports, caches | path_provider + `dart:io` |
| Embedded NoSQL, if you truly need it | hive_ce / isar_community forks, or ObjectBox — **never stale hive/isar originals** |
| Tokens and secrets | Platform keystore via a secure-storage package |

## Migrations are part of the choice

Any database you ship will change schema after users have data.
Before release 1.0, confirm your choice has a migration story you
understand (drift: versioned schema + migration tests; sqflite:
`onUpgrade` by hand) and write the first migration test while the
schema is still trivial — retrofitting migration discipline after
version 3 is where local-data horror stories come from.

Verify current versions on https://pub.dev before adding any of
these — storage packages in particular have look-alike forks.

## Next

Testing: [08-testing.md](08-testing.md).
Networking that fills the database: [06-networking-and-data.md](06-networking-and-data.md).
