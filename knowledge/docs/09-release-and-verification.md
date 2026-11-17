# 09 — Release and verification

## The shape (no exceptions without the owner's word)

Exactly three assets per desktop release:

- `AppName-v{VERSION}-x64-Setup.exe`
- `AppName-v{VERSION}-x64-Portable.zip`
- `SHA256SUMS.txt`

x64 only. No MSI, no ARM64/x86 variants, no PortableApps zips, no
bare loose exes. Distribution is GitHub Releases only — **never
winget** (no code-signing certificate exists; binaries ship
unsigned and the release notes say so honestly).

## Cadence

- **Grouped releases.** Small fixes accumulate on main and ship
  together in the next grouped release; a fix does not get its own
  version.
- **Substantial PRs only.** Batch related work into one substantial
  pull request; trivial changes ride the next batch.
- **The gate before the release:** merges, tags, and releases each
  need the owner's explicit say-so for that instance (docs/05).
  Work that reaches a publish step without it holds there and
  reports ready.
- **Batch the publish.** One batched push per publish wherever it
  fits; everything else (PRs, merges, branch ops) through the
  signed-in browser. Never loop per-file writes.

## Verification (all of it, every time)

1. The **full gate** ran locally first — all tests, all targets,
   output read (docs/04). CI confirms; it does not substitute.
2. Published files are **read back** and compared by git blob SHA
   (byte-identity), not by eyeballing rendered pages.
3. Release assets are **re-downloaded** after upload and matched
   against `SHA256SUMS.txt`.
4. Any binary built outside the proven CI route is
   **PE-import-checked**: its imports must be system DLLs only. A
   hash match alone has shipped a broken binary before — hash
   proves identity, not loadability. Tauri release assets come
   from the MSVC CI route, never a local cross-build; Electron
   Windows releases likewise ship from the Windows CI workflow.
5. **Release documentation sync:** the release carries only that
   version's own changelog section; README, repo description, and
   topics are re-checked for accuracy against what shipped, and
   screenshots are refreshed from real captures (owed captures are
   flagged, never faked).

## Honest labels

Every claim in a release report is labeled **Verified**,
**Partially Verified**, or **Unverified**. Windows runtime behavior
that was not exercised stays Unverified — recorded plainly, never
smoothed over, and never turned into a request for the owner to
field-test.
