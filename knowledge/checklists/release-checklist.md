# Release checklist

One release = one grouped batch (docs/09). Nothing here is
optional without a recorded waiver.

## Gate

- [ ] Owner's say-so for this merge, this tag, and this release
      obtained (docs/05)
- [ ] Full gate run locally: all tests, all targets, output read;
      CI green on the exact head (docs/04)
- [ ] `QUALITY.md` current: no Fail dimension, score ≥85, waivers
      recorded (docs/04)
- [ ] Performance re-measured against the project's budgets; no
      unwaivered regression over 10%

## Version and packaging

- [ ] Version bumped in **every** copy: build props,
      program constant, **and** `seanpak.json` (docs/08)
- [ ] Packaged with the latest SeanPak; `seanpak verify` clean
- [ ] Exactly three assets: `AppName-v{VERSION}-x64-Setup.exe`,
      `AppName-v{VERSION}-x64-Portable.zip`, `SHA256SUMS.txt`
- [ ] TesselGUI conformance at the latest revision (or the
      project's recorded exemption stands)

## Publish and verify

- [ ] Publish batched: one push per publish; PRs/merges through
      the browser (docs/09)
- [ ] Published files read back and matched by git blob SHA
- [ ] Assets re-downloaded and matched against `SHA256SUMS.txt`
- [ ] Any non-CI-built binary PE-import-checked (system DLLs only)
- [ ] Release notes carry only this version's changelog section
- [ ] README, repo About description, and topics re-checked
      against what shipped; screenshots refreshed from real
      captures or the owed captures flagged
- [ ] Report labeled Verified / Partially Verified / Unverified —
      runtime not exercised stays Unverified
