# New project checklist

Work top to bottom; each line is a rule from the docs named.

## Before code

- [ ] Brief restated; certainty ≥95% (100% on irreversible or
      security-relevant choices); missing fields surfaced as
      described options (docs/01, docs/04)
- [ ] Category leaders benchmarked internally; missing leader
      capabilities flagged Include / Defer / Reject (docs/04)
- [ ] Tier classified from the project's evidence; `.project-tier`
      written; `## Project Manifest` block added (docs/02)
- [ ] Stack checked against the tier's sanctioned routes; any
      alternate inside its hard constraints; any new external
      dependency approved by the owner first (docs/02, docs/05)
- [ ] Project rule sheet created from
      [templates/project-rules-template.md](../templates/project-rules-template.md)
- [ ] Foundation frozen: module layout, layering, operation
      registry location (docs/10)
- [ ] New top-level window or big layout change? Mockup shown as
      an image and confirmed (docs/07)

## Seeding

- [ ] Standard documents seeded — only the ones that genuinely
      apply (reference/standard-docs-set.md)
- [ ] README with `## TL;DR` first; About description + topics set
      on the repo (docs/10)
- [ ] MIT LICENSE unless a different license was agreed
- [ ] `QUALITY.md` created from the template; `docs/PARITY.md`
      started if the project is substantial
- [ ] Config design carries `schema_version` + a migration plan
      (docs/03)
- [ ] `seanpak.json` drafted from the template (docs/08)

## First slice

- [ ] Features land as operations first, surfaces second (docs/04)
- [ ] Every-program rules checked for the slice: CLI parity,
      autosave, undo/backup, help, states (docs/06)
- [ ] Full gate defined in the rule sheet and run — all tests, all
      targets, output read (docs/04)
