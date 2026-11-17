# 06 — Every-program rules

These apply to every Windows program in the family, whatever its
tier or stack.

## Capability and continuity

- **Full command-line support.** Every capability available in the
  window is usable from the command line (the CLI dispatches to the
  same operations — docs/04).
- **Never lose the user's work.** Programs save as the user goes,
  quietly and without being asked. After a crash or power cut,
  reopening restores the work exactly where it was left.
- **Reopen where they left off.** Last file, place, geometry, and
  settings restored (window geometry validated against the actual
  monitors); a short recent-items list.
- **Undo for anything destructive.** Delete, overwrite, or
  important change → undo, a backup copy first, or a preview with
  confirmation. Nobody ruins something with one wrong click.

## First minute and everyday use

- **Useful in the first minute.** The main job is doable within a
  minute of first opening: sensible defaults, no setup forms or
  account demands in the way.
- **Search wherever there's lots of stuff.** Many settings, files,
  or items → a search box.
- **Help inside the program.** A short plain-words guide (Help
  button or F1), fully offline.
- **Drag and drop.** File programs accept drops onto the window.
- **Audience-first.** Design for the program's actual users and
  situations; safe defaults for beginners, grouped and explained
  advanced controls for pros.

## Interface craft

- **Per-Monitor DPI v2 aware.** All spacing, padding, fonts, and
  control sizes scale with the DPI factor — relative units, never
  static pixels. Fluid layouts; a sensible minimum size below which
  secondary content clips, scrolls, or collapses instead of
  overlapping core controls. Text wraps or truncates cleanly with
  ellipsis. Icons are vector/scalable. Spacing follows a 4px/8px
  grid. Every interactive element has explicit hover, pressed,
  focused, disabled, and loading states. Test the extremes:
  minimum size, ultrawide/4K, 100%–300%+ scaling.
- **No primary-window scrollbars** — scrolling lives in virtualized
  lists. Real-time status where work happens (bytes, rate,
  progress), with fast cancellation.
- **Standard controls first**; a custom control must justify itself
  (docs/04, failure mode 15). Accessibility is required, not
  polish: keyboard paths, focus visibility, high-contrast survival.
- **Errors say what happened and how to fix it**, in plain words.

## Privileges and updates

- **No admin by default.** Programs run unelevated; when admin is
  genuinely required, the program explains why in plain words
  *before* asking.
- **Updates offered, never forced.** An optional update check (the
  one allowed network touch) may offer a newer version with a plain
  description of what's new. It never installs on its own, never
  nags after a "no", and can be switched off in settings.
- **No nagging, ever.** No review/rating/donation popups; a quiet
  donate link in the About box is the limit.
