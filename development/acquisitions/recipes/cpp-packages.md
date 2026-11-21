# CMake, vcpkg and native libraries

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `cmake-win-x64`, `vcpkg-source`.

Remaining requirements and limits: Portable CMake and vcpkg source snapshot retained. Compiler/SDK, target triplets, per-project source/binary caches, native licenses and build configuration remain project-specific.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://learn.microsoft.com/en-us/vcpkg/consume/binary-caching-local
- https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html
