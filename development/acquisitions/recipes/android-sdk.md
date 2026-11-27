# Android SDK, platform/build tools and NDK

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `android-ndk-samples`, `temurin21-win-x64`, `temurin21-source`, `temurin21-build-source`.

Original offline substitute: `original/offline_contracts.py`. Original MIT code; no vendor API compatibility or production service behavior claimed.

Remaining requirements and limits: Apache-licensed NDK samples and a portable Temurin 21 Windows x64 JDK, exact OpenJDK source and Temurin build scripts are retained. The Google Android SDK/NDK bundle remains unmirrored under restrictive SDK terms. Target platforms, build tools, NDK and each project Gradle dependency graph are still required. The original validator does not install software, accept licenses or replace vendor APIs.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://developer.android.com/tools/sdkmanager
- https://developer.android.com/ndk/downloads
- https://developer.android.com/studio/terms
