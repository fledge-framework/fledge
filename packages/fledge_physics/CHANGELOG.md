## 0.3.1

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_physics): expose systemName on collision + velocity systems. ([4b0e8a58](https://github.com/fledge-framework/fledge/commit/4b0e8a58c63ef1cc974419c777e23d5a8fefa1e4))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

## 0.3.0

 - **FIX**(fledge_physics): yieldAfter counts blocked contact, not only overlap. ([f6bbb220](https://github.com/fledge-framework/fledge/commit/f6bbb220509bead9664c04cc4dd97051f0290eda))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_physics): add flutter dependency to package. ([c6608ee5](https://github.com/fledge-framework/fledge/commit/c6608ee5128672c4ec03963ca3b4abd8c507673f))
 - **FEAT**(fledge_physics): yieldAfter — pass-through after sustained contact. ([5af431e0](https://github.com/fledge-framework/fledge/commit/5af431e06101b6f80350c8e23416c58eedc202bb))
 - **FEAT**(fledge_physics): opt-in dynamic-vs-dynamic blocking. ([e264f586](https://github.com/fledge-framework/fledge/commit/e264f586778836cd99b64aafdbdadb056455885f))
 - **FEAT**(fledge_physics): fixed-step integration + resolution. ([271b41de](https://github.com/fledge-framework/fledge/commit/271b41defa06e8e9f58218e39fed4c6ab3989720))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(examples): add new drifter game demo. ([c126a144](https://github.com/fledge-framework/fledge/commit/c126a144fe20402104b01a259d4ee36a00327d92))
 - **FEAT**(fledge_physics): extract collision engine into new package. ([cc31acc0](https://github.com/fledge-framework/fledge/commit/cc31acc0a02159fd39fa0dcdb9655d223c4c0027))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- `Collider`, `CollisionShape`, `CollisionGrid`, `Pathfinder` moved in from `fledge_tiled`.
- Spatial-hash broad-phase.

### Changed

- `CollisionEvent` is now a real event queue (one-frame latency) rather than a marker component.

### Removed

- `CollisionCleanupSystem` — no longer needed with event-queue collisions.


## [0.1.14] - 2026-04-14

## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



## [0.1.11] - 2026-01-21



## [0.1.10] - 2026-01-06

## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [0.1.5] - 2026-01-04

## [0.1.5] - 2026-01-04

### Miscellaneous

- **fledge_physics:** Provide docs for remaining public apis



## [0.1.4] - 2026-01-04



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-01-04

### Added

- Initial release of fledge_physics
- `CollisionConfig` component with layer/mask bitmask filtering and sensor support
- `CollisionEvent` component for collision notifications
- `Velocity` component for marking dynamic entities
- `CollisionLayers` base class with reserved framework layers and game layer start point
- `CollisionDetectionSystem` - generates collision events for overlapping entities with layer filtering
- `CollisionResolutionSystem` - wall-sliding physics that prevents movement into solid colliders
- `CollisionCleanupSystem` - removes collision events at end of frame
- `PhysicsPlugin` - easy integration via single plugin registration
- Sensor support - trigger zones that generate events without blocking movement
- Two-way layer filtering - both entities must have compatible layer/mask combinations
