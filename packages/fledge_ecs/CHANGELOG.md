## 0.2.3

 - **FIX**(fledge_ecs): explicit before/after overrides registration-order conflict edges. ([e698e92f](https://github.com/fledge-framework/fledge/commit/e698e92fd4bf396d60d5131f94ea3a0296b9f25e))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FIX**(fledge_input): fix timing issue for action resolution. ([62356b0d](https://github.com/fledge-framework/fledge/commit/62356b0d81db96018025579a544517bf85499de5))
 - **FIX**(fledge_ecs): create missing getters. ([e8f8ee3b](https://github.com/fledge-framework/fledge/commit/e8f8ee3ba27bf40d69599dda78ed27353f0cd7bb))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_net): add network packet encryption. ([843c1c99](https://github.com/fledge-framework/fledge/commit/843c1c9911d82a997f8d52841267409d6cdceb4c))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_ecs): add game checkpoint api. ([3b140dcc](https://github.com/fledge-framework/fledge/commit/3b140dccd5e52f9e6159e2059c161914cbafb6f7))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_ecs): add advanced disposal functions. ([79479d10](https://github.com/fledge-framework/fledge/commit/79479d1027eb91954975c140c390f208a4f7de84))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))
 - **DOCS**(fledge_ecs): schedule_label comments reflect that App.tick drives fixed/extract/render. ([82292987](https://github.com/fledge-framework/fledge/commit/82292987556e9f327048a00c1a418c7f506b5b62))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` (was 3.6). Matches the workspace-wide floor required by `analyzer` 13.x+ and `flutter_soloud` 4.x+.


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
