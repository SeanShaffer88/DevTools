# Gradle wrapper, plugin and Maven dependency cache

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `gradle-bin`, `temurin21-win-x64`, `temurin21-source`, `temurin21-build-source`.

Remaining requirements and limits: The Gradle binary distribution and portable Temurin 21 Windows JDK with exact source/build scripts are retained. Select project-compatible JDK, Gradle and Android Gradle plugin versions. Project Maven dependencies, wrapper pinning, variants and caches remain required. No vendor build or runtime test was performed.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://docs.gradle.org/current/userguide/dependency_caching.html
