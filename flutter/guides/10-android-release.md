# 10 — Android Release

Shipping a Flutter app to Google Play is mostly the standard Android
release story with a Flutter front door: you build an **Android App
Bundle (.aab)**, signed through **Play App Signing**, from a release
build with code shrinking on. This guide covers the parts that are
specific enough to get wrong.

Snapshot: **Flutter 3.50.0 / Dart 3.14.0**, Play target-API era
**API 36** (see the deadlines reference in the Kotlin/Android material
and re-check Play Console help — the target requirement rises most
years).

## The version lives in pubspec.yaml

```yaml
version: 1.0.0+1
```

- `1.0.0` is the **versionName** users see.
- `+1` is the **versionCode** — the integer Play uses to order
  releases. Every upload to Play needs a **higher** versionCode than
  the last one, or Play rejects it.
- Flutter feeds both into the Android build automatically. Do not also
  hard-code them in Gradle; one source of truth.

Bump the version **before** the release build, every time.

## Signing: upload key + Play App Signing

Play App Signing is the model, and it is not optional for new apps:

- **Google holds the final app signing key** (the one devices trust).
- **You hold an upload key** — it only proves the upload came from
  you. If you lose it, Google can reset it after identity checks; if
  you lose the *app* signing key in the old pre-Play-Signing world
  there was no recovery, which is exactly why this model exists.

Create the upload keystore once (JDK `keytool`):

```powershell
keytool -genkeypair -v -keystore upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Wire it up **outside version control**:

1. `android/key.properties` (git-ignored) points at the keystore and
   alias, with passwords read from there or the environment:

   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=C:/path/to/upload-keystore.jks
   ```

2. `android/app/build.gradle.kts` loads `key.properties` if present
   and uses it for the `release` signing config; if the file is
   absent, release signing is left unset (so CI and other machines
   fail loudly instead of silently shipping a debug-signed bundle).
3. **Never commit** the keystore or real passwords. Back the keystore
   up somewhere safe and separate — losing it means an upload-key
   reset process, not instant death, but it is still a bad week.

Flutter's own docs walk this file-by-file ("Build and release an
Android app" on docs.flutter.dev) — follow them for the exact Gradle
snippets for your Flutter version, and keep the structure above.

## Build the bundle

```powershell
flutter build appbundle --release
```

Output:

```
build/app/outputs/bundle/release/app.aab
```

That `.aab` is what you upload to Play Console. (An APK —
`flutter build apk --release` — is for direct distribution and
testing, not for Play uploads.)

## Code shrinking (R8) is on by default

Release builds run **R8** code shrinking and resource shrinking by
default in current Flutter/Android tooling. Practical consequences:

- Smaller bundle, dead code removed — good.
- Reflection-heavy plugins occasionally need **keep rules** in
  `android/app/proguard-rules.pro`. A release-only crash that debug
  never shows is the classic symptom: test the **release** build on a
  real device before uploading, not just debug.
- Keep the mapping files from each release build (Play accepts them
  for deobfuscated crash reports; they live under
  `build/app/outputs/mapping/release/`).

## Target API and Play requirements

- The Flutter/Android toolchain sets `targetSdk` from the Flutter
  version's defaults; current-era Flutter targets **API 36**, which
  matches Play's requirement for new apps and updates in this era.
- After upgrading Flutter, confirm the effective target in the built
  bundle rather than assuming — Play rejects uploads below the
  required target, and the requirement steps up on a published
  schedule (extensions exist but are a delay, not a strategy).
- Play also requires the App Bundle format and Play App Signing —
  both already covered above — plus the usual Console declarations
  (data safety, content rating, target audience). Those live in Play
  Console, not in the codebase; do them deliberately, they are part
  of the release.

## Flavors on Android

Android flavors are **Gradle product flavors** on the Android side,
selected from Flutter with `--flavor`:

```powershell
flutter build appbundle --release --flavor prod -t lib/main_prod.dart
```

Each flavor can carry its own `applicationId` suffix, name, and icon,
so `dev` / `staging` / `prod` installs can sit side by side on one
phone. The full cross-platform flavor story — including `--dart-define`
config and the Windows flavor support added in Flutter 3.47 — is
[guide 12](12-flavors-and-config.md). Rule of thumb: flavors are an
Android/desktop concept implemented per platform; there is no single
switch that creates them everywhere.

## Play release tracks

Upload in steps, not straight to everyone:

1. **Internal testing** — your own small list, minutes to go live.
   First stop for every build.
2. **Closed testing** — a wider trusted group; also where new
   personal developer accounts satisfy Play's pre-production testing
   requirement.
3. **Open testing** — public opt-in beta.
4. **Production, staged rollout** — release to a percentage (e.g.
   20%), watch crashes/ratings, then halt or complete the rollout.

A build that survives internal testing with the release signing,
release shrinking, and a cold install is the build you promote — you
promote the **same bundle** up the tracks rather than rebuilding, so
what you tested is what ships.

## Pre-upload checklist

- [ ] `version:` bumped in pubspec.yaml (versionCode increased)
- [ ] `flutter analyze` clean; tests pass (guide 08)
- [ ] Release build installed and exercised on a real device
- [ ] Upload key signing in place; `key.properties` not committed
- [ ] `flutter build appbundle --release` output is the file uploaded
- [ ] Effective target API meets Play's current requirement
- [ ] Mapping files from this build saved
- [ ] Upload goes to internal testing first, then promotes
