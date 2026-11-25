# fledge_tiled

## Purpose
TMX/TSX tilemap loading, rendering, animation, collision extraction, and walkability-grid generation for pathfinding.

## Status: Functional

## Stats
- Source: 21 files, ~3,620 LOC
- Tests: 3 files (`tile_sprite_conversion_test.dart`, `tile_sort_order_test.dart`, `ordering_test.dart`)
- TODOs in code: 1 (`TODO(next-major)`: drop the `fledge_physics` re-export from the barrel)

## What Works
- TMX/TSX file loading via asset loader (`tiled` ^0.12)
- Tile layer rendering with viewport culling for performance
- Animated tile support with frame sequencing
- Object layer parsing (spawn points, triggers, zones)
- Collision shape extraction from tile/object properties
- Walkability `CollisionGrid` extraction for A* (`Pathfinder` itself lives in `fledge_physics`)
- Spawn configuration for entity creation from map objects

## Gaps
- **[P1]** Minimal test coverage (tile→sprite conversion, extraction sort order, schedule ordering)
- **[P2]** Memory management — loaded tilemaps never explicitly disposed

## Action Items
1. Add unit tests for TMX parsing, collision extraction, and grid extraction
2. Add tilemap disposal/unloading support for level transitions

## Architecture Notes
- **Entry point**: `lib/fledge_tiled.dart` (barrel export; also re-exports `fledge_physics` for back-compat — deprecated, slated for removal next major)
- **TiledPlugin** (`lib/src/plugin.dart`): Takes `TiledPluginConfig` (`respectLayerVisibility`, `chunkSize`, `maxLoadedChunks`). Inserts `Assets<TilemapAsset>` / `Assets<TilesetAsset>` plus the deprecated `TilemapAssets` / `TilesetRegistry` facades; registers `SpawnTilemapEvent` / `TilemapSpawnedEvent`; adds `TilemapSpawnSystem` (`Schedules.first`) and `TileAnimationSystem` (`Schedules.update`). Registers `TilemapExtractor` only if an `Extractors` resource already exists — add `RenderPlugin` (from `fledge_render_2d`) **before** `TiledPlugin`.
- **Components**:
  - `Tilemap` (`lib/src/components/tilemap.dart`): Parsed map data attached to an entity
  - `TileLayer` (`lib/src/components/tile_layer.dart`): Individual layer within a tilemap (chunked via `TileChunk` / `ChunkKey`)
  - `ObjectLayer` (`lib/src/components/object_layer.dart`): Named objects (`TiledObject`) — spawn points, triggers
  - `TilemapAnimator` (`lib/src/components/tilemap_animator.dart`): Drives animated tile frames
- **Loader** (`lib/src/loader/`): `TilemapLoader` (abstract) and `AssetTilemapLoader` (Flutter asset bundle). Parses TMX/TSX XML. Asset-pipeline loaders `TmxLoader` / `TsxLoader` live in `lib/src/resources/tiled_assets.dart` (`TilemapAsset` = `LoadedTilemap`, `TilesetAsset` = `LoadedTileset`).
- **Extraction** (`lib/src/extraction/`): `TilemapExtractor` emits `ExtractedSprite`s into the RenderWorld (via `tile_sprite_conversion.dart`); `CulledTilemapExtractor` adds viewport culling. A deprecated `ExtractedTile` is still emitted alongside each sprite for the deprecation window — read `ExtractedSprite` in new code. Draw order: `tileSortKey` (sub-order `row * 100 + layerIndex`, clamped into the `DrawLayer` range) plus `tilePreciseSubOrder` (unclamped) as `preciseSubOrder` on both outputs; order with `ExtractedSprite.sortByDrawOrder` / `ExtractedTile.compareDrawOrder`.
- **Pathfinding** (`lib/src/pathfinding/collision_extractor.dart`): `extractCollisionGrid(...)` builds a `CollisionGrid` from tile collision data; run `Pathfinder` (from `fledge_physics`) on it.
- **Collision** (`lib/src/collision/tile_collider.dart`): `TileCollider` converts Tiled objects/tiles to `fledge_physics` collision shapes in local space.
- **SpawnConfig** (`lib/src/config/spawn_config.dart`): `TilemapSpawnConfig` maps Tiled object types to entity spawn functions via `ObjectTypeConfig`; `TileLayerConfig` per layer.
- **Two-stage spawn**: Load asset → `SpawnTilemapEvent` triggers `TilemapSpawnSystem` → `TilemapSpawnedEvent` emitted.
- **System names**: `TilemapSpawnSystem.systemName` (`'tilemap_spawn'`); `TileAnimationSystem` uses the literal `'tile_animation'` (no constant).
- **Infinite map support**: Chunk-based loading with configurable chunk size and max chunks.
- **Tests**: Flutter package — run with `flutter test`.
