# Package Manifest And Static Checks

Original local operational note. Test-Package.ps1 -PackagePath inventories relative
file paths, byte counts and SHA256. Optional -ManifestPath accepts exactly:

    {"schemaVersion":1,"files":[{"path":"data/config.json","required":true,"sha256":"64 hexadecimal characters"}]}

Omit sha256 to check presence only. required defaults to true; it must be a JSON
Boolean when supplied. Optional missing files are informational. Required missing
files, hash mismatches and malformed manifests fail. Paths must be relative,
unambiguous and contained in the package; dot traversal, rooted paths, alternate
data streams, wildcards, duplicate normalized paths and reparse points are rejected.

Unexpected files are warnings unless -Strict is supplied. Strict requires a
manifest. A manifest located inside the package remains in the inventory but is
excluded from unexpected-file findings. SHA256 identifies bytes; it does not
establish trust, provenance or artifact freshness.

-ExpectedArchitecture x86|x64|Arm64 checks EXE/DLL PE machine fields. A managed PE
header is not a complete runtime architecture policy. FileVersion is reported
when present, not compared to an inferred product version. Normal and delay-load
dependency resolution is not certified.

Installer upgrade behavior, application process closure, desktop/startup options,
user settings preservation and runtime behavior require a separate authorized
disposable installation test. All are outside static package certification.
