# Android apps

Original practical lifecycle guide. Installed SDK, device and release checks remain project-specific; no Android device was exercised by authoring this pack.

## Intake and stack

Choose Kotlin/Compose for Android-first integration or Flutter when shared UI is an actual requirement. Select minimum/target SDK, Java, Gradle and Android-plugin versions as one compatibility set from the project. Define tablets/foldables, external input, background work, offline operation and accessibility expectations. Consult canonical [Kotlin](../../kotlin/README.md) and [Flutter](../../flutter/README.md) packs for implementation details.

Classify stored/transmitted data, permissions, backup, account removal and retention. Separate presentation state, domain rules and repositories; inject clock, network and storage. Model loading/content/empty/error/cancelled states. Keep secrets out of the APK. Intents, deep links and exported components are explicit input boundaries.

## Implement and recover

Use `app/ui`, `domain`, `data`, `platform` and `tests/fixtures` where appropriate. Version database migrations and preserve old snapshots. A migration error must not erase user data silently. Cache expiration, sync conflicts, network retries and cancellation need finite budgets and observable outcomes. Test permission denial and revocation without assuming a successful permission prompt.

## Build and test

Inspect the Gradle wrapper source and verification/lock metadata first. Typical existing tasks are `.\gradlew.bat testDebugUnitTest` and `assembleDebug`; flavors can change those names. Read the actual task interface before invoking it. Connected tests require an explicitly selected authorized device. Prepare wrapper distribution, Maven/Gradle cache, SDK platform/build-tools and matching JDK before using offline mode; `--offline` does not acquire anything.

Test rotation/recreation, process death, clock changes, low storage, malformed data, interrupted migrations and poor/no connectivity. Separate unit, emulator and physical-device evidence. Use TalkBack, enlarged fonts, focus order, contrast and touch-target tests on supported configurations. Measure startup, frame timing, ANRs, memory and background battery behavior using representative data.

## Release and handoff

Inspect the final manifest, ABI set, alignment and signing certificate with the toolkit's Android helpers. Keep keys and credentials out of this library and logs. Verify release behavior separately from debug. Store policy and target-SDK deadlines must be rechecked at release time, with date/version recorded. Review privacy, deletion and backup behavior before distribution. Prepare database rollback and a staged rollout plan rather than assuming downgrade is safe.

Use [the acceptance contract](../templates/android-apps/acceptance.md). Record exact build tasks and selected serials, artifact hashes, checks performed and incomplete gates. A successful APK build does not prove lifecycle, accessibility or store acceptance.
