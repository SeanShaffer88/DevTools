# Developer dependencies and offline readiness

Original operational guide. Documentation, source, installed binaries and cached build dependencies are separate availability states. A lockfile is not a populated offline cache.

## Inventory first

Read declared project requirements before acquiring anything. Record host/target architecture, versions, origin, license, integrity evidence and actual verification commands. Separate compiler/build tools, runtime libraries, test tools and optional integrations. Use existing toolkit environment/runtime/SDK/dependency helpers after reading their help. Reuse [toolchain references](../../ai-resources/categories/toolchains.md) and the [local repository catalog](../../resources/github/catalog.md); untested references remain untested.

Prefer already installed compatible tools. Do not change global PATH or upgrade SDKs speculatively. Missing components need an explicit acquisition plan, disk budget and destination. Private registries, license keys and credentials must not enter the library, manifests or logs.

## Acquire and preserve provenance

Start from [acquisition.json](../templates/dependencies/acquisition.json), which is data, not an installer. Populate exact version, canonical origin, expected digest where available, license evidence, architecture, staging destination, cache location and verification command. Mark not-acquired until actual bytes/provenance are recorded. Keep archive and notices where redistribution permits; stage new versions separately and preserve rollback.

Consult [the dependency recipes](../dependency-recipes.json) for acquisition/preparation routes. Recipes identify missing capabilities; they neither install software nor establish redistribution rights.

Do not bulk mirror vendor SDKs, manuals or paid assets without checking the exact license. A license string or hash does not establish redistribution permission. Link-only records are useful but cannot be called offline documentation. Original operating summaries can fill workflow gaps without reproducing proprietary manuals.

## Prove offline operation

Use each package manager's project-specific supported cache mechanism and exact lock metadata. npm scripts, Cargo build scripts, Gradle plugins and native build hooks execute code: review the selected sources before running them. Do not assume an archive or reference repository is safe to execute.

A warm online build can populate caches but does not establish completeness. Run the documented build with networking unavailable in an isolated environment, preserving logs and listing missing artifacts. Offline flags differ by manager/version; obtain them from installed help and project documentation. Never silently substitute a newer package when the pinned one is missing.

## Validate failure and release evidence

Test missing cache, digest mismatch, wrong architecture, unsupported runtime, low disk and interrupted acquisition. Use bounded staging and atomic activation where supported. Importing a tool should not start background services. Keep optional integrations explicit; absence must produce actionable Unknown/Unsupported evidence when appropriate.

Record source commit, tool versions, dependency identities, build arguments, artifact hashes and checks performed. Separate identity from trust and license permission. Review stale entries deliberately; do not auto-update the global library. This pack ships neither vendor SDKs nor a complete package mirror, and cannot guarantee arbitrary future projects will build offline.
