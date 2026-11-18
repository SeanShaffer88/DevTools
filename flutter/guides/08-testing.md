# 08 — Testing

Flutter's test story is one of its strengths: the same Dart code
runs unit tests, widget tests in a simulated environment, golden
(screenshot) tests, and full integration tests on a real device —
all driven by `flutter test`. The discipline is layering: many
fast tests at the bottom, few slow ones at the top.

Testing docs: https://docs.flutter.dev/testing/overview

## The layers

| Layer | What it proves | Speed | Where it lives |
|---|---|---|---|
| Unit | One class/function behaves | Milliseconds | `test/` |
| Widget | One widget renders + reacts | Fast, no device | `test/` |
| Golden | Pixels did not change unexpectedly | Fast | `test/` |
| Integration | The whole app works on a device | Slow, real device/emulator | `integration_test/` |

If a behaviour can be tested at a lower layer, test it there.
Integration tests are for wiring and platform behaviour, not for
re-proving your business logic one slow boot at a time.

## Unit tests

Plain Dart, no Flutter runtime needed. This is where repositories,
models, and state logic (guides 04 and 06) earn their keep —
design them to be constructible with fakes and they are trivial
to test:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cart totals add up', () {
    final cart = Cart();
    cart.add('book', priceCents: 1200);
    cart.add('pen', priceCents: 300);
    expect(cart.totalCents, 1500);
  });

  test('empty cart totals zero', () {
    expect(Cart().totalCents, 0);
  });
}
```

Group related cases with `group(...)`, and name tests as
sentences about behaviour, not about methods.

## Mocking with mocktail

When a class depends on an API client or a database, substitute a
fake. `mocktail` is the common Dart choice because it needs no
code generation and is null-safety native:

```dart
class MockApiClient extends Mock implements ApiClient {}

void main() {
  test('repository maps a 200 into items', () async {
    final api = MockApiClient();
    when(() => api.getItems()).thenAnswer((_) async => ['a', 'b']);

    final repo = ItemRepository(api);
    expect(await repo.getItems(), ['a', 'b']);
    verify(() => api.getItems()).called(1);
  });
}
```

Prefer hand-written fakes for simple interfaces (a class with
canned answers is easier to read than a wall of `when(...)`), and
mocktail when the interface is wide or you need verification.
Verify the current mocktail version on pub.dev before adding it.

## Widget tests

Widget tests pump a widget into a test environment and interact
with it through finders and gestures — no emulator required:

```dart
testWidgets('counter increments on tap', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CounterPage()));

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();   // run one frame after the tap

  expect(find.text('1'), findsOneWidget);
});
```

Essential vocabulary:

- `tester.pumpWidget(...)` — build the widget tree.
- `find.text`, `find.byType`, `find.byKey`, `find.byIcon` — locate.
- `tester.tap`, `tester.enterText`, `tester.drag` — interact.
- `tester.pump()` — advance one frame; `pumpAndSettle()` — run
  until animations finish (careful: it times out on infinite
  animations like a spinning progress indicator).
- Wrap the widget under test in `MaterialApp` (or the app's real
  theme/providers) — most widgets assume those ancestors exist.

Widget tests are the workhorse for screens: states render, buttons
call callbacks, error states appear when the state says so.

## Golden tests: pixels as the assertion

A golden test renders a widget and compares it, pixel by pixel,
against a committed reference image:

```dart
testWidgets('item card golden', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: ItemCard(name: 'Book', priceCents: 1200)),
  );
  await expectLater(
    find.byType(ItemCard),
    matchesGoldenFile('goldens/item_card.png'),
  );
});
```

Workflow:

```powershell
flutter test --update-goldens   # create / refresh reference images
flutter test                     # compare against them
```

Rules for goldens that do not become a burden:

- Golden-test *components and key screens*, not every widget.
- A golden failure means "pixels changed" — sometimes that is the
  change you intended (update the goldens and review the diff in
  the pull request), sometimes it is a regression. The review of
  the image diff is the test.
- Fonts and platform rendering differ between machines. Generate
  and compare goldens on the same platform — in practice, let CI
  own the golden images, and load real fonts in the test setup if
  text rendering matters.

## Integration tests

Integration tests run the real app on a device or emulator and
drive it end to end — the smoke test that the pieces are wired
together. They live in `integration_test/` and use the
`integration_test` package.

**Non-negotiable setup detail:** `integration_test` comes from
the Flutter SDK, never from pub. In `pubspec.yaml` it is declared
exactly like this:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

If you ever see a version number pinned against `integration_test`
from pub.dev in a project, that is a version mix-up — fix it to
the SDK form above.

```dart
// integration_test/app_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in and see the home screen', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('email')), 'a@b.c');
    await tester.enterText(find.byKey(const Key('password')), 'secret');
    await tester.tap(find.byKey(const Key('sign_in')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });
}
```

```powershell
flutter test integration_test/app_test.dart -d <device-id>
```

Keep integration tests few, stable, and about the critical path
(sign in, core flow, purchase-shaped flow). Flaky integration
tests get deleted; design them against keys and real waiting
conditions, not fixed sleeps, so they survive.

## Running everything, and CI

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

That trio is the local gate and the CI gate — same commands, so
"green on my machine" and "green in CI" mean the same thing. In
CI, run unit/widget/golden tests on every pull request (fast, no
device farm needed), and integration tests on an emulator or
device job on merge or nightly, where their cost is justified.

Before declaring any change done, be able to say which of these
actually ran — format, analyze, tests, and a build for the target
platform — and label anything that did not run as Unverified
rather than assuming it would pass.

## Next

Back to state: [04-state-management.md](04-state-management.md).
Data under test: [06-networking-and-data.md](06-networking-and-data.md).
