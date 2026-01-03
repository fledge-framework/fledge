# Changelog

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
