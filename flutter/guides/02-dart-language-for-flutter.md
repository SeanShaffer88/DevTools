# 02 — The Dart Language for Flutter Developers

You do not need to master all of Dart before writing Flutter, but
these are the parts you will use every day. This guide assumes
Flutter 3.50.0, which bundles **Dart 3.14.0**.

Language tour: https://dart.dev/language
Effective Dart style: https://dart.dev/effective-dart

## The Dart 3 baseline

Dart 3 changed the ground rules. Code written for Flutter today:

- **Has sound null safety, always.** It cannot be disabled in
  Dart 3. A type is non-nullable unless you say otherwise with `?`.
- **Uses records, patterns, and exhaustive switches** (below) as
  ordinary tools, not novelties.
- **May use class modifiers** (`sealed`, `final`, `base`,
  `interface`, `mixin class`) to control inheritance.
- **May use primary constructors** (added in Dart 3.13) — a compact
  constructor syntax. You will meet it in newer code; the classic
  constructor syntax remains fully valid.
- **Does not use macros.** The Dart macros experiment was
  abandoned. Code generation in Dart means `build_runner` with
  generators such as `json_serializable` and `freezed` — see
  guide 06.

## Null safety in practice

```dart
String name = 'Ada';     // can never be null
String? nickname;        // may be null — and starts as null

int length = nickname?.length ?? 0;   // null-aware access + fallback
```

Rules of thumb:

- Prefer `?`, `?.`, and `??` over the bang operator `!`.
- `nickname!` means "crash if this is null". It is a promise you
  make to the compiler — make it rarely, and only when you have
  actually checked.
- `late` means "I will assign this before anyone reads it":

```dart
late final String config;   // assigned once during setup
```

Use `late` sparingly; a forgotten assignment is a runtime crash.

## Variables, types, and inference

```dart
var count = 0;            // inferred as int, then fixed as int
final title = 'Home';     // set once at runtime, cannot change
const maxItems = 100;     // compile-time constant

String greet(String who) => 'Hello, $who';   // string interpolation
```

`final` for almost everything local; `const` whenever a value is
known at compile time — `const` widgets in Flutter are a real
performance tool, not a style tic.

## Collections

```dart
final list = [1, 2, 3];
final set = {'a', 'b'};                    // no duplicates
final map = {'id': 1, 'name': 'Ada'};

final doubled = [for (final n in list) n * 2];       // collection-for
final maybe = [if (showExtra) 99];                   // collection-if
final copy = [...list, 4];                           // spread
```

Collection operators inside widget `children:` lists are the same
feature — Flutter UI code is full of `if` and `for` inside lists.

## Records: small anonymous data bundles

Records group a few values without declaring a class:

```dart
(String, int) parse(String s) => (s.trim(), s.length);

final (text, length) = parse(' hi ');   // destructure on receipt
```

Use a record for a private helper that returns two or three
related values. Use a real class when the data has a name, methods,
or a life outside one function.

## Patterns and exhaustive switch

Dart 3 pattern matching makes state handling in UI code much safer:

```dart
String describe(Object value) => switch (value) {
  int n when n < 0 => 'negative',
  int n => 'a number: $n',
  String s => 'text: $s',
  (String name, int age) => '$name is $age',   // record pattern
  _ => 'something else',
};
```

The key word is **exhaustive**: over a sealed type, the compiler
proves you handled every case, and adding a new case later turns
every unhandled switch into a compile error. That is exactly what
you want for UI states:

```dart
sealed class LoadState {}
final class Loading extends LoadState {}
final class Ready extends LoadState {
  Ready(this.items);
  final List<String> items;
}
final class Failed extends LoadState {
  Failed(this.message);
  final String message;
}

// In a widget:
switch (state) {
  Loading() => const CircularProgressIndicator(),
  Ready(items: final items) => ListView(children: [for (final i in items) Text(i)]),
  Failed(message: final m) => Text('Error: $m'),
}
```

## Classes and class modifiers

```dart
class Point {
  const Point(this.x, this.y);      // positional fields, const ctor
  final int x;
  final int y;

  Point.named({required this.x, required this.y});  // named ctor

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}
```

Modifiers you will actually use:

- `sealed class` — all subtypes live in the same library; enables
  exhaustive switching (above). The default choice for state types.
- `final class` — cannot be extended outside its library.
- `abstract class` — cannot be instantiated; a contract plus
  optional shared code.
- `mixin` — reusable behaviour mixed into classes with `with`.

Prefer composition and small sealed hierarchies over deep
inheritance trees.

## Functions

```dart
int add(int a, int b) => a + b;                       // arrow body
void log(String message, {bool verbose = false}) {}   // named params
void greet({required String name}) {}                 // required named

// Functions are values:
final names = ['ada', 'bo'].map((s) => s.toUpperCase()).toList();
```

In Flutter, callbacks are functions passed as values everywhere —
`onPressed: () => doThing()` is the pattern, not an exception.

## Async: Futures, Streams, isolates

A `Future<T>` is a value that arrives later. `async`/`await` is the
normal way to consume one:

```dart
Future<String> loadName() async {
  final response = await fetchFromSomewhere();
  return response.name;
}
```

A `Stream<T>` is many values over time — listen, or use Flutter's
`StreamBuilder`:

```dart
Stream<int> ticks() async* {
  var i = 0;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 1));
    yield ++i;
  }
}
```

Error handling is ordinary `try`/`catch`, including in async code:

```dart
try {
  final data = await load();
  show(data);
} on TimeoutException {
  showRetry();
} catch (e) {
  showError(e);
}
```

**Isolates** are Dart's separate memory/thread units — no shared
memory, messages only. Flutter runs your UI on the main isolate;
heavy parsing or computation (big JSON, image work) belongs on a
background isolate so the UI never janks:

```dart
final result = await Isolate.run(() => parseBigJson(rawText));
```

`Isolate.run` (and Flutter's older `compute`) is the easy path:
hand it a function and the input, get a Future of the output.

## What to skip for now

Generators beyond `async*` basics, extension types, FFI, and the
full modifier matrix can all wait until a real project needs them.
The features above — null safety, records, patterns, sealed
classes, collections, and async — are 95% of daily Flutter Dart.

## Next

Widgets: [03-widgets-and-ui.md](03-widgets-and-ui.md).
State: [04-state-management.md](04-state-management.md).
