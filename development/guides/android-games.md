# Android games

Original offline delivery playbook. This is a project workflow, not an engine/export-template bundle or device certification.

## Choose a bounded vertical slice

Choose Godot for scene-based development, a game framework for specialized simulation, or Compose Canvas for modest UI-centric gameplay. Prototype one playable loop on a target device before adding engine layers. Define orientation, graphics backend, ABI set, touch gestures, controllers, audio focus and pause/resume. Consult canonical [Godot](../../godot/README.md) and [Kotlin](../../kotlin/README.md) material; engine/export-template versions must agree.

Intake includes frame budget, minimum device class, thermal behavior, monetization, offline launch, save retention and asset rights. Separate fixed-step simulation from rendering and input sampling. Translate touch/controller events into domain actions. Seed randomness and identify replay/simulation versions; desktop determinism does not automatically extend across different devices.

## Build architecture and assets

Use simulation, scenes, Android platform adapters, source assets, exported assets and replay fixtures as boundaries. Keep source attribution and export settings beside asset families. Bound texture sizes, audio memory, load concurrency and initial download size. Keep save writes crash-safe and migrations transactional. Avoid recurring disk or network work in the render loop.

Use the project's pinned export preset or verified Gradle wrapper tasks. Command names and flags depend on the actual engine version; inspect local help instead of inventing a generic export command. Offline preparation includes engine binary, matching templates, SDK/JDK, plugins and licensed assets. An editor that opens a scene is not evidence of an offline Android release export.

## Verify failure and accessibility

Test simulation rules and replay outcomes independently. Then test multiple pointers, touch cancellation, app switching, surface recreation, rotation where supported, headset changes and interruptions on the actual authorized device. Measure frame-time percentiles, memory after repeated scenes, thermal throttling and loading stalls on representative low-end hardware. A desktop preview does not establish mobile GPU support.

Provide scalable text, readable contrast, non-color-only cues, motion controls and alternatives to precision gestures. Keep audio/haptic controls independent. Test save interruption and previous-version migration without overwriting the only user copy. Keep mock, emulator and physical evidence separate.

## Release

Require signed artifact inspection, ABI/backend matrix, offline launch, suspend/resume, versioned saves, attribution and rollback. Review network behavior, consent and lifecycle cost before adding monetization SDKs. Store requirements change and must be checked for the actual release. Use [the game acceptance contract](../templates/android-games/acceptance.md), recording serial, engine/template versions, measured budgets and every unrun gate.
