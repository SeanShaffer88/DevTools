# 10 — Project lifecycle

## Storytold orchestration (how parallel work runs)

1. **Foundation freeze first.** Module layout, layering, and
   interfaces are frozen and written into the repo before any
   parallel work starts. An interface change lands alone, first.
2. **Swarm: 6–8 agents maximum**, one directory each, working from
   the standard brief. Workers never commit, push, or open PRs.
3. **The integrator merges serially**, personally running the FULL
   gate on each worktree and again on the merged tree.
4. Every substantial project keeps `docs/PARITY.md` and a test
   corpus that grows per slice (docs/04).

New projects run this way from day one; existing projects adopt it
at their next substantial slice or major version.

## The standard document set

Every project carries the files from the standard set that
genuinely apply — 17 in `docs/`, plus `README.md` and `LICENSE.md`
at the root (never duplicated in both places). The full list and
its rules are in
[reference/standard-docs-set.md](../reference/standard-docs-set.md).
Real content only; platform-mandated placement (a WoW addon's root
files, a PortableApps layout) wins over the set.

## Repo rules

- Every repo gets its **About description and topics** filled at
  creation, and re-checked at every release (docs/09).
- **README** opens with `## TL;DR` in plain words, then features,
  real screenshots, requirements from evidence, install steps,
  usage, configuration, build instructions, troubleshooting for
  real known errors, and honest limitations. Anything undetermined
  is written "To be confirmed" — never guessed.
- **MIT by default** for the owner's projects, unless a different
  license is recommended for a specific project and the owner
  agrees.
- Public docs contain factual product documentation only — no
  references to the owner, briefs, or design process, and no
  competitor comparisons by default.

## Slices, pauses, and stops

- Plan **fewer, larger combined slices**: one slice carries
  everything that belongs together.
- **Local first** whenever local is faster — builds, tests, gates,
  packaging prep. GitHub is for hosting, PRs, releases, and what
  local cannot genuinely produce.
- **Pause protocol:** when the owner says pause/stop on a project,
  stop — no changes, commits, or PRs until an explicit resume.
  Leave the work clean and safe, and hand over a summary: what is
  completed, what is in progress, any uncommitted changes, and the
  next steps. Pauses are literal and per-project; one project's
  pause never bleeds into another's, and an abandoned project is
  never revived or re-suggested without the owner's word.
