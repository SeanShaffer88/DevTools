# Android game acceptance

Original template. Replace TODOs before using engine or device operations.

| Boundary | Required project evidence |
| --- | --- |
| Engine | Version, matching export templates, plugin hashes/licenses |
| Target | Minimum hardware, Android versions, ABI and graphics backends |
| Simulation | Fixed-step rules, seed, replay version, expected outcomes |
| Input | Multiple pointers, cancel, controller disconnect, pause/focus loss |
| Lifecycle | Surface recreation, app switch, audio focus, save interruption |
| Assets | Attribution, texture/audio/load budgets, export settings |
| Accessibility | Readable text, non-color cues, motion/audio/haptic controls |
| Performance | Frame percentiles, memory growth, thermal/load measurements |
| Distribution | Signed release inspection, offline launch, save migration, rollback |

Declare exact test/export commands and selected authorized device serial. Record Pass/Fail/Unknown/NotRun for each supported combination. Desktop previews and replay unit tests do not prove physical-device behavior. Keep store-policy evidence dated and separate from local build checks.
