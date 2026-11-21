# 04 — State Management

"State management" in Flutter means: where does changing data
live, who can change it, and how do widgets learn it changed?
Flutter has no single mandated answer — it has a ladder. Start on
the lowest rung that fits, and climb only when the current rung
hurts.

Official overview: https://docs.flutter.dev/data-and-backend/state-mgmt/options

## Rung 0: setState (built in, no package)

Data that belongs to one widget and nobody else — a counter, a
checkbox, which tab is open — is `StatefulWidget` + `setState`
(guide 03). This is not a beginner crutch to be ashamed of; it is
the correct tool for *local UI state* at every skill level.

Outgrow it when: the same data is needed by widgets in different
branches of the tree, or business logic is piling up inside
`build` and event handlers.

## The idea underneath everything: InheritedWidget

Flutter's built-in mechanism for "an ancestor holds a value and
descendants can read it and rebuild when it changes" is
`InheritedWidget`. `Theme.of(context)` and `MediaQuery.of(context)`
are exactly this. Every package below is, at heart, a friendlier
wrapper around this idea plus conventions for *changing* the value.
You rarely write a raw `InheritedWidget` in app code, but knowing
it exists demystifies all of the packages.

## Rung 1: provider — the official starting point

`provider` (**6.1.5+1**) is the package the Flutter documentation
recommends first for app-wide state. It exposes objects down the
tree and rebuilds listeners on change:

```dart
class Cart extends ChangeNotifier {
  final items = <String>[];
  void add(String item) {
    items.add(item);
    notifyListeners();
  }
}

// At the app root:
ChangeNotifierProvider(
  create: (_) => Cart(),
  child: const MyApp(),
)

// In a widget — rebuild when the cart changes:
final count = context.watch<Cart>().items.length;

// In a callback — read without subscribing:
context.read<Cart>().add('book');
```

`watch` in `build`, `read` in callbacks. That distinction is the
whole beginner learning curve of provider, and it is small. Choose
provider when you want the documented, lowest-surprise default.

## Rung 2a: Riverpod — provider's ideas, without the tree

Riverpod (**3.5.0**) declares providers as top-level objects that
do not depend on the widget tree, which makes state easier to test
and reuse, and catches several provider misuse errors at compile
time:

```dart
final counterProvider = NotifierProvider<Counter, int>(Counter.new);

class Counter extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

// In a ConsumerWidget:
final count = ref.watch(counterProvider);
ref.read(counterProvider.notifier).increment();
```

**Riverpod 3.x migration warning:** the old workhorses
`StateProvider` and `StateNotifierProvider` moved to a legacy
import — `package:flutter_riverpod/legacy.dart`. Code samples
written for Riverpod 2 will not compile as-is against 3.x until
those imports (or a move to `NotifierProvider`) are sorted out.
Check which major a tutorial targets before copying it.

Choose Riverpod for larger apps that want compile-safe, testable
state with a strong code-generation option (`riverpod_generator`).

## Rung 2b: flutter_bloc — explicit events and states

`flutter_bloc` (**9.1.1**) implements the BLoC pattern: UI sends
*events* in, a bloc transforms them into a stream of *states* out.
More ceremony, very predictable, excellent for teams and for
flows with complex rules:

```dart
sealed class CounterEvent {}
final class Increment extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
  }
}
```

Choose bloc when the app is event-driven by nature (forms with
validation rules, multi-step flows, auditability) or when a team
already standardises on it. The sealed-class state style from
guide 02 fits bloc perfectly — exhaustive switches over states in
the UI, compile errors when a case is missed.

## Signals: fine-grained reactivity

`signals_flutter` brings the signals model (popularised by web
frameworks) to Flutter: a value that automatically tracks who
read it and rebuilds only those widgets:

```dart
final count = signal(0);
// in build:
Text('${count.value}');   // this widget re-runs when count changes
count.value++;
```

Signals shine for dense, frequently-updating local state. They are
a newer addition to the ecosystem — evaluate maturity for your
project rather than assuming they replace the rungs above.

## Dependency injection: get_it

State packages decide how UI observes data. A *service locator*
like `get_it` (**9.3.0**) answers a different question: how do
classes get their dependencies (repositories, API clients) without
constructing them inline?

```dart
final getIt = GetIt.instance;
getIt.registerSingleton<ApiClient>(ApiClient());
getIt.registerFactory<CartRepository>(() => CartRepository(getIt()));

// elsewhere:
final repo = getIt<CartRepository>();
```

Register at startup in `main`, resolve where needed, and register
fakes in tests. get_it pairs with any state solution above — bloc
and Riverpod users often use it for the non-UI object graph. Keep
registrations in one obvious file; a locator nobody can audit
becomes magic.

## Decision guide

| Situation | Reach for |
|---|---|
| State inside one widget | `setState` — no package |
| First app-wide state, want the documented path | provider |
| Large app, compile-safe + testable state, codegen welcome | Riverpod 3 |
| Event-driven flows, team standard, strict predictability | flutter_bloc |
| Dense reactive local state, experimenting | signals_flutter |
| Constructing repositories/services cleanly (with any above) | get_it |

Rules that hold regardless of choice:

- **One solution per app** for UI state (DI locator aside). Mixing
  provider, Riverpod, and bloc in one codebase is how state bugs
  become archaeology.
- Keep business logic out of widgets: widgets render state and
  forward gestures; notifiers/blocs/repositories do the work.
- State types as sealed classes + exhaustive switches (guide 02)
  make "impossible" UI states unrepresentable.
- Whatever you pick, write down *why* in the project readme —
  future you will otherwise re-litigate it.

Versions drift: verify the current version on
https://pub.dev before adding any of these to `pubspec.yaml`.

## Next

Routing: [05-navigation-and-routing.md](05-navigation-and-routing.md).
Data: [06-networking-and-data.md](06-networking-and-data.md).
