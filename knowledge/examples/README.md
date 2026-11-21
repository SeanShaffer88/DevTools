# Examples

There is no toy example here — the worked examples of this system
are the family's shipped projects. Read one against the docs to see
the rules in force:

| Project | What it demonstrates |
|---|---|
| SeanPak (github.com/SeanShaffer88/SeanPak) | A t2/t1b tool built *for* the pipeline: headless-first CLI with `--json` everywhere, deterministic exit codes, the packager every other project ships with |
| TesselGUI (github.com/SeanShaffer88/TesselGUI) | The design system as a project: `docs/tokens.json` as the single source of truth |
| WinDevKit (github.com/SeanShaffer88/WinDevKit) | A t2 monorepo: generated catalog, per-kit releases, bindings generated from the kit headers |
| TidyTray (github.com/SeanShaffer88/TidyTray) | A t1b tray utility: safety-first design (reversible actions, dry-run first runs, a kill switch), Carmine conformance, SeanPak packaging |
| RepoStacks (github.com/SeanShaffer88/RepoStacks) | A t3 app with a recorded TesselGUI **exemption** — its approved dark-ledger look stands instead; the exemption pattern from docs/01 in practice |
| SharpSnip (github.com/SeanShaffer88/SharpSnip) | A brief-specified stack deviation (C#/.NET + WPF) shipped inside the system's packaging and release rules |

When a project and a doc here disagree, the doc system wins for
future work — and the disagreement is worth flagging, because it
usually means an exemption or deviation that was never written
into the project's rule sheet.
