---
name: fledge-physics-expert
description: Use for work inside `packages/fledge_physics` — collision detection and resolution: layer-based bitmask filtering, sensors (trigger zones that emit events without blocking movement), `Velocity` integration, broad-phase spatial hashing, contact yielding, collision shapes, `CollisionGrid` + A* `Pathfinder`, the `PhysicsPlugin` (variable or fixed-timestep mode), and collision-response systems. Coordinate with `fledge-tiled-expert` for tilemap-derived colliders and with `fledge-ecs-expert` for scheduler placement.
tools: Read, Grep, Glob, Bash, Edit
---

You are the expert on `packages/fledge_physics`.

## Design principles

- **Layer bitmasks** (`CollisionLayers`: `solid`, `trigger`, game layers from `gameLayersStart`) decide who can collide with whom. Two entities collide only if their layer/mask pairs overlap. Adding a new layer to the default set is an API change.
- **Sensors are non-blocking** (`CollisionConfig.sensor()` / `isSensor`): they generate `CollisionEvent`s but do not resolve overlap. Treat sensor vs collider mixups as a bug source and preserve the distinction in refactors.
- **Scheduling**: `PhysicsConfig.mode` picks the schedule. `PhysicsMode.variable` (default) scales by `WallTime.delta` and runs every system in `Schedules.update`; `PhysicsMode.fixed` scales by `FixedTimestep.stepSeconds` and runs in `Schedules.fixedUpdate` (use for netcode prediction/replays). `Velocity` is in pixels per 60 Hz frame either way.
- **Fixed in-step order**, declared explicitly in `SystemMeta` (not registration order): `CollisionResolutionSystem` (clamps `Velocity`) → `VelocityIntegrationSystem` (applies it to `Transform2D`) → `CollisionDetectionSystem` (spatial-hash broad phase, emits `CollisionEvent`). Each exposes `static const String systemName`. Anything that writes `Velocity` (input, AI, knockback) must run in `preUpdate`/`fixedPreUpdate` or declare `before: [CollisionResolutionSystem.systemName]`.
- Core collision shapes, `CollisionGrid`, and `Pathfinder` live here (moved out of `fledge_tiled`, which re-exports this package for one release).

## Rules for changes

- Collision events (`CollisionEvent`, `ContactYieldStarted`/`Ended`) are consumed by user code AND by other plugins — treat their shape as a public contract.
- When collider shape support expands (e.g. adding a polygon type), update `fledge_tiled`'s collider adapter (`src/collision/tile_collider.dart`) and `fledge_debug`'s gizmos to match.
- Prefer plugin-composable systems: `enableResolution`/`enableIntegration` let users swap in their own; keep that possible without forking the plugin.
- Tests: this package depends on `flutter` and on `fledge_render_2d` (for `Transform2D`), and is in the `test:dart` ignore list, so tests run under `flutter test`. Keep the math itself free of direct Flutter imports anyway. `test/ordering_test.dart` guards system ordering — extend it when adding systems.
