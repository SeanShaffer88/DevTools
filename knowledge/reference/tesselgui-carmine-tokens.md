# TesselGUI Carmine tokens (reference extract)

The key values of TesselGUI v2.0.0 revision 3 (Carmine). The
machine-readable source of truth is `docs/tokens.json` in the
TesselGUI repo — when a value here and the JSON disagree, the JSON
wins. See [docs/07](../docs/07-design-tesselgui.md) for how the
scheme is applied.

## Core colors (dark)

| Token | Value | Role |
|---|---|---|
| background | `#1B1B1D` | Editor / main background |
| surface | `#1F1F22` | Surface |
| raised | `#232326` | Panels |
| selected | `#2A2A2F` | Selected row |
| selectedStrong | `#33333A` | Strong selection |
| hover | `#28282D` | Hover fill |
| pressed | `#2E2E34` | Pressed fill |
| foreground | `#E6E3E1` | Primary text |
| muted | `#89868A` | Secondary text |
| border | `#76767C` | Borders |
| edge | `#43434A` | Material edge |
| grid | `#28282B` | The fine square grid texture |
| surround | `#191919` | Window surround |
| accent | `#960018` | **Carmine** — action, focus, selection indicator |
| actionHover | `#A81226` | Action hover |
| actionPressed | `#7E0014` | Action pressed |
| actionForeground | `#FFFFFF` | Text on Carmine |
| progress | `#B8AAA0` | Progress |
| info | `#72AAA5` | Informational |
| warning | `#C9A86A` | Warning |
| success | `#A3B58A` | Success |
| danger | `#E8939F` | Danger |
| textSelection | `#3F3F46` | Text selection |
| disabledForeground | `#89868A` | Disabled text |
| disabledFill | `#1B1B1D` | Disabled fill |
| readOnlyFill | `#232326` | Read-only fill |

Status fills pair with their foregrounds: infoFill `#1C2B29`,
warningFill `#2E2617`, successFill `#222B1D`, dangerFill `#3B1B22`.
Find: findMatch `#4A3E24`, findMatchActive `#63552F`.

## Spacing

Scale (CSS-pixel-equivalent; adapt to native units and user
scaling): **4, 8, 12, 16, 24, 32**. Compartment gutter 8, control
gap 8 (minimum 6), panel padding 8, related-group gap 12–16,
section gap 24.

## Rules that travel with the tokens

- Carmine is never the only cue for meaning.
- Compact-first density; Consolas-first for code and data.
- Light mode uses the Carmine family; High Contrast is a separate
  scheme and is not rethemed by Carmine changes.
