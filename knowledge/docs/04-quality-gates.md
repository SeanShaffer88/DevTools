# 04 — Quality gates (the Elite Prompt distilled)

## Benchmark first

Before designing, study what the leading programs in the category
do. If the plan is missing a capability every leader has, flag it
with an Include / Defer / Reject recommendation. Benchmarking is an
internal step; public docs never carry competitor comparisons.

## Everything is an operation

Each capability is implemented once, as an operation (command) in a
registry, and every surface — window, CLI, JSON channel, scripting —
dispatches to it. A feature that exists only inside a click handler
is a defect (failure mode 7 below): untestable, unscriptable,
unreusable.

## The QUALITY.md gate

Every substantial project keeps a `QUALITY.md`, scored from
evidence, never from impressions:

- Any dimension scored **Fail** means the work is **not done**.
- Overall score must reach **85**, with **no dimension under 3**.
- A fresh-context adversarial pass reviews what the builder built;
  the builder is never the sole reviewer of their own work.
- A missed budget is recorded as a **waiver** with a reason and a
  follow-up — thresholds are never quietly edited. Minor waivers
  the helper may grant; major ones need the owner.

## Coverage and certainty floors

- Coverage: **85%** of core logic, **70%** overall, **100%** of
  safety paths (destructive actions, migrations, parsing of
  untrusted input).
- Certainty: **≥95%** overall before building; **100%** on
  irreversible or security-relevant choices. Below the floor, stop
  and present described options.
- The gate is the **full** gate: all tests, all targets, output
  actually read. A filtered subset presented as a gate is failure
  mode 5.

## The failure modes the gate exists to catch

| # | Mode | Catch |
|---|---|---|
| 1 | Demo-ware | A polished slice hiding an unfinished core |
| 2 | Happy-path only | No error/empty/offline states; tests that never fail anything |
| 3 | Silent scope narrowing | A requirement quietly reinterpreted into something easier |
| 4 | Invented API or fact | A call, flag, or claim no source supports |
| 5 | Filtered gate | Only some tests run before merge/release |
| 6 | Self-graded homework | Builder as sole reviewer; scores without evidence |
| 7 | GUI-only feature | Capability trapped in a UI handler |
| 8 | God function / god file | One unit doing everything |
| 9 | Copy-paste twins | Same logic in two places, drifting |
| 10 | Silent data loss | Parse failure discards; migration overwrites the original |
| 11 | Swallowed errors | Empty catches; "success" reported on failure |
| 12 | Unbounded work | No limits on loops, caches, retries, polling |
| 13 | Secret in the open | Key, token, or personal data in code, logs, or docs |
| 14 | Dependency by default | A library added "because everyone uses it" |
| 15 | Novelty over native | A custom control where a standard one exists |

## PARITY.md

Substantial projects keep `docs/PARITY.md`: the capability matrix
against the category leaders, scored only from test and corpus
evidence. The test corpus grows with every slice.
