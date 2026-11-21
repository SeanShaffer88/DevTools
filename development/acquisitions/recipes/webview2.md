# WebView2 Runtime and SDK

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `webview2-sdk`.

Remaining requirements and limits: Official SDK NuGet headers/loaders retained under bundled license. WebView2 browser runtime, architecture-specific deployment and runtime validation remain separate.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution
