# 08 — Packaging with SeanPak

Every Windows program release is packaged with **SeanPak** — the
per-project installer scripts (NSIS, Inno, hand-rolled WiX) are
retired as a packaging route. A project's release workflow calls
SeanPak; it does not build its own installer.

## The pipeline

Manifest + payload files in → three assets out:

- `AppName-v{VERSION}-x64-Setup.exe`
- `AppName-v{VERSION}-x64-Portable.zip`
- `SHA256SUMS.txt`

SeanPak's primary user is the build pipeline itself: the headless
route (`seanpak pack` with `--json`, `--silent`, `--dry-run`) is
the main workflow, with deterministic exit codes and a JSON report;
the Builder GUI is secondary. Full CLI parity applies to SeanPak
like everything else (docs/06).

## The manifest

Each project carries a `seanpak.json`: app identity, version,
payload layout, install location token, and options. A starter is
in [templates/seanpak-template.json](../templates/seanpak-template.json).
Version strings live in more places than the manifest (project
build props, a program constant) — a version bump updates **every**
copy, and the release checklist (checklists/release-checklist.md)
asks for each one by name.

## Install behavior (owner's directives)

- **Per-user by default.** The default install location is the
  per-user Programs folder (`%LOCALAPPDATA%\Programs\<App>`),
  never Program Files. Writability is checked before anything
  changes; if the chosen folder is not writable, the per-user
  location is offered as fallback — never a silent elevation.
- Desktop icon by default; "launch after setup" ticked by default.
- **Silent auto-update when already installed:** a newer installer
  run over an existing install updates in place, closing and
  relaunching running instances; only a process that refuses to
  close interrupts, once.
- The installer enforces a declared Windows-version floor, packs
  declared Microsoft redistributable prerequisites at build time
  (never downloaded at install time — zero cloud), and offers
  repair through Modify/uninstall.
- Portable installs are a first-class choice, including an
  `extract` command that unpacks without installing.

## Verify before calling it shipped

`seanpak verify` plus the read-back discipline of docs/09: assets
re-downloaded, hashes matched against `SHA256SUMS.txt`, and any
hand-built binary PE-import-checked (system DLLs only) before it is
attached to a release.
