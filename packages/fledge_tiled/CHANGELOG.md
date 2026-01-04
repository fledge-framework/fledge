# Changelog

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

### Features

- **fledge_render:** Use layer enums rather than magic numbers

### Miscellaneous

- **license:** Remove whitespace from license files
- Update license text



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-02

### Added

- Initial release of fledge_tiled
- TMX/TSX map and tileset loading
- AssetTilemapLoader for loading from Flutter assets
- TilemapAssets resource for storing loaded tilemaps
- Tilemap component for map entities
- TileLayer component for efficient tile rendering
- ObjectLayer component for Tiled object access
- SpawnTilemapEvent for loading maps into the world
- TilemapSpawnConfig for customizing spawn behavior
- Object entity spawning with custom callbacks
- TiledProperties for type-safe property access
- Collision shape generation from Tiled objects
- TileCollider for tile-based collision
- Animated tile support with TilemapAnimator
- TilemapExtractor for render world integration
