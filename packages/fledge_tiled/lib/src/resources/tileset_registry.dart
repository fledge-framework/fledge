import 'dart:ui' show Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureAtlas;

import '../collision/collision_shapes.dart';
import '../components/tilemap_animator.dart';
import '../properties/tiled_properties.dart';

/// Resource for managing shared tilesets across multiple maps.
///
/// When multiple maps use the same external tileset (.tsx file),
/// this registry allows sharing the loaded tileset data.
///
/// Example:
/// ```dart
/// final registry = world.getResource<TilesetRegistry>()!;
///
/// // Check if already loaded
/// if (!registry.isLoaded('tilesets/terrain.tsx')) {
///   final tileset = await loadTileset('tilesets/terrain.tsx');
///   registry.register('tilesets/terrain.tsx', tileset);
/// }
///
/// final tileset = registry.get('tilesets/terrain.tsx')!;
/// ```
class TilesetRegistry {
  /// Loaded tilesets by source path.
  final Map<String, LoadedTileset> _tilesets = {};

  /// Gets a tileset by source path.
  LoadedTileset? get(String source) => _tilesets[source];

  /// Registers a loaded tileset.
  void register(String source, LoadedTileset tileset) {
    _tilesets[source] = tileset;
  }

  /// Unregisters a tileset.
  LoadedTileset? unregister(String source) => _tilesets.remove(source);

  /// Checks if a tileset is loaded.
  bool isLoaded(String source) => _tilesets.containsKey(source);

  /// Clears all registered tilesets.
  void clear() => _tilesets.clear();

  /// All registered tileset paths.
  Iterable<String> get sources => _tilesets.keys;

  /// Number of registered tilesets.
  int get length => _tilesets.length;
}

/// A loaded tileset with texture and metadata.
///
/// Contains everything needed to render and query tiles from this tileset.
class LoadedTileset {
  /// Source path of the tileset (TSX file or embedded).
  final String source;

  /// Tileset name from Tiled.
  final String name;

  /// First GID for this tileset in the map.
  ///
  /// This is map-specific and may vary when the same tileset
  /// is used in different maps.
  final int firstGid;

  /// Tile width in pixels.
  final int tileWidth;

  /// Tile height in pixels.
  final int tileHeight;

  /// Number of columns in the tileset image.
  final int columns;

  /// Total number of tiles in the tileset.
  final int tileCount;

  /// Spacing between tiles in pixels.
  final int spacing;

  /// Margin around the tileset image in pixels.
  final int margin;

  /// The texture atlas containing the tileset image.
  final TextureAtlas atlas;

  /// Tile-specific properties (local ID -> properties).
  final Map<int, TiledProperties> tileProperties;

  /// Tile animations (local ID -> animation).
  final Map<int, TileAnimation> animations;

  /// Collision shapes per tile (local ID -> shapes).
  final Map<int, List<CollisionShape>> collisionShapes;

  const LoadedTileset({
    required this.source,
    required this.name,
    required this.firstGid,
    required this.tileWidth,
    required this.tileHeight,
    required this.columns,
    required this.tileCount,
    required this.atlas,
    this.spacing = 0,
    this.margin = 0,
    this.tileProperties = const {},
    this.animations = const {},
    this.collisionShapes = const {},
  });

  /// Gets the source rectangle for a local tile ID.
  Rect getTileRect(int localId) => atlas.getSpriteRect(localId);

  /// Checks if a local ID is valid for this tileset.
  bool containsTile(int localId) => localId >= 0 && localId < tileCount;

  /// Gets properties for a tile, or null if none defined.
  TiledProperties? getProperties(int localId) => tileProperties[localId];

  /// Gets animation for a tile, or null if not animated.
  TileAnimation? getAnimation(int localId) => animations[localId];

  /// Gets collision shapes for a tile, or empty list if none defined.
  List<CollisionShape> getCollisionShapes(int localId) =>
      collisionShapes[localId] ?? const [];

  /// Returns true if a tile has custom properties.
  bool hasProperties(int localId) => tileProperties.containsKey(localId);

  /// Returns true if a tile has an animation.
  bool hasAnimation(int localId) => animations.containsKey(localId);

  /// Returns true if a tile has collision shapes.
  bool hasCollision(int localId) => collisionShapes.containsKey(localId);

  /// Number of rows in the tileset.
  int get rows => (tileCount + columns - 1) ~/ columns;

  /// Converts a global tile ID to a local tile ID.
  ///
  /// Returns null if the GID doesn't belong to this tileset.
  int? gidToLocalId(int gid) {
    final localId = gid - firstGid;
    if (localId >= 0 && localId < tileCount) {
      return localId;
    }
    return null;
  }

  /// Converts a local tile ID to a global tile ID.
  int localIdToGid(int localId) => localId + firstGid;
}
