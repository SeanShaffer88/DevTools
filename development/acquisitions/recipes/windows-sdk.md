# Windows SDK and MSVC Build Tools

Status: **restricted-with-original**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: none; restricted vendor payload excluded.

Original offline substitute: `original/offline_contracts.py`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: MSVC compiler, Windows SDK/CRT/layout remain vendor-licensed and unbundled. Original contract records compiler/SDK/architecture/flags; it does not compile or replace Win32 APIs.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://learn.microsoft.com/en-us/visualstudio/install/create-an-offline-installation-of-visual-studio
