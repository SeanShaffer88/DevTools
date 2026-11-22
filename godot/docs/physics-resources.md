# Godot realistic physics resources

Scope: Godot **4.7.2** API and the **4.7** documentation branch, captured 2026-11-22. Recheck the target project's exact version before adapting. This is an offline research collection, not installed addons or a tested simulation.

## Start with the supported engine

- **SoftBody3D:** subdivide the mesh sufficiently, configure pinned points and collisions, and budget solver cost. The [official tutorial](../physics/vendor/godot-physics-manual/tutorials/physics/soft_body.rst) explicitly says soft body support is generally more robust with Jolt. New projects created in 4.6+ default to Jolt; existing projects may need the project setting changed. Physics interpolation currently does **not** affect soft bodies. More physics ticks can improve their smoothness at CPU cost.
- **Ragdolls:** use a Skeleton3D to generate physical bones, tune their shapes/joints, and use **PhysicalBoneSimulator3D.physical_bones_start_simulation()** in this version. See the [ragdoll tutorial](../physics/vendor/godot-physics-manual/tutorials/physics/ragdoll_system.rst) and [current API](../physics/vendor/godot-physics-api/doc/classes/PhysicalBoneSimulator3D.xml). Older tutorials may place control methods elsewhere.
- **Jolt:** read [backend differences and unsupported features](../physics/vendor/godot-physics-manual/tutorials/physics/using_jolt_physics.rst) before switching. Backend selection is not proof that a particular suspension, joint setup or project will be stable.
- **Interpolation:** [advanced interpolation](../physics/vendor/godot-physics-manual/tutorials/physics/interpolation/advanced_physics_interpolation.rst) explains camera/manual exceptions and local transform interpolation in both 2D and 3D. Update physics-driven transforms on physics ticks and reset interpolation after discontinuities where appropriate. Rendering smoothness does not increase physical accuracy.
- **Vehicles:** [VehicleBody3D](../physics/vendor/godot-physics-api/doc/classes/VehicleBody3D.xml) is a raycast vehicle with known issues and is **not designed for realistic 3D vehicle physics**. Prototype its behavior before choosing it; the official reference suggests custom CharacterBody3D/RigidBody3D integration for advanced needs. Jolt does not remove this limitation.

## Correctness rules to apply deliberately

1. **Callbacks:** [RigidBody3D._integrate_forces(state)](../physics/vendor/godot-physics-api/doc/classes/RigidBody3D.xml) is specifically intended for safe direct physics-state access. Do not prohibit it or defer every update. Scene-tree changes or collision changes while queries are flushing can require call_deferred/set_deferred; decide from the operation and exact error/API contract. Avoid repeatedly overriding a rigid body's transform/velocity from render callbacks.
2. **Layers and masks:** design and test both sides of collision filtering. Explicit values in scene files or code make intent reviewable; inspector defaults are not inherently invalid. Verify trigger monitoring, shapes, scale, and backend before blaming a missing collision on masks alone. See [CollisionObject3D](../physics/vendor/godot-physics-api/doc/classes/CollisionObject3D.xml).
3. **Time steps:** for an original manual continuous decay model, `speed *= exp(-rate * delta)` preserves the chosen exponential rate across time steps. Use consistent units and physics delta. Do not add it on top of built-in damping without accounting for both; engine damping has its own documented integration semantics. Apply impulses for impacts and forces for sustained acceleration.
4. **Performance:** increase tick rate or solver work only against a measured failure and CPU budget. Test piles, fast bodies, joint chains, soft meshes and worst-case contacts. Interpolation can smooth supported transforms without increasing tick rate; it cannot fix tunneling, invalid shapes or unstable constraints.
5. **Validation:** compare trajectories at multiple tick rates, verify units, rest stability, energy growth, collision filtering, high-speed contact and pause/resume. Benchmark on each target platform/backend. No tests here establish physical accuracy, determinism, performance or Android compatibility of community addons.

## All requested resources and their disposition

