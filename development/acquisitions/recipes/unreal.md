# Unreal Engine and authorized source/content

Status: **restricted-with-original**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: none; restricted vendor payload excluded.

Original offline substitute: `original/offline_contracts.py`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: No Epic engine/editor/partner content mirrored under restricted distribution terms. Original engine-neutral scene/input/save contract and tests are provided; no Unreal API/editor/rendering/build compatibility is claimed.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://www.unrealengine.com/en-US/eula/unreal
