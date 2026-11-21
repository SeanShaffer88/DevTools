# The standard document set

Every project carries the files from this set **that genuinely
apply to it** — real content only, no placeholders, no invented
facts. Public docs hold factual product documentation only.

## In `docs/` (on main)

`AUDIT.md` · `CHANGELOG.md` · `FEATURES.md` · `COMPATIBILITY.md` ·
`ROADMAP.md` · `BENCHMARK.md` · `CREDITS.md` · `CONTRIBUTING.md` ·
`CODE_OF_CONDUCT.md` · `SUPPORT.md` · `SECURITY.md` ·
`MAINTAINERS.md` · `GOVERNANCE.md` · `ARCHITECTURE.md` ·
`TROUBLESHOOTING.md` · `INSTALL.md` · `MIGRATION.md`

## At the repo root

`README.md` · `LICENSE.md`

Root placement is deliberate: GitHub only detects a license at the
root, and the root README is the repo's face. Never keep duplicate
copies of a file in both places — they drift.

## Rules

- Only files that genuinely apply ship. No `MIGRATION.md` where
  nothing has ever migrated; no `BENCHMARK.md` where nothing is
  measured.
- Where a platform format mandates its own placement (WoW addon
  root files, a PortableApps tree), the format wins.
- Files a project already keeps at its root (`CHANGELOG.md`,
  `FEATURES.md`, `ROADMAP.md`, …) move into `docs/` when the
  project adopts the standard, with inbound links updated.

## Rollout

New projects from day one; existing active projects at their next
slice or publish (no mid-release retrofit); abandoned and paused
projects untouched.