| Requested resource | Saved material / primary pointer | Limits |
| --- | --- | --- |
| Using SoftBody3D | [Offline official tutorial](../physics/vendor/godot-physics-manual/tutorials/physics/soft_body.rst) | Text only; images/includes not mirrored. |
| Ragdoll System | [Offline official tutorial](../physics/vendor/godot-physics-manual/tutorials/physics/ragdoll_system.rst) | Current simulator API above; no runtime scene test. |
| Using Jolt Physics | [Offline official tutorial](../physics/vendor/godot-physics-manual/tutorials/physics/using_jolt_physics.rst) | Verify version and backend differences. |
| Advanced Physics Interpolation | [Offline official tutorial](../physics/vendor/godot-physics-manual/tutorials/physics/interpolation/advanced_physics_interpolation.rst) | Not soft-body interpolation. |
| VehicleBody3D | [Offline official class XML](../physics/vendor/godot-physics-api/doc/classes/VehicleBody3D.xml) | Known realism limitations. |
| Getting Started with 2D Physics in Godot (Kodeco) | [Ken Lee tutorial](https://www.kodeco.com/44858551-getting-started-with-2d-physics-in-godot) | Reference only: article redistribution permission not established; no article copy. For offline fundamentals use [official physics introduction](../physics/vendor/godot-physics-manual/tutorials/physics/physics_introduction.rst). |
| Physics Gotchas (GitHub) | Exact requested repository unresolved. [Candidate documentation repository](https://github.com/Ericdataplus/godot-4-ultimate-documentation) | Candidate only, not identified as the user's source; no verified redistribution license, no copied files. Use the grounded correctness rules above. |
| Godot Rapier Physics | [Offline author README](../physics/vendor/godot-rapier/README.md), [architecture](../physics/vendor/godot-rapier/ARCHITECTURE.md), [repository](https://github.com/appsinacup/godot-rapier-physics) | Author advertises 2D/3D fluids, determinism and stability/performance improvements. These are unverified claims here, not universal guarantees. Select matching dimension, engine, architecture and native/export libraries; complete dependencies are not saved. |
| Verlet Rope 4 (.NET) | [Offline README](../physics/vendor/verlet-rope/README.md), [simulated](../physics/vendor/verlet-rope/addons/verlet_rope_4/Physics/VerletRopeSimulated.cs) and [rigid](../physics/vendor/verlet-rope/addons/verlet_rope_4/Physics/VerletRopeRigid.cs) references | Author requires Godot 4.4.1+ .NET and .NET 8 SDK. Simulated and rigid-body modes differ. Standard non-.NET Godot is insufficient. Not built or installed. |
| Ocean3D Lite | [Offline README](../physics/vendor/ocean3d-lite/README.md), [buoyancy source](../physics/vendor/ocean3d-lite/addons/ocean3d_lite/floating_body.gd), [repository](https://github.com/Ocean3D-Org/ocean3d-lite) | Author documents Gerstner visual/physics sync and multi-probe buoyancy. Needs plugin/autoload setup; only Lite material saved, no paid edition/assets. Not activated or tested. |
| openfairway | [Offline addon README](../physics/vendor/openfairway/addons/openfairway/README.md), [aerodynamics](../physics/vendor/openfairway/addons/openfairway/physics/Aerodynamics.cs), [bounce](../physics/vendor/openfairway/addons/openfairway/physics/BounceCalculator.cs) | Author requires Godot 4.5+ .NET and .NET 9 SDK+. GDScript interop still needs built C# runtime. Golf accuracy and target compatibility unverified; unrelated course/game assets excluded. |

## Provenance and verification

[Source inventory](../../development/vendor/SOURCES.json) records immutable commit URLs, capture date, SHA-256, size and attribution for each exact file. [Offline library catalog](../../development/catalog.vendor.json) makes the text searchable without network access. External images, linked pages, binaries and transitive dependencies are not mirrored. Source excerpts can reference absent modules and are not standalone build inputs. Nothing was installed, imported into Godot or executed.

The official manual is **CC-BY-3.0**, attributed to **Juan Linietsky, Ariel Manzur and the Godot community**; retain its [license](../physics/vendor/godot-physics-manual/LICENSE.txt) and attribution. Godot engine class XML uses the engine [MIT license](../physics/vendor/godot-physics-api/LICENSE.txt). Community subsets retain their own MIT licenses and Rapier third-party notice. These terms apply separately from this original guide, which uses [DevTools MIT](../../development/LICENSE). References and author claims do not certify third-party quality or permission for unrelated assets.

Verification commands (offline, Python standard library):

```text
python development/tools/library.py audit --root .
python development/tools/library.py search "physics" --domain pc-games --limit 10 --root .
python -m unittest discover -s development/tests -v
python -m unittest discover -s development/acquisitions/tests -v
```
