# Native reliability support

`ReliabilityNativeCommon.ps1` adds local path refusal and the schema1
Pass/Fail/Unknown/SetupError exit mapping to existing `QualityCommon.ps1`.
Importing it only defines functions. PS7 and built-in .NET; no added dependencies.
Original DevTools implementation; no third-party code copied. Existing repository
license terms apply; no independent redistribution grant is asserted here.

## Policy diagnostics

```powershell
pwsh -NoProfile -File ./Get-PolicyDiagnostics.ps1 -EvidencePath ./evidence.json -TargetPath ./README.md -Json
```

Evidence schema1 requires operation string (1–256 characters), signed 32-bit
exitCode, stderr/stdout strings (0–65536 characters each), context host/sandbox
strings (0–256 characters each). Optional context.windowsSandboxConfigured is
boolean. UTF8 JSON is capped at 256 KiB and depth 8. Paths are capped at 4096
characters; UNC, ADS, traversal, wildcards and existing reparse ancestors refused.

No writes, target launches, setting changes, global Codex config reads, effective
access checks or broad compliance claims. Own execution policies/language mode
are observed live; selected target existence, attributes, zone-stream presence and
aggregate ACL metadata contain no ACL identities or raw paths. Evidence is hashed;
raw text is never included in results. Filesystem checks are not atomic against a
concurrent path replacement; use stable locally controlled evidence/targets.

Explicit supplied script restrictions, sandbox configuration denials and sharing
violations are diagnoses (Pass/0). Missing selected executable is Fail/2.
Generic denial, generic policy text and absent sandbox backend remain Unknown/3.
Invalid setup is SetupError/125. Supplied errors are unauthenticated and no
diagnosis claims that the failed operation now succeeds.

Reference reviewed as documentation only: WhyNot pinned commit
56d3617ce4e96cef61dac35280d63e5a76f78a90, resources/github/snapshots/WhyNot/.
Its broad attribution and repair suggestions are not adopted; this helper uses
fixed narrow suggestions and never advises disabling protection or elevation.

Focused verification: `pwsh -NoProfile -File tests/Test-ReliabilityNativePolicy.ps1`.
Tests write only their selected evidence destination; helper itself writes nothing.
Main group suite integration, packed consumption and independent audit belong to
the parent group workflow and are not established by this slice.
