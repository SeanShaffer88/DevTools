# 01 — The system at a glance

Five layers, one direction of authority: a higher layer wins on
conflict unless the owner says otherwise in the moment.

| # | Layer | Decides |
|---|---|---|
| 1 | The owner's current instruction | This task, this instance — including one-off exemptions |
| 2 | Elite Software Master Prompt | How software is conceived and judged: benchmark-first, operations, quality gate, certainty, budgets, honesty |
| 3 | Adaptive Engineering Contract V4.0 | What a project is (tier), what it may be built with (stacks), the universals, the release matrix |
| 4 | AI Coding Guardrails | How the work itself is conducted: dependencies, secrets, testing, failure stops, reporting |
| 5 | Windows Desktop Master Prompt | Windows-specific craft: UX, accessibility, safety protocols, evidence labels |
| 6 | The project's rule sheet | This project's instantiation: purpose, frozen foundation, build/gate commands, budgets, special rules |

## How a project adopts the system

- **New projects** are under the system from day one: the rule sheet
  is created at project start, the tier is declared, the standard
  documents are seeded (docs/10).
- **Existing projects** adopt the project-level artefacts (rule
  sheet, `QUALITY.md`, `docs/PARITY.md`) at their next substantial
  slice or major version. Never retrofit a shipped project
  mid-release.
- **Abandoned and paused projects** are untouched until the owner
  resumes them.
- **Exemptions are explicit.** The owner may exempt a project from a
  layer's piece (for example a design-system exemption with an
  approved alternative look). An exemption is recorded in the
  project's rule sheet and never assumed from silence.

## Activation, for substantial work

Before building anything substantial, the helper:

1. Restates the brief in its own words.
2. States its certainty against the floors in docs/04.
3. Surfaces missing fields as decisions — multiple described
   options with trade-offs and a recommendation, never a single
   take-it-or-leave-it.
4. Classifies the project (tier + rationale) and checks the stack
   against docs/02 before writing code.

## What the system optimizes for

Software that is free, offline, dependable, and pleasant in the
first minute; releases that are few, grouped, and verified; and an
owner who directs in short bursts without wading through approval
prompts — because publishing is batched and the irreversible steps
(merge, tag, release, permanent delete) are the only ones that wait
for a say-so.
