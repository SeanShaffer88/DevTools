# 05 — Navigation and Routing

Navigation is moving between screens and — on mobile and the web —
honouring the URLs and deep links that arrive from outside the app.
Flutter gives you a raw navigator and one dominant routing package.
Learn the raw tool, then use the package.

Official docs: https://docs.flutter.dev/ui/navigation

## Navigator: the built-in stack

Screens live on a stack. Push adds one, pop removes one:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const DetailsPage()),
);
Navigator.of(context).pop();   // back
```

Returning a result from a pushed screen:

```dart
final picked = await Navigator.of(context).push<String>(
  MaterialPageRoute(builder: (_) => const PickerPage()),
);
// in PickerPage: Navigator.of(context).pop('chosen value');
```

Named routes (`routes:` map + `pushNamed`) exist on `MaterialApp`,
but stringly-typed names with untyped arguments are exactly where
bugs breed. For anything past a demo, use the declarative router
below, which is also how deep links become tractable.

## go_router: the standard choice

`go_router` (**18.1.4**) is maintained in the official
`flutter/packages` repository and is the routing package the
Flutter team points developers to. Routes are declared as a tree
of paths; navigation is by location string or by route name:

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const HomePage(),
      routes: [
        GoRoute(
          path: 'items/:id',
          name: 'item',
          builder: (_, state) =>
              ItemPage(id: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);

MaterialApp.router(routerConfig: router);
```

Navigate imperatively when needed:

```dart
context.go('/items/42');        // replace the stack with this location
context.push('/items/42');      // stack it on top (back returns here)
context.goNamed('item', pathParameters: {'id': '42'});
```

`go` vs `push` is the one distinction to internalise: `go` declares
"the app *is at* this location" (tabs, top-level sections), `push`
is a detour the user backs out of (details, editors).

## Type-safe routes with go_router_builder

Path strings and `pathParameters['id']!` work, but they are
unchecked. `go_router_builder` generates typed route classes from
annotations, so wrong parameters stop compiling:

```dart
@TypedGoRoute<ItemRoute>(path: '/items/:id')
class ItemRoute extends GoRouteData with $ItemRoute {
  const ItemRoute({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ItemPage(id: id);
}

// call site — fully typed:
const ItemRoute(id: 42).go(context);
```

The generation step runs through `build_runner` — the same
workflow as JSON models in guide 06:

```powershell
dart run build_runner watch --delete-conflicting-outputs
```

Adopt the builder when routes gain query parameters, multiple
parameterised branches, or a team tired of string typos.

## Shell routes: persistent chrome

Tabs or a sidebar that stay on screen while inner content changes
are a *shell*: `StatefulShellRoute.indexedStack` keeps one
navigation stack per branch, so each tab remembers its place.
Reach for it instead of hand-rolling a `BottomNavigationBar` that
swaps bodies and throws away scroll positions and back stacks.

## Deep links

A deep link is an ordinary URL — `https://example.com/items/42`,
or an app scheme link — that should open the matching screen, from
a browser, an email, a notification, or another app.

With go_router, deep links are mostly already done: because the
app's location *is* a URL-shaped path, a link to `/items/42`
resolves through the same route table. Your remaining work is
platform registration:

- **Android:** an intent filter for your scheme/host in
  `AndroidManifest.xml`, plus App Links verification
  (`assetlinks.json` hosted on your domain) so links open the app
  instead of the browser.
- **iOS:** Associated Domains entitlement + `apple-app-site-association`
  hosted on your domain.
- **Web:** nothing extra — the URL is native there.

Test links cold (app killed) and warm (app running): the two paths
differ, and only cold testing catches missing registrations.

Platform setup changes over time — follow the current steps at
https://docs.flutter.dev/ui/navigation/deep-linking rather than
copying manifest snippets from old posts.

## Guards: redirects

Authentication gates and onboarding checks belong in one place:
go_router's `redirect`. It runs on every navigation and can send
the user elsewhere:

```dart
GoRouter(
  refreshListenable: authState,   // re-run redirect when auth changes
  redirect: (context, state) {
    final loggedIn = authState.isLoggedIn;
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/';
    return null;   // no redirect
  },
  routes: [ /* ... */ ],
);
```

Keep redirect logic small and total: it runs constantly, and a
redirect loop (A sends to B, B sends to A) hangs the app on a
blank screen. Always allow the destination itself through.

## Passing data between screens

Preference order, safest first:

1. **In the URL** — ids and filters (`/items/42?tab=reviews`).
   Survives deep links, restarts, and sharing.
2. **Typed route parameters** via go_router_builder (above).
3. **`extra`** — an in-memory object passed with `push`. Fine for
   a quick hand-off; it does *not* survive a deep link or a state
   restoration, so never make it the only copy of anything.

If a screen cannot rebuild itself from its URL plus your data
layer, it will break on deep links — that test is the design rule.

## Common mistakes

- Reading route arguments from a context *above* the router.
- Using `Navigator` and go_router interchangeably in one feature —
  pick the router's API inside routed code.
- Putting a whole object in the URL instead of its id.
- Forgetting `refreshListenable`, so login/logout does not
  re-trigger redirects until the next manual navigation.
- Hard-coding the initial route instead of letting a deep link in.

Verify the current go_router version on https://pub.dev before
adding it — 18.x is the line this guide was written against.

## Next

Data: [06-networking-and-data.md](06-networking-and-data.md).
Storage: [07-local-storage.md](07-local-storage.md).
