## 0.2.3

 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_render_2d): emit TransitionCompleted when a fade transition finishes. ([85d3f225](https://github.com/fledge-framework/fledge/commit/85d3f2250be1ff9b952a5ddf50c6db9eaf78a097))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_save): create fledge_save package. ([48a3a327](https://github.com/fledge-framework/fledge/commit/48a3a327b9c0950ec320d7f805cce19bf7a300f6))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

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
