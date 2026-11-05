# Android Artifact And Performance Evidence

Original operational note, version 1. Get-AndroidDiagnostics.ps1 reads APK ZIP metadata. Test-AndroidArtifact.ps1 invokes installed aapt2, apksigner and zipalign for separate manifest/permission, signature and ZIP alignment findings. Unsigned APKs correctly fail signature verification. ZIP alignment with -P 16 does not establish each ELF load segment's 16 KiB compatibility or store eligibility.

Invoke-AndroidTest.ps1 requires an explicit serial and package. Launch/Startup explicitly start an Activity; Startup records am start -W without forcing a stop, so it does not infer cold-start behavior. Memory uses raw dumpsys meminfo. FrameStats uses raw dumpsys gfxinfo <package> framestats without reset; renderer support and FPS accuracy are not guaranteed. Screenshot uses binary exec-out capture and may contain private display content. Compare captures from comparable device, app, renderer and workload conditions rather than treating a single snapshot as a benchmark.

Official pointers: https://developer.android.com/tools/aapt2 ; https://developer.android.com/tools/apksigner ; https://developer.android.com/tools/zipalign ; https://developer.android.com/tools/dumpsys ; https://developer.android.com/guide/practices/page-sizes . Device execution requires an authorized selected device; fake-ADB tests establish orchestration only.
