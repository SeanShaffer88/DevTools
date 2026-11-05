# DLL Inspection

Original local operational note. Use Get-DllInfo.ps1 -Path with a literal PE path;
optional -CompareTo supplies the baseline. The inspector reads bytes, not executable
code. It never loads the inspected module.

PE machine identifies x86, x64, Arm64 or other header values. A CLR directory is
an indicator of managed metadata, not a complete managed API inventory or a promise
that a PE32 image requires an x86 process. Named and ordinal exports, forwarded
exports, imported libraries and normal import symbols are reported. Exported globals
can reside in zero-filled virtual sections with no corresponding file data.

Comparison uses ordinal:name identities. Added/removed exports and architecture
changes are clues for review, not proof of ABI compatibility. Calling conventions,
structure layout, parameter types, CLR APIs, delayed imports, loader search paths,
runtime dependency availability and signature trust remain unchecked. Export
forwarder changes require inspecting the full image reports.

Reference pointer verified 2026-11-03:
https://learn.microsoft.com/en-us/windows/win32/debug/pe-format

The online specification is not copied or mirrored here. Current implementation
bounds sections, strings and symbol counts and rejects unsupported/malformed files.
