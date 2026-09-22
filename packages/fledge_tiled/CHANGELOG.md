## 0.3.0

 - **REFACTOR**(fledge_tiled): depend on fledge_render_2d instead of the fledge_render shim. ([72becfe6](https://github.com/fledge-framework/fledge/commit/72becfe6bef448a30cf5a4d59bbd6fed651678a9))
 - **REFACTOR**(fledge_render): combine core systems from fledge_render_flutter. ([4126c272](https://github.com/fledge-framework/fledge/commit/4126c272f2ddd3a198a285c5a80afdbea79aa126))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FIX**(fledge_render_2d): fix null safety error on private field. ([6378bb1e](https://github.com/fledge-framework/fledge/commit/6378bb1eb375413aebc469a49353bbcf126f615c))
 - **FIX**(fledge): update dependencies, upgrade melos to v7. ([e513327a](https://github.com/fledge-framework/fledge/commit/e513327a9f77e28d2126f9140e146a9b322c7b94))
 - **FIX**: update dependencies to latest stable versions. ([9e696757](https://github.com/fledge-framework/fledge/commit/9e696757bef8acc802da081690dc918e51f20b9d))
 - **FEAT**(fledge_tiled): emit ExtractedSprite so tiles draw through FledgeRenderView. ([76ad87f7](https://github.com/fledge-framework/fledge/commit/76ad87f7c9f3b5a8d1bb64bc9847931924227b44))
 - **FEAT**(fledge_tiled): read tilemaps from Assets<TilemapAsset>. ([eb0515f2](https://github.com/fledge-framework/fledge/commit/eb0515f27f746f536a4060683b178716b9d40b3c))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))
 - **FEAT**(fledge_tiled): add CulledTilemapExtractor. ([8ad8e658](https://github.com/fledge-framework/fledge/commit/8ad8e65817ad8074f55929085fe6d8747da6e114))
 - **FEAT**(fledge_tiled): add support for pathfinding. ([23ba2e0c](https://github.com/fledge-framework/fledge/commit/23ba2e0cad68aabb2bc8a7a0fab52c0af96acd58))
 - **FEAT**(fledge_tiled): enable class based tile sorting. ([291d9a12](https://github.com/fledge-framework/fledge/commit/291d9a12ed5d99912919497b024e7fdd286ae1ce))
 - **FEAT**(fledge_tiled): refactor TilemapSpawnConfig API. ([35b12d1e](https://github.com/fledge-framework/fledge/commit/35b12d1eaa72f7e703f6820b4e0f8d69452f509e))
 - **FEAT**(fledge_render): use layer enums rather than magic numbers. ([b7337885](https://github.com/fledge-framework/fledge/commit/b73378851a5fc04ea34893e6cd1690a6067b3a46))
 - **FEAT**: initial commit. ([0e057c5a](https://github.com/fledge-framework/fledge/commit/0e057c5a4646a51d2f7f4c6bd5ed552b745b1b7d))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- Migrated to `tiled: ^0.12.0` and `xml: ^7.0.0`. The `AssetTilemapLoader` internal `TsxProvider` was rewritten against the new `ParserProvider` contract (`bool canProvide(String)` + `Parser getSource(String)`), and TMX parsing now goes through `TiledMap.parseTmx(xml, providers: [...])` instead of the removed `TileMapParser.parseTmx`. Public API unchanged.
- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Required for `tiled` 0.12 and the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Changed

- `Collider`, `CollisionShape`, `CollisionGrid`, `Pathfinder` moved to `fledge_physics`; deprecated re-exports retained for one release.
- Now depends on `fledge_physics`.
- Upgraded to `tiled: ^0.12.0` and `xml: ^7.0.0`. The `AssetTilemapLoader`
  internal `TsxProvider` was migrated to the new `ParserProvider` contract
  (`bool canProvide(String)` + `Parser getSource(String)`), and TMX parsing
  now goes through `TiledMap.parseTmx(xml, providers: [...])` instead of the
  removed `TileMapParser.parseTmx`. No public API changes.

### Added

- `Assets<TilemapAsset>` / `Assets<TilesetAsset>` integration.


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
