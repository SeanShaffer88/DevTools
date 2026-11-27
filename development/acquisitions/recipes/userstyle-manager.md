# Userstyle manager and CSS target environment

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `stylus-source`.

Remaining requirements and limits: Stylus GPL3 exact source tree retained, not its compiled extension: corresponding npm build dependency source graph is not bundled. Browser/manager build/install/forced-colors workflows remain unverified.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://github.com/openstyles/stylus/wiki/UserCSS
