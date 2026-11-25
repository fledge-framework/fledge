# fledge_physics

## Purpose
Layer-based collision detection and resolution with velocity integration, plus grid-based A* pathfinding.

## Status: Functional

## Stats
- Source: 16 files, ~2,265 LOC
- Tests: 5 files (contact yield, dynamic blocking, ordering self-check, spatial hash, velocity integration)
- TODOs in code: 0

## What Works
- Collision layers and masks (bitfield-based filtering)
- Sensor entities (detect overlap without physical response)
- Velocity component with integration (variable or fixed timestep via `PhysicsMode`)
- Collision resolution (clamps `Velocity` against solid colliders before movement)
- Opt-in dynamic-vs-dynamic blocking (`CollisionConfig.blocksDynamic`) with timed yielding (`yieldAfter`)
- Spatial-hash broad phase (`SpatialHash`, cell size via `PhysicsConfig.spatialHashCellSize`)
- `CollisionEvent` published through the ECS event queue (double-buffered, frame-scoped)
- A* pathfinding on a `CollisionGrid` (`Pathfinder`) — moved here from `fledge_tiled`

## Gaps
- **[P1]** Limited error handling for degenerate cases (zero-size colliders, NaN positions)
- **[P2]** No tests for layer filtering or sensor behaviour in isolation; no pathfinding tests

## Action Items
1. Add unit tests for layer filtering, sensors, and `Pathfinder`
2. Add error handling for degenerate cases (zero-size colliders, NaN positions)

## Architecture Notes
- **Entry point**: `lib/fledge_physics.dart` (barrel export)
- **PhysicsPlugin** (`lib/src/plugin.dart`): Takes a `PhysicsConfig` (`mode`, `enableResolution`, `enableIntegration`, `spatialHashCellSize`). Registers `CollisionEvent`, `ContactYieldStarted`/`ContactYieldEnded` events, inserts the `ContactYieldTracker` resource, and adds all three systems to `Schedules.update` (`PhysicsMode.variable`, default, scales by `WallTime.delta`) or `Schedules.fixedUpdate` (`PhysicsMode.fixed`, scales by `FixedTimestep.stepSeconds`). `Velocity` is in pixels per 60 Hz frame in both modes.
- **Components / events** (`lib/src/components/`):
  - `CollisionConfig`: Layer, mask, sensor flag, `blocksDynamic`, `yieldAfter`
  - `Velocity`: 2D velocity for integration
  - `CollisionEvent`: Event (not a component) carrying `entityA`/`entityB` — read with `world.eventReader<CollisionEvent>()`
  - `ContactYieldStarted` / `ContactYieldEnded` (`contact_yield.dart`): Events for dynamic pairs that start/stop passing through each other
- **Shapes** (`lib/src/collision/collision_shapes.dart`): `Collider` plus `RectangleShape`, `EllipseShape`, `PolygonShape`, `PolylineShape`, `PointShape`.
- **CollisionLayers** (`lib/src/layers/collision_layers.dart`): Bitfield constants and helpers for layer/mask configuration.
- **Pathfinding** (`lib/src/pathfinding/`): `CollisionGrid` (walkability grid) and `Pathfinder` (A*, returns `PathResult`).
- **Systems** (`lib/src/systems/`): Fixed order `collision_resolution → velocity_integration → collision_detection`, all declared explicitly in `SystemMeta`. Reference them via the constants `CollisionResolutionSystem.systemName` (`'collision_resolution'`), `VelocityIntegrationSystem.systemName` (`'velocity_integration'`), `CollisionDetectionSystem.systemName` (`'collision_detection'`) in `before:` / `after:` — not the Dart class names. Resolution and integration have `.fixed()` const constructors for fixed mode. There is no cleanup system.
- **Layer filtering**: Dual condition — `(a.layer & b.mask) != 0 && (b.layer & a.mask) != 0`. Framework reserves bits 0-7; games use bits 8-31 (`CollisionLayers.gameLayersStart`). Standard constants in `CollisionLayers` (solid=0x0001, trigger=0x0002).
- **Sensors**: Same layer/mask config but `isSensor = true` — generate collision events without blocking movement.
- **Events are frame-scoped**: `CollisionEvent`s live in the double-buffered event queue, so readers see the previous frame's collisions.
- **Schedule ordering rule**: any game system that writes `Velocity` (input, AI, knockback) **must** run before `collision_resolution`. Simplest: put the system in `Schedules.preUpdate` (or `Schedules.fixedPreUpdate` in fixed mode) — different schedule, always earlier. Alternative: stay in the physics schedule and declare `before: [CollisionResolutionSystem.systemName]`. Without either, the scheduler breaks the tie by registration order, physics clamps last frame's velocity first, input overwrites it with a wall-ward value, and velocity integration pushes the player through the wall. Everything compiles, tests pass, the player clips through. `App.checkScheduleOrdering()` (in `fledge_ecs`) flags this class of bug; `test/ordering_test.dart` self-checks the plugin and `examples/drifter/test/schedule_ordering_test.dart` is the game-level template.
- **Tests**: Flutter package (depends on `fledge_render_2d`) — run with `flutter test`.
