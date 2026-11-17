# 07 — Design: the TesselGUI system

Every program conforms to the latest **TesselGUI** — currently
v2.0.0 revision 3, the **Carmine** scheme — unless the owner exempts
the project in writing (an exemption is recorded in the project's
rule sheet, with its approved alternative).

## Carmine in brief

- Dark charcoal, near-black surfaces: editor `#1B1B1D`, panels
  `#232326`. Text `#E6E3E1` on them, muted text `#89868A`.
- **Carmine accent `#960018`** — used for action, focus, and
  selection, and **never as the only cue** (pair it with shape,
  position, or text so meaning survives color blindness and high
  contrast).
- A fine square grid texture (`#28282B`) on the main window.
- Compact-first density; Consolas-first type for code and data.
- The GitHub scheme survives as a preset; light mode takes the
  Carmine family; High Contrast is its own scheme and is unchanged
  by rethemes.

The full token set is in
[reference/tesselgui-carmine-tokens.md](../reference/tesselgui-carmine-tokens.md);
the machine-readable source of truth is `docs/tokens.json` in the
TesselGUI repo — check there for anything newer.

## Layout and interaction rules

- The responsive rules of docs/06 (DPI scaling, 4/8px grid, fluid
  containers, all control states) are part of conformance, not
  taste.
- **Scoped tooltips:** required on icon-only buttons, non-standard
  custom controls, status indicators, and column headers.
  Self-describing labeled buttons do not get redundant tooltips.
  (This scoping superseded an earlier tooltips-on-everything rule
  in 2026-11.)
- **The mockup gate:** design confirmation is required only for a
  new top-level window or a layout change bigger than a single
  dialog/menu. Mockups are shown as images.

## Conformance timing

New projects conform from day one. Existing projects adopt the
current TesselGUI at their next slice or release — a retheme is a
slice of its own, batched with that project's pending work, never a
drive-by edit inside another change.
