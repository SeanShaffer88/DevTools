# .NET SDK and NuGet local feed

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `dotnet-source`.

Original offline substitute: `original/offline_contracts.py`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: Windows .NET SDK binary is not mirrored: its .NET Library License restricts standalone redistribution. SDK source snapshot does not include build dependencies, runtime binaries or project-specific NuGet graph. Original readiness contract is not a .NET compiler/runtime.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://learn.microsoft.com/en-us/nuget/hosting-packages/local-feeds
- https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-restore
- https://dotnet.microsoft.com/en-us/dotnet_library_license.htm
- https://github.com/dotnet/core/blob/main/license-information-windows.md
