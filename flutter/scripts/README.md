# Flutter pack — scripts

PowerShell 7 scripts (the pack's primary shell, matching the DevTools
house rules) with a bash twin of each for Git Bash / WSL / macOS /
Linux. Every script is check-and-report by default: **nothing here
installs anything, downloads anything (except
`Update-FlutterPack -Fetch`, only when you pass the switch), or stores
credentials.**

| Script | What it does |
|---|---|
| [Test-FlutterToolchain.ps1](Test-FlutterToolchain.ps1) / [.sh](Test-FlutterToolchain.sh) | Read-only readiness check: flutter/dart on PATH + versions, git, Visual Studio C++ workload (via vswhere), Android SDK pieces (ANDROID_HOME, cmdline-tools, platform-tools, platforms), Chrome for web. Prints a PASS/MISSING table with the exact fix step per miss, then summarizes `flutter doctor -v`. Exit 1 if anything is missing. |
| [New-FlutterProject.ps1](New-FlutterProject.ps1) / [.sh](New-FlutterProject.sh) | Wraps `flutter create` with pack defaults: `-Name` (required, lowercase_with_underscores), `-Org` (default `com.example`), `-Platforms` (default `windows,android`), `-Empty` switch. Refuses if flutter is missing or the folder exists. Applies `templates/analysis_options.yaml` and `templates/gitignore-flutter` when present, then prints next steps. |
| [Invoke-FlutterBuild.ps1](Invoke-FlutterBuild.ps1) / [.sh](Invoke-FlutterBuild.sh) | Builds one target — `windows-release`, `android-aab`, `android-apk-debug`, `web` — then reports the artifact path, size, and SHA256 (Windows: Release folder + app exe hash; AAB/APK: the file hash; web: folder + `main.dart.js` hash). Fails clearly on a nonzero build exit or a missing artifact. |
| [Update-FlutterPack.ps1](Update-FlutterPack.ps1) / [.sh](Update-FlutterPack.sh) | Pack maintenance. Default (no network): prints the Flutter releases manifest URL and the pub.dev API endpoint for every package in `reference/dependencies.md` so the version snapshot can be re-verified by hand. With `-Fetch` / `--fetch` only: downloads the releases manifest and compares the current stable Flutter against `reference/versions.md`. Writes nothing either way. |

## Usage

```powershell
pwsh -File scripts/Test-FlutterToolchain.ps1
pwsh -File scripts/New-FlutterProject.ps1 -Name my_app -Org com.acme
pwsh -File scripts/Invoke-FlutterBuild.ps1 -Target android-aab -ProjectPath .\my_app
pwsh -File scripts/Update-FlutterPack.ps1            # offline
pwsh -File scripts/Update-FlutterPack.ps1 -Fetch     # the only network mode in this folder
```

```bash
bash scripts/Test-FlutterToolchain.sh
bash scripts/New-FlutterProject.sh my_app --org com.acme
bash scripts/Invoke-FlutterBuild.sh --target android-aab --project ./my_app
bash scripts/Update-FlutterPack.sh --fetch
```
