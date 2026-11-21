# Steamworks, consoles and store/service SDKs

Status: **restricted-with-original**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: none; restricted vendor payload excluded.

Original offline substitute: `original/offline_contracts.py`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: No partner-only Steamworks/console/store credentials or SDKs mirrored. Original injected in-memory achievements/save/fake-purchase adapter supports deterministic testing without network, billing or vendor API compatibility. Real integration still needs authorized SDK/environment.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://partner.steamgames.com/doc/sdk
- https://developer.android.com/google/play/integrity
