# Unity editor and licensed packages

Status: **restricted-with-original**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: none; restricted vendor payload excluded.

Original offline substitute: `original/offline_contracts.py`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: No Unity editor/proprietary packages mirrored. Original engine-neutral scene/input/save contract and deterministic fixture tests are supplied; they do not provide Unity APIs, rendering, editor/importer or a compiler. Unity.Mathematics download was excluded because actual license is Unity Companion License, not assumed MIT.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://unity.com/legal
- https://docs.unity3d.com/Manual/upm-ui-offline.html
