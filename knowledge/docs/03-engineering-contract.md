# 03 — The engineering contract (V4.0 distilled)

## Universal mandates (all tiers)

- **Zero cloud, zero telemetry.** Programs function air-gapped. The
  single allowed network behavior is an optional update check that
  offers, never forces, and can be switched off (docs/06).
- **Respect the user.** No nagging, no dark patterns, no selling
  data. Software is completely free; optional donations never
  unlock anything.
- **Config carries `schema_version`.** Every config file declares
  its schema version and ships explicit, tested upward migrations —
  a CI migration fixture per version bump. A failed migration backs
  up and quarantines; it never silently discards user data.
- **Atomic writes** for anything the user would miss; DPAPI for
  sensitive data at rest on Windows; WAL/checkpoint-style recovery
  where a store can be interrupted.
- **Validate all input.** Malformed user data is quarantined and
  reported, never silently dropped and never a crash.
- **Local structured logs only.** Nothing leaves the machine.

## Override classes — who may bend what

| Class | Covers | Who decides |
|---|---|---|
| A | Numeric caps (RAM, budgets) and stack choices | The owner, in-session, explicitly |
| B | Style and tooling preferences | The helper, self-serve |
| C | The universals above | Never violated silently by an agent; the owner changes them only by amending the contract |

## The release matrix (as amended)

Every desktop release (t1a/t1b/t3) ships exactly:

- `AppName-v{VERSION}-x64-Setup.exe`
- `AppName-v{VERSION}-x64-Portable.zip`
- `SHA256SUMS.txt`

No `.msi` — ever, at any tier. No x86 or ARM64 variants. t2 ships
per-target-triple zips, t4 the addon zip, t5 apk/aab — each still
with `SHA256SUMS.txt`. All desktop installers are built by SeanPak
(docs/08). t1a/t1b programs support `--clean` / `--uninstall`
alongside the standard flag set (`--headless`, `--json`, `--silent`,
`--dry-run`, `--verbose`, `--debug`, `--trace` where they apply).
