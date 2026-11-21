# Android application acceptance

Original reusable project template; no device actions are authorized by filling it in.

1. Record package ID, version, min/target SDK, JDK/Gradle/plugin versions and flavor.
2. List actual unit/build/instrumentation tasks and installed SDK components.
3. Define user journeys and loading/content/empty/error/cancelled UI states.
4. List permissions, exported components, deep links, retention/backup/deletion rules.
5. Provide old database fixtures and interrupted/failed migration recovery.
6. Test rotation, process recreation/death, denied permission, offline/slow network and low disk.
7. Record TalkBack, large-font, contrast, focus and touch-target observations.
8. Set startup/frame-time/memory/background budgets and measure release behavior.
9. Declare the exact authorized device serial; separate mock/emulator/device results.
10. Inspect final manifest, ABI, alignment, certificate, privacy behavior and rollback.

For each item store expected result, fixture, command, exit code, observed result and evidence path. Keep credentials/signing keys out. Offline readiness requires the wrapper, matching SDK/JDK and complete dependency cache, followed by a disconnected build. Store policy checks are dated release-time evidence, not permanent certification.
