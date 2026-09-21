# Changelog

## [Unreleased]

### Changed

- Widened the `analyzer` dependency constraint from `^12.0.0` to `>=12.0.0 <15.0.0` so the package accepts the current stable `analyzer` (14.x) alongside 12.x/13.x. The generator only touches `Element`/`InterfaceType` APIs that are stable across all three major versions. Clears the pana "constraint doesn't accept latest stable" signal.

## [0.2.0] - 2026-09-20

### Fixed

- `_analyzeQueryParameter` now infers reads/writes from `Query<T>` vs `QueryMut<T>`, resolving false conflicts in the scheduler.


## [0.1.14] - 2026-04-14



## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14

## [0.1.12] - 2026-04-14

### Features

- **fledge_net:** Create net package

### Miscellaneous

- Update github workflow for new package



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



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.2] - 2026-01-03

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_ecs_generator
- Code generation for `@component` annotated classes
- Code generation for `@system` annotated functions
- Generated plugin for automatic component and system registration
- Integration with build_runner
