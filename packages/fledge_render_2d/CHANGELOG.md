# Changelog

## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [Unreleased]

### Refactoring

- **fledge_render:** Combine core systems from fledge_render_flutter



## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [Unreleased]

### Bug Fixes

- **fledge_render_2d:** Fix null safety error on private field

### Features

- **fledge_tiled:** Refactor TilemapSpawnConfig API



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
