# Changelog

## [0.1.9] - 2026-01-06



## [0.1.8] - 2026-01-06



## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [0.1.6] - 2026-01-05

### Bug Fixes

- **fledge_render_flutter:** Clean up deprecated api files

### Features

- **fledge_render:** Add plugin to auto register extractors

### Refactoring

- **fledge_render:** Combine core systems from fledge_render_flutter



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.6] - 2026-01-04

### Added

- **RenderPlugin** - Plugin that sets up Extractors, RenderWorld, and RenderExtractionSystem automatically
- **RenderLayer** classes merged from `fledge_render_flutter`:
  - `RenderLayer` - Abstract base class for render layers
  - `CompositeRenderLayer` - Combines multiple layers in order
  - `TransformedRenderLayer` - Applies a transform matrix before rendering
  - `ClippedRenderLayer` - Clips rendering to a rectangle
  - `ConditionalRenderLayer` - Conditionally renders based on a predicate

### Changed

- Package now requires Flutter SDK (for Canvas and painting APIs)

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

### Added

- DrawLayer enums for layer-based sort keys

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_render
- Two-World Architecture: Main World and Render World separation
- Extractor system for copying game data to render data
- Render graph for modular pipeline definition
- Render scheduling infrastructure
