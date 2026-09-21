# Changelog

## [0.2.0] - 2026-09-20

### Changed

- Scheduler rewritten around named schedule graph (`Schedules` + `Scheduler`); `stage:` argument on `addSystem` renamed to `schedule:`.
- `App.tick()` restructured to drive extract + render schedules on top of the main schedule.
- Query iterators snapshot archetype membership at iter start, fixing a silent-drop bug when systems spawned/despawned matching entities mid-iteration.

### Added

- `FixedTimestep` resource and fixed-timestep dispatch chain (`Schedules.fixedUpdate`).
- `Query1..4<T>` / `QueryMut1..4<T>` marker types; reads/writes are now inferred from the marker in generator output.
- `WallTime` / `WallTimePlugin` for real-time clocks.

### Deprecated

- `Time` / `TimePlugin` — use `WallTime` / `WallTimePlugin`.


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



## [0.1.11] - 2026-01-21

## [0.1.10] - 2026-01-06

## [0.1.10] - 2026-01-06

### Features

- **fledge_save:** Create fledge_save package

### Miscellaneous

- Bump versions
- Bump versions



## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.3] - 2026-01-04

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field

### Features

- **fledge_tiled:** Refactor TilemapSpawnConfig API
- **fledge_physics:** Extract collision engine into new package.

### Miscellaneous

- **lint:** Resolve const identifier issues



## [0.1.2] - 2026-01-03

## [0.1.1] - 2025-01-03

### Added

- Session checkpoint API for managing session vs game-level state:
  - `App.markSessionCheckpoint()` - Mark current plugins as session-level
  - `App.resetToSessionCheckpoint()` - Reset to session state, cleanup game plugins
- `World.resetGameState()` - Clear entities, archetypes, and events while preserving resources
- `Schedule.clear()` - Remove all systems from all stages
- `SystemStage.clear()` - Remove all systems from a stage
- `World.archetypeCount` - Get total number of archetypes
- `World.resourceCount` - Get total number of resourcse

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_ecs
- Entity and Component system with typed queries
- World management for entities and resources
- System scheduling with stages and ordering
- Resource management for global state
- Event system for inter-system communication
- Plugin architecture for modular game features
- Query system: `query`, `query2`, `query3`, `query4` for multi-component queries
- Time plugin with delta time tracking
- Entity commands: spawn, despawn, insert, remove
