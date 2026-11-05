# Dependencies And Native Contracts

Original operational note, version 1. Use Get-DllInfo.ps1 for PE headers/imports/exports and Resolve-NativeDependencies.ps1 for a bounded static candidate graph. Windows DLL module names are case-insensitive, but export names are case-sensitive. Ordinals and forwarders are part of the public export surface. A static import graph cannot prove the actual process loader's behavior: API-set mapping, SxS activation, dynamic LoadLibrary calls, delay imports and loaded modules can alter resolution. Unknown supported contexts must remain visible.

Use Get-DependencyAudit.ps1 for supported lock-file inventory. Licenses and advisories without evidence remain unknown. Offline inventories are not fresh vulnerability scans. Use Test-DllContract.ps1 only for explicitly trusted owned libraries with declared primitive signatures, in the isolated child. Loading a DLL executes initialization code; a child process is not a sandbox. Export identity alone does not certify calling conventions, layout, allocator boundaries or ABI compatibility.

Official pointer: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order . Use the selected compiler/architecture documentation for ABI details. No copied upstream documentation is bundled here.
