# Changelog

## [0.1.6] - 2026-01-05

## [0.1.6] - 2026-01-05

### Bug Fixes

- **fledge_render_flutter:** Clean up deprecated api files

### Refactoring

- **fledge_render:** Combine core systems from fledge_render_flutter



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.6] - 2026-01-04

### Deprecated

- **This package is deprecated.** Use `package:fledge_render/fledge_render.dart` instead.
- All `RenderLayer` classes have been merged into `fledge_render`
- This package now only re-exports from `fledge_render` for backwards compatibility

## [0.1.5] - 2026-01-04

### Changed

- Internal refactoring

## [0.1.4] - 2026-01-04

### Changed

- Internal refactoring

## [0.1.3] - 2026-01-04

### Changed

- Internal refactoring

## [0.1.2] - 2026-01-03

### Fixed

- Update dependencies to latest stable versions

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_render_flutter
- Canvas backend using Flutter's Canvas API
- Backend abstraction layer for future GPU support
- BackendSelector for automatic backend selection
- Texture management and creation utilities
- RenderLayer system for organized rendering
