# PC games

Original practical lifecycle guidance. This pack contains a small save contract, not an engine, renderer or tested game distribution.

## Intake and stack decisions

Choose an engine from editor/scene needs, graphics backends, target hardware, asset pipeline and licensing constraints. Establish Windows versions, CPU/GPU classes, monitors and input devices. Build a vertical slice before adding speculative frameworks. Reuse canonical [Godot guidance](../../godot/README.md) where applicable and the toolkit's asset/replay helpers only after reading their interfaces.

Record player loop, controls, save slots, pause behavior, local/cloud storage, networking and mod support. Separate simulation, presentation and platform services. A replay needs tick-indexed actions, seed, simulation version and initial state. Floating-point differences can prevent cross-platform bit identity; define the actual determinism boundary rather than promising universal replay parity.

## Implementation and persistence

Use simulation, presentation, platform, assets, tools and replay-fixture boundaries. Keep imports/exports and attribution beside source assets. The [save schema](../templates/pc-games/save.schema.json) and [fixture](../templates/pc-games/save.json) define a deliberately tiny versioned format. Production loaders must bound bytes/depth/counts before allocation, reject unsupported versions and validate ranges. JSON Schema does not provide safe file I/O or transactional migration by itself.

Write saves to a staged file, validate, then replace within the supported filesystem contract. Preserve an old copy during migration. Test interrupted writes, corruption, unknown fields/versions and disk exhaustion. Save failures should preserve play state and explain the recovery option without silently resetting progress.

## Build and verify

Use the engine/project's pinned headless test/export command or configured CMake/Cargo interface. Inspect project presets and tool versions first. Offline preparation includes engine export modules, shader compilers, plugins, dependency caches and licensed assets; generated editor caches are not canonical source.

Test fixed-step rules, replay outputs, save/load and migrations. Exercise focus loss, Alt-Tab, fullscreen changes, controller disconnect, multiple monitors and audio-device changes on actual hardware. Release input capture when focus is lost. Multiplayer adds authority validation, malformed packets, latency/loss and reconnection testing; loopback alone is insufficient.

Measure frame-time distributions, loading stalls, peak memory and repeated-scene growth. Budget texture/mesh/audio resources against target hardware. Provide keybindings, subtitles, motion and volume controls, readable contrast and non-color cues. Verify a clean machine and renderer matrix before publishing. Keep crash reports opt-in and bounded, and validate storefront/cloud integrations separately.

Official persistence context checked 2026-11-21: [Godot saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html). This guide's workflow/schema are original. Record engine version, exact commands, artifact hashes and hardware evidence; static schema inspection is not gameplay proof.
