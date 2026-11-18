# 13 — Performance and DevTools

Flutter performance work has one golden rule: **measure in profile
mode, on a real device, with the built-in DevTools suite** — never
from debug mode, never from vibes. This guide covers the build modes,
the tools, and the small set of habits that prevent most jank.

Snapshot: **Flutter 3.50.0 / Dart 3.14.0**. **DevTools ships with the
Flutter SDK** — there is nothing separate to install.

## Build modes: debug, profile, release

| Mode | What it is for | Performance truth? |
|---|---|---|
| **Debug** | Day-to-day development: hot reload, asserts, debugger, service extensions | **No.** Debug is deliberately slower (JIT, checks, no optimisation) |
| **Profile** | Performance measurement: release-like AOT code, just enough service support for DevTools profiling | **Yes.** This is the mode you measure in |
| **Release** | Shipping: fully optimised, no debugger/profiler hooks | Yes, but you cannot profile it — profile mode exists precisely for this |

```powershell
flutter run --profile -d <device>
flutter build appbundle --release   # shipping (guide 10)
```

Judging frame times from a debug build is the most common Flutter
performance mistake. The second most common is measuring on an
emulator — use the slowest real device your users plausibly own.

## DevTools: the suite that ships with the SDK

Launch it from your IDE or with `flutter devtools` / the URL printed
by `flutter run`. The parts that matter most:

- **Performance view** — frame chart (UI thread + raster thread bars
  per frame), timeline events, and the "slow frame" story at a
  glance. A frame that misses its budget (about 16.6 ms at 60 Hz,
  8.3 ms at 120 Hz) shows up red.
- **CPU profiler** — where time actually goes in a recorded window;
  find the one expensive function instead of optimising ten cheap
  ones.
- **Memory view** — allocation tracking and snapshots; look for
  growth across repeated navigation (leaks in Flutter are usually
  undisposed controllers and subscriptions, see below).
- **Widget inspector** — the widget tree live, layout constraints,
  and "why is this rebuilding" questions; pair it with the
  inspector's rebuild indicators while profiling.
- **Network view** — every request your app made, timing and payload;
  pairs with [guide 06](06-networking-and-data.md).
- **Logging / debugger** — structured logs and breakpoints when the
  print statement is not enough.

Also new in this era: **Widget Previews are stable** (since Flutter
3.47) — the DevTools/IDE preview environment renders widgets outside
a running app, which is as much a design-iteration speed tool as a
performance one.

## Jank: what actually causes it

A frame has two budgets: build/layout/paint on the **UI thread**
(your Dart code) and rasterisation on the **raster thread** (drawing
the pixels). The Performance view tells you which thread missed —
fix the one that's red.

Usual suspects, in order:

1. **Doing real work in `build()`** — parsing, sorting, I/O, heavy
   computation. `build` should be a pure, cheap description of state;
   move work into your state/repository layer (guide 14).
2. **Rebuilding too much of the tree** — a state change at the top
   repainting a whole screen. Narrow the scope of listeners/builders
   so only the widgets that changed rebuild.
3. **Expensive paint** — big saveLayer effects (opacity over large
   areas, clips, blurs, shadows) hammer the raster thread.
   `RepaintBoundary` isolates a frequently-repainting region (an
   animation, a chart) so it does not force the rest of the screen to
   repaint with it:

   ```dart
   RepaintBoundary(child: AnimatedChart(data: data))
   ```

4. **Images at full size** — decoding a 4000px photo into a 200px
   slot wastes memory and time; size image requests to their display
   size.
5. **Synchronous I/O on the UI isolate** — use async APIs, or a
   background isolate (`compute`) for genuinely heavy CPU work.

## const discipline (the cheap 20%)

`const` constructors let Flutter skip rebuilding identical widget
subtrees entirely. It is the highest-value habit in this guide:

- Make every widget constructor `const`-capable (`const MyWidget({super.key})`).
- Use literal `const` widgets wherever values are static.
- Turn on the lint that nags you (it is in `flutter_lints`, see
  [guide 01](01-getting-started-and-toolchain.md) / reference) and
  let the analyser enforce the habit.

Related hygiene: dispose every `AnimationController`,
`TextEditingController`, `ScrollController`, stream subscription, and
timer in `dispose()` — undisposed resources are both a leak and a
jank source.

## Lists and scrolling

- Build long lists lazily with `ListView.builder` / `GridView.builder`
  (never a `Column` of 500 children).
- Give list items stable keys when their identity matters, so the
  framework reuses elements instead of rebuilding.
- Profile the scroll itself in profile mode; scroll jank is usually
  per-item build cost, so make the item widget cheap and `const`
  where possible.

## A repeatable performance pass

1. `flutter run --profile` on the slowest target device.
2. Script the exact interaction (scroll this list, open that screen).
3. Open DevTools Performance; find the red frames; note UI vs raster.
4. CPU-profile the worst window; fix the top offender only.
5. Re-measure the same script. Record before/after numbers in the
   change that fixes it — a fix without a measurement is a guess.
6. Check startup separately: time to first frame is its own budget;
   defer initialisation that the first screen does not need.

## Checklist

- [ ] All performance claims measured in profile mode on a real device
- [ ] DevTools Performance + CPU views used, worst offender fixed first
- [ ] No heavy work or I/O inside `build()`
- [ ] `const` used wherever possible; controllers/subscriptions disposed
- [ ] Animations/charts isolated with RepaintBoundary where they repaint often
- [ ] Long lists use builder constructors; images sized to their slots
