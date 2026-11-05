# Local Resource Library

Original versioned documentation and recipes live in docs/v1 and recipes/v1. Search them with Get-DevReference.ps1 -Resources -Query <literal text> -Json. The original six-reference search remains the default without -Resources.

fixtures/v1 contains inert original known-good/broken inputs and fixtures.json expected results. Recreate into a new directory with resources/New-RegressionFixture.ps1 -Destination <new-directory>. Header-only DLLs must never be executed; metadata-only APKs are not installable. Source/provenance/hashes are retained.

cache/catalog.json is a demonstrable offline cache record for an original fixture. Verify with resources/Test-CacheCatalog.ps1 -CatalogPath resources/cache/catalog.json -Json. No downloader or automatic update exists. Metadata does not certify licensing or security.

lua holds original mock tests, not actual client snapshots. Real syntax/mock execution requires a compatible interpreter and explicit trusted harness selection. Import genuine client sources through Manage-WowClientProfile.ps1 and preserve their provenance. All unperformed host/device/game/VM/online checks must remain visible in evidence.
