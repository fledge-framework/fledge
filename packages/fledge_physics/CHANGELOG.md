# Changelog

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
