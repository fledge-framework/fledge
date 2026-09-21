## 0.2.3

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_flutter): clean up deprecated api files. ([9efc0894](https://github.com/fledge-framework/fledge/commit/9efc089434d00be56bc2b66af52bb1e1c0a18525))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_render): add plugin to auto register extractors. ([2485ee2b](https://github.com/fledge-framework/fledge/commit/2485ee2bb4db5a3f5218058bfe2646f4adb2f8e0))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Deprecated

- Package deprecated — merged into `fledge_render_2d`. This release is a re-export shim; migrate to `package:fledge_render_2d/fledge_render_2d.dart`.


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
