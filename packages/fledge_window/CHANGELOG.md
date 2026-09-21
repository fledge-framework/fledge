# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Fixed

- Removed two unused `catch (e, _)` stack-trace variables to clear `unused_catch_stack` analyzer warnings.

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Changed

- Consumer migration to the new `schedule:` API.


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



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.2] - 2026-01-03

## [0.1.2] - 2026-01-03

### Bug Fixes

- Update dependencies to latest stable versions
- **fledge:** Update dependencies, upgrade melos to v7

### Miscellaneous

- **license:** Remove whitespace from license files
- Update license text

### Ci

- **github:** Create changelogs for all packages on release



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_window
- Window modes: fullscreen, borderless, and windowed
- Runtime mode switching with toggleFullscreen, setWindowMode, cycleWindowMode
- WindowState resource for querying current window state
- DisplayInfo resource for monitor information
- WindowModeChanged event
- WindowResized event
- WindowFocusChanged event
- World extension methods for window control
