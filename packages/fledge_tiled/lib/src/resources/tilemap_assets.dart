import 'dart:ui' show Rect;
import 'package:tiled/tiled.dart' show TiledMap;

import '../components/tilemap_animator.dart';
import '../properties/tiled_properties.dart';
import 'tileset_registry.dart';

/// Resource managing loaded tilemap assets.
///
/// Stores parsed TiledMap data and associated textures.
/// Use this resource to access loaded tilemaps by key.
///
/// Example:
/// ```dart
/// // During app setup
/// final loader = AssetTilemapLoader();
/// final tilemap = await loader.load('maps/level1.tmx', textureLoader);
/// app.world.getResource<TilemapAssets>()!.put('level1', tilemap);
///
/// // Later, spawn the map
/// final assets = world.getResource<TilemapAssets>()!;
/// final loaded = assets.get('level1')!;
/// ```
class TilemapAssets {
  /// Loaded maps by key.
  final Map<String, LoadedTilemap> _maps = {};

  /// Gets a loaded tilemap by key.
  LoadedTilemap? get(String key) => _maps[key];

  /// Stores a loaded tilemap.
  void put(String key, LoadedTilemap tilemap) {
    _maps[key] = tilemap;
  }

  /// Removes a tilemap by key.
  LoadedTilemap? remove(String key) => _maps.remove(key);

  /// Checks if a tilemap is loaded.
  bool contains(String key) => _maps.containsKey(key);

  /// Clears all loaded tilemaps.
  void clear() => _maps.clear();

  /// All loaded tilemap keys.
  Iterable<String> get keys => _maps.keys;

  /// Number of loaded tilemaps.
  int get length => _maps.length;

  /// Whether there are any loaded tilemaps.
  bool get isEmpty => _maps.isEmpty;

  /// Whether there are loaded tilemaps.
  bool get isNotEmpty => _maps.isNotEmpty;
}

/// A fully loaded tilemap with all required resources.
///
/// Contains the parsed map data, texture atlases for each tileset,
/// and extracted animation data.
class LoadedTilemap {
  /// The parsed Tiled map data.
  final TiledMap map;

  /// Loaded tilesets with their texture atlases.
  final List<LoadedTileset> tilesets;

  /// Tile animations extracted from all tilesets.
  ///
  /// Key is the global tile ID (GID), not the local tile ID.
  final Map<int, TileAnimation> animations;

  /// Original source path (for reloading).
  final String sourcePath;

  const LoadedTilemap({
    required this.map,
    required this.tilesets,
    required this.animations,
    required this.sourcePath,
  });

  /// Gets the tileset and local ID for a global tile ID.
  ///
  /// Returns null if the GID is not valid (0 or out of range).
  TilesetLookup? getTilesetForGid(int gid) {
    if (gid == 0) return null;

    // Find the tileset that contains this GID
    // Tilesets are sorted by firstGid in descending order for binary search
    for (int i = tilesets.length - 1; i >= 0; i--) {
      final tileset = tilesets[i];
      if (gid >= tileset.firstGid) {
        final localId = gid - tileset.firstGid;
        if (localId < tileset.tileCount) {
          return TilesetLookup(
            tileset: tileset,
            tilesetIndex: i,
            localId: localId,
          );
        }
      }
    }
    return null;
  }

  /// Gets the animation for a global tile ID.
  TileAnimation? getAnimation(int gid) => animations[gid];

  /// Returns true if the given GID has an animation.
  bool hasAnimation(int gid) => animations.containsKey(gid);

  /// Map width in tiles.
  int get width => map.width;

  /// Map height in tiles.
  int get height => map.height;

  /// Tile width in pixels.
  int get tileWidth => map.tileWidth;

  /// Tile height in pixels.
  int get tileHeight => map.tileHeight;

  /// Whether this is an infinite map.
  bool get infinite => map.infinite;
}

/// Result of looking up a tileset for a GID.
class TilesetLookup {
  /// The loaded tileset.
  final LoadedTileset tileset;

  /// Index of the tileset in the map's tileset list.
  final int tilesetIndex;

  /// Local tile ID within the tileset.
  final int localId;

  const TilesetLookup({
    required this.tileset,
    required this.tilesetIndex,
    required this.localId,
  });

  /// Gets the source rectangle for this tile.
  Rect get sourceRect => tileset.atlas.getSpriteRect(localId);

  /// Gets the tile properties (if any).
  TiledProperties? get properties => tileset.tileProperties[localId];
}
