# AGENTS.md — rules for any AI working in this system

You are building Windows desktop software under a layered rule
system. This file is the short form. The docs carry the detail; the
full source texts are named in [SOURCES.md](SOURCES.md) and win on
conflict with any summary, including this one.

## The layers, in force order

1. The owner's current instruction for the task at hand.
2. The Elite Software Master Prompt — governs all projects.
3. The Adaptive Engineering Contract (V4.0) — tiers, stacks,
   universals, override classes.
4. The AI Coding Guardrails & Operating Contract — 19 points, as
   amended by the owner (see docs/05).
5. The Universal Windows Desktop Master Prompt — Windows-specific
   supporting detail.
6. The project's own rule sheet (its Appendix 7 instantiation).

## Non-negotiables

1. **Classify before building.** Every project declares its tier
   (t1a–t5) in a `.project-tier` file and a Project Manifest block;
   the tier's rules are inert outside that tier.
2. **Everything is an operation.** A feature is implemented first as
   an operation/command callable identically from GUI, CLI, and any
   other surface. No GUI-only features.
3. **The gate is hard.** `QUALITY.md` scored from evidence; any Fail
   dimension means not done. Coverage floors: 85% core, 70% overall,
   100% on safety paths. Certainty ≥95% before building, 100% on
   irreversible or security-relevant choices — below that, ask with
   described options.
4. **No new external dependency without the owner's explicit
   approval**, plus a licence check, a register entry, and an exit
   sketch. Prefer the standard library and platform APIs.
5. **Zero cloud, zero telemetry.** Programs work fully offline;
   the one allowed network touch is an optional, switch-off-able
   update check that offers and never forces.
6. **One release shape.** `AppName-v{VERSION}-x64-Setup.exe` +
   `AppName-v{VERSION}-x64-Portable.zip` + `SHA256SUMS.txt`. No
   MSI, no other architectures, no bare exes. Packaged with SeanPak,
   themed with TesselGUI, unless the owner exempts the project.
7. **Never winget.** No code-signing certificate exists; binaries
   ship unsigned and the docs say so. Never propose winget.
8. **Merges, tags, and releases need the owner's explicit say-so
   for that instance.** Local commits and feature-branch work
   proceed freely. Batch publishes into the fewest operations.
9. **Never lose the user's work.** Autosave; destructive actions
   get undo, a backup, or a preview first. Config files carry a
   `schema_version` with tested upward migrations.
10. **Public docs are product facts only.** No references to the
    owner, briefs, or process. READMEs open with `## TL;DR` and use
    only real screenshots from the owner's machine.
11. **Report honestly.** Label claims Verified / Partially Verified
    / Unverified. Runtime that only the owner's machine can prove
    is recorded Unverified — never ask the owner to field-test.
12. **Pause means pause.** A pause/stop on a project halts all work
    on it until the owner says resume; leave a clean state and a
    summary. Pauses are per-project and literal.
