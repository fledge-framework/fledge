# Changelog

## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [Unreleased]

### Features

- **fledge_ecs:** Add game checkpoint api



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

## [Unreleased]

### Bug Fixes

- Update dependencies to latest stable versions
- **fledge:** Update dependencies, upgrade melos to v7

### Miscellaneous

- **license:** Remove whitespace from license files
- Update license text
- Bump versions



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
