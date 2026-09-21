# Changelog

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
