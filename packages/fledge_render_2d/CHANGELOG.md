# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Changed

- `fledge_render` merged into this package; the old package remains as a re-export shim for one release.
- Sprites now use a real Canvas backend via `drawRawAtlas`.
- `Sprite` / `AtlasSprite` participate in the `DrawLayer` sort scheme.

### Added

- `SpriteDrawer` + `CanvasSpriteDrawer`; `GpuSpriteDrawer` stub for the future GPU path.
- Typed `BackendSpriteData` payload for the extract → draw path.
- `FledgeRenderView` widget as the retained-mode entry point.
- `SpriteMaterial.normalMap` slot (consumed by `fledge_lighting_2d`).


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

## [0.1.9] - 2026-01-06

### Features

- **fledge_tiled:** Add CulledTilemapExtractor



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

- Initial release of fledge_render_2d
- Transform2D component for local position, rotation, and scale
- GlobalTransform2D with hierarchy propagation
- TransformPropagateSystem for computing world transforms
- Camera2D with orthographic projection
- Pixel-perfect rendering utilities and camera snapping
- Sprite component for textured quad rendering
- SpriteBundle for convenient entity spawning
- TextureAtlas for sprite sheet support
- AtlasSprite for rendering from texture atlases
- AnimationClip and AnimationPlayer for sprite animation
- Material2D system with shader support
- Orientation component for tracking entity facing direction
