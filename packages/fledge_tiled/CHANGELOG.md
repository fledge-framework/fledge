# Changelog

## [0.2.0] - 2026-09-20

### Changed

- `Collider`, `CollisionShape`, `CollisionGrid`, `Pathfinder` moved to `fledge_physics`; deprecated re-exports retained for one release.
- Now depends on `fledge_physics`.

### Added

- `Assets<TilemapAsset>` / `Assets<TilesetAsset>` integration.

### Notes

- Continues to pin `xml: ^6.6.1`. `xml 7.0.0` cannot yet be adopted because
  `tiled 0.11.1` (the newest release compatible with the Fledge Dart 3.6 SDK
  floor) still constrains `xml: ^6.1.0`. `tiled 0.12.0` supports `xml ^7.0.0`
  but bumps its own SDK floor to Dart `>=3.11` and reshapes the external
  tileset API (`TsxProvider` -> `ParserProvider`, `TileMapParser.parseTmx` ->
  `TiledMap.fromString`), so the upgrade is deferred until Fledge's SDK
  floor is raised. Tracked as a TODO in `pubspec.yaml`.


## [0.1.14] - 2026-04-14



## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



## [0.1.11] - 2026-01-21



## [0.1.10] - 2026-01-06

## [0.1.9] - 2026-01-06

## [0.1.9] - 2026-01-06

### Features

- **fledge_tiled:** Add CulledTilemapExtractor



## [0.1.8] - 2026-01-06

## [0.1.7] - 2026-01-05

## [0.1.7] - 2026-01-05

### Features

- **fledge_tiled:** Enable class based tile sorting

### Miscellaneous

- Bump dependencies



## [0.1.6] - 2026-01-05

## [0.1.5] - 2026-01-04



## [0.1.4] - 2026-01-04



## [0.1.3] - 2026-01-04

## [0.1.2] - 2026-01-03

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
