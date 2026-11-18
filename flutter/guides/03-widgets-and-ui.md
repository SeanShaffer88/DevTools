# 03 — Widgets and UI

Everything on screen in Flutter is a widget — including layout,
padding, and even the app itself. Widgets are immutable
descriptions; Flutter compares new descriptions against the old
tree and updates only what changed.

Widgets catalog: https://docs.flutter.dev/reference/widgets
Layout guide: https://docs.flutter.dev/ui/layout

## The one mental model

> **Constraints go down. Sizes go up. The parent sets position.**

A parent passes constraints ("be between this wide and that
wide") to its children. Each child picks a size inside those
constraints. The parent then decides where the child sits. Almost
every layout surprise in Flutter is one of these three steps being
different from what you assumed — usually an *unbounded* constraint
(a scroll view inside a column is the classic).

## Stateless vs Stateful

A `StatelessWidget` is a pure function of its inputs:

```dart
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Text('Hello, $name');
  }
}
```

A `StatefulWidget` owns mutable state that survives rebuilds:

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$_count'),
        ElevatedButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
```

Why two classes? The widget object is recreated on every rebuild;
the `State` object is not. Configuration lives on the widget
(`widget.name`), mutable data lives in the state.

`setState` tells the framework "this state changed, rebuild me".
Call it for the change, never as a general refresh hammer — see
guide 04 for when to outgrow it.

## BuildContext

Every `build` receives a `BuildContext`. Think of it as the
widget's *location in the tree*: it is how a widget looks up
inherited services — theme, size, navigation, localization:

```dart
final theme = Theme.of(context);
final width = MediaQuery.sizeOf(context).width;
```

Rules that save hours:

- A context can only see **ancestors**, never descendants or
  siblings. "No Material widget found" and similar errors usually
  mean you used a context from *above* the widget that provides
  the thing.
- If you need a context below a provider, insert a `Builder` widget
  to get a fresh context at that point in the tree.
- Never store a context and use it after an `await` without
  checking `context.mounted` — the widget may be gone.

## Layout essentials

| Widget | What it does |
|---|---|
| `Column` / `Row` | Stack children vertically / horizontally |
| `Expanded` / `Flexible` | Share leftover space inside a Column/Row |
| `Padding` | Inset a child (prefer this over margin containers) |
| `SizedBox` | Fixed size, or a spacer with one dimension set |
| `Stack` + `Positioned` | Overlap children |
| `ListView` / `GridView` | Scrolling lists — use `.builder` for long ones |
| `ConstrainedBox` / `Align` / `Center` | Extra constraints / positioning |

```dart
Row(
  children: [
    const Icon(Icons.star),
    const SizedBox(width: 8),
    Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
    Text(price),
  ],
)
```

Always use `ListView.builder` (not a Column of children) for lists
whose length you do not control — builder creates rows lazily as
they scroll into view.

## Material, Cupertino — and the big 3.50 change

Flutter's design-system widgets historically shipped *inside* the
SDK: `import 'package:flutter/material.dart'` and
`package:flutter/cupertino.dart`. Most existing code, tutorials,
and packages still use those bundled imports, and they still work.

**Flutter 3.50 changes the direction.** The bundled Material and
Cupertino implementations are **deprecated in favour of standalone
packages**:

- `material_ui` — the Material implementation as its own package
- `cupertino_ui` — the Cupertino implementation as its own package

Both packages reached **1.0 in Flutter 3.47**, so they are not
experiments. The reason for the split: the design systems can now
be versioned and updated on pub.dev's schedule instead of waiting
for a quarterly Flutter release, and apps can pin a design system
independently of the framework.

How to act on this:

1. **Existing apps:** keep building. Run the automated migration
   when you adopt the new packages — `dart fix` applies the
   mechanical import/API updates.
2. **Use the compatibility bridge during migration:**
   `MaterialUiCompatibilityBridge` exists so an app can move
   incrementally instead of in one flag-day rewrite.
3. **New apps:** evaluate starting on `material_ui` /
   `cupertino_ui` directly, and say which choice the project made
   in its readme — mixed assumptions between bundled and package
   widgets are the failure mode to avoid.
4. **Learning:** learn concepts (scaffolds, buttons, dialogs,
   navigation) once — they carry across both. When a tutorial's
   imports differ from your project's, that is the split, not an
   error in the tutorial.

## Theming

Define the theme once at the app root; widgets read it through
`Theme.of(context)`:

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    useMaterial3: true,
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  ),
  home: const HomePage(),
)
```

`ColorScheme.fromSeed` generates a coherent Material 3 palette
from one colour. Prefer theme values (`colorScheme.primary`,
`textTheme.titleLarge`) over hard-coded colours and font sizes in
widgets — that is what makes dark mode and rebranding cheap.

## Responsive and adaptive

Responsive = the layout uses the space it has. Adaptive = the UI
also follows platform conventions. Start with the space:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 700) {
      return const WideLayout();    // e.g. list + detail side by side
    }
    return const NarrowLayout();    // e.g. list only, tap to detail
  },
)
```

- Design breakpoints (for example ~600–700 logical pixels) around
  your content, not around named devices.
- On large screens, spend width on *more content at once*
  (two-pane layouts), not on stretched phone UI.
- Test with the window resized, not only on fixed emulator sizes —
  desktop and foldables change size at runtime.

## Performance habits that matter early

- Mark constructors `const` wherever possible; `const` widgets are
  reused instead of rebuilt.
- Keep `build` methods cheap and side-effect free — they run often.
- Split big widgets into small widget classes rather than helper
  methods returning widgets: classes give Flutter a stable tree
  node to reuse, methods do not.
- Reach for `ListView.builder`, image caching, and profiling
  (DevTools) before reaching for micro-optimisations.

## Next

State management: [04-state-management.md](04-state-management.md).
Routing: [05-navigation-and-routing.md](05-navigation-and-routing.md).
