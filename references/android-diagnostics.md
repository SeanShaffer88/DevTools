# Android Diagnostics And Builds

Original local operational note. Get-AndroidDiagnostics.ps1 supports offline APK
inspection and explicit device diagnostics. Offline mode does not start ADB or
extract the archive. ZIP entry names reveal DEX files, assets and native ABI
directories. A binary AndroidManifest.xml needs Android tooling for semantic
decoding; archive presence alone does not establish correct application identity,
signature trust, installability or runtime behavior.

Device mode requires an explicit serial. Finite logcat capture can expose sensitive
application output. Explicit ADB diagnostics may start the local ADB server; no
install, uninstall, activity launch or log clearing belongs to this helper.

Generated Android templates use installed Java and Android SDK tools. An unsigned
APK is a build artifact, not an installed or device-tested application. Compile
and package tests do not establish runtime behavior, lifecycle correctness or
store submission readiness. Read the generated README and Build.ps1 interfaces.

Official pointers verified 2026-11-03; online documents are not mirrored:
https://developer.android.com/tools/adb
https://developer.android.com/tools/logcat
https://developer.android.com/tools/apkanalyzer
