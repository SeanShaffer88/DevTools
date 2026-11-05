# Builds, Cache And Fixtures

Original operational note, version 1. Compare-DevBuild.ps1 captures explicit inputs/artifacts with SHA256 and supplied configuration/toolchain data. Capture does not execute configuration, rebuild a project, inspect all environment variables or prove independent reproducibility. Matching bytes establish identity; differences identify evidence to investigate.

resources/New-RegressionFixture.ps1 creates original inert PE/APK/addon/config fixtures in a new destination. fixtures/v1/fixtures.json records expected helper exits and hashes. The header-only DLL is for static reader tests and must never be loaded. metadata-only.apk is valid ZIP inspection data, not an installable or signed APK. Good/bad names refer only to the documented checker.

resources/Test-CacheCatalog.ps1 checks an explicit offline catalog's relative files, SHA256 and recorded source/version/license/provenance metadata. A hash match is not trust or a grant to redistribute dependencies. No network downloads occur. Register approved caches deliberately and retain upstream license notices. The bundled cache entry is an original inert test fixture, not third-party runtime binaries.
