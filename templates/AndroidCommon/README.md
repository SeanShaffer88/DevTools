# __NAME__

Native Java Android source starter. No Gradle, AndroidX, downloaded libraries, signing keys, or runtime wrappers. Includes a local SVG mockup under `mockups/`.

Requires PowerShell 7, an installed JDK, Android SDK platform `android-36`, and Build Tools `36.0.0`. Other installed numeric versions can be explicitly selected; the manifest targets API 36 with minimum API 23. Tool versions must support that manifest.

Run explicitly from a new PowerShell process:

```powershell
pwsh -NoProfile -File .\Build.ps1 -SdkPath 'C:\Path\To\Android\Sdk'
```

The script compiles Java, runs D8, creates an APK with aapt2, adds DEX, then aligns/checks it. Unique `build/<id>/` folders retain output logs and `result.json` with actual exit codes. The resulting `__NAME__-unsigned.apk` is **unsigned**. No installation, signing, release or device/runtime validation is performed. Generation itself executes none of these tools. Generated source uses only Android platform APIs; test layout/input on intended devices before shipping.
