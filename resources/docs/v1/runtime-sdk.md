# Runtime And SDK Evidence

Original operational note, version 1. Runtime presence and build-tool completeness are different checks. A VC redistributable is not a compiler; a compiler file is not an SDK.

Use Test-RuntimeRequirements.ps1 with an explicit schema-1 requirements manifest. Architecture, exact .NET framework name, minimum-inclusive and maximum-exclusive numeric versions matter. Supplied inventories are supplied evidence, never fresh host proof. Missing evidence under partial coverage is Unknown, not Missing. Use Test-SdkCompleteness.ps1 for a selected Windows native, .NET, Java or Android target. Its file checks are structural, not a compile/link test.

MSVC compiler headers and UCRT headers live in separate roots. Windows SDK 10.0.26100.0 on this host contains stddef.h under Include/<version>/ucrt. Set INCLUDE/LIB through a verified developer environment for an actual native build. Do not infer missing CRT files from one misconfigured link command.

Official pointers: https://learn.microsoft.com/en-us/dotnet/core/install/how-to-detect-installed-versions ; https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files ; https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution . Runtime distribution permission is not inferred from installation or hashes.
