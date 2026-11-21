# Userscript manager and documentation

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `violentmonkey-source`, `violentmonkey-extension`.

Remaining requirements and limits: Official Violentmonkey webextension ZIP and exact MIT source retained. No extension installation, signing compatibility, browser activation, storage/grants or actual userscript workflow verified.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://violentmonkey.github.io/api/metadata-block/
- https://www.tampermonkey.net/documentation.php
