# Development library maintenance

Keep canonical guides, examples, source provenance and verification evidence distinct.
Use `tools/library.py` offline audit/search/plan before adding duplicate material.
Never execute referenced code or acquire dependencies merely because a catalog entry
exists. Missing optional resources must remain explicitly not-acquired.

Catalog paths are repository-relative. Preserve entry IDs and all eight domain IDs.
Pin vendored file size/hash, origin, license and upstream provenance; never imply
runtime verification from static inspection. Review changes before explicit manifest
refresh, then run audit and standard-library tests. Keep source files bounded and
free of credentials/private data. No background services or network on import.
