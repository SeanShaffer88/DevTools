# Flutter SDK, Dart and pub cache

Status: **partial**. This is payload coverage, not an installed/complete offline toolchain.

Acquired payload IDs: `flutter-source`, `flutter-sdk-no-mingit-win-x64`.

Remaining requirements and limits: Pinned Flutter source plus a modified Flutter 3.50.1 Windows SDK/Dart/engine archive are retained. The entire bundled MinGit subtree was removed to avoid GPL/LGPL binary redistribution without complete corresponding sources. All other member bytes remain unchanged and their notices are retained. A separately installed Git, target SDKs and project-specific pub/plugin caches are required. No SDK activation, build or runtime check was performed.

Verify from the repository root: `python development/acquisitions/verify.py verify`. The verifier reads local bytes only and checks archive contents without extraction/execution. `inventory.json` records exact source, version/revision, hashes, retained license paths and publisher-checksum evidence.

Upstream preparation/terms references:
- https://dart.dev/tools/pub/cmd/pub-get
- https://docs.flutter.dev/install
