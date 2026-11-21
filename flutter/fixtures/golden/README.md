# Golden tests

A golden test renders a widget, captures it as a PNG image (the
"golden file"), and on later runs re-renders the widget and fails
if the pixels differ beyond tolerance. Goldens pin the *look* of a
widget the way a unit test pins its behavior — ideal for design
system components, list rows, cards, and empty/error states.

## How they work

```dart
testWidgets('item tile matches golden', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: ItemTile(item: sampleItem))),
  );
  await expectLater(
    find.byType(ItemTile),
    matchesGoldenFile('goldens/item_tile.png'),
  );
});
```

- First run / after an intentional visual change: regenerate the
  goldens with `flutter test --update-goldens`. Review the image
  diffs like code — an updated golden you did not look at is a test
  you silently rewrote.
- Plain runs (`flutter test`) compare against the committed PNGs
  and fail on differences, writing diff images under
  `test/failures/` for inspection.
- Goldens are sensitive to font rendering, device pixel ratio, and
  platform. Keep golden tests on one reference platform in CI (the
  usual choice is the Linux runner), pin the test font setup, and
  avoid goldens for widgets that embed platform-native views or
  network images.
- Custom comparison tolerance and per-platform handling go through
  `GoldenFileComparator` — see the Flutter testing guide in this
  resource pack before building anything elaborate.

## What is in this folder

Nothing — on purpose. **There are no PNG golden files in this
fixture pack, and none should be trusted if copied from anywhere
other than a run of your own project.** A golden is only meaningful
for the exact widget code, fonts, Flutter version, and platform
that produced it; a placeholder PNG shipped here would fail every
real project and teach the wrong lesson. Generate goldens from your
own widgets with `--update-goldens`, eyeball them, and commit the
PNGs next to the tests that use them.
