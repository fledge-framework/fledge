import 'dart:ui' show Offset, Rect;

import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show TextureAtlas, TextureHandle;

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
@Deprecated(
  'Prefer `Assets<Tileset>` from fledge_assets. TilesetRegistry stays as a '
  'path-keyed facade for one release.',
)
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
/// The atlas texture of an image-collection tileset, which has no single
/// image: each tile has its own ([LoadedTileset.tileImages]). Its id can't
/// collide with a real texture (ids from 1) or `kSolidColorTexture` (0).
const TextureHandle kNoTilesetImageTexture = TextureHandle(
  id: -1,
  width: 0,
  height: 0,
);

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

  /// Each tile's own image, for an image-collection tileset (local ID ->
  /// texture); empty for a tileset cut from one image ([atlas]).
  ///
  /// An image collection's local IDs can have gaps where tiles were
  /// removed in Tiled.
  final Map<int, TextureHandle> tileImages;

  /// Each tile's class (Tiled's "Class", formerly "Type"), by local ID,
  /// where one is set. A tile object without a class of its own takes its
  /// tile's.
  final Map<int, String> tileClasses;

  /// The tiles drawn with characters, y-sorted, wherever they're painted
  /// (the bool tile property `y_sort`), by local ID: the span, in the
  /// tile's own pixels and before flips, whose bottom is the line it sorts
  /// at. That's its collision's bounds (so a wall sorts where its base
  /// is), the whole tile without collision, or a zero-height span at its
  /// int property `sort_y`. See [ySortLine].
  final Map<int, Rect> ySortSpans;

  /// The tileset's tile offset (Tiled's "Drawing Offset"), in pixels: how
  /// far every tile is drawn from its cell's bottom-left corner.
  final Offset tileOffset;

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
    this.tileImages = const {},
    this.tileClasses = const {},
    this.ySortSpans = const {},
    this.tileOffset = Offset.zero,
  });

  /// Where tile [localId], painted with Tiled's [flipFlags]
  /// (`TileFlipFlags`), sorts among characters: the y of its line, in
  /// pixels from the tile's top; null for a tile drawn on its layer.
  ///
  /// Tiled swaps x and y first (diagonal), then mirrors (horizontal,
  /// vertical): only the swap and the vertical mirror move a line.
  double? ySortLine(int localId, int flipFlags) {
    final span = ySortSpans[localId];
    if (span == null) return null;
    final diagonal = flipFlags & 4 != 0;
    final vertical = flipFlags & 2 != 0;
    final top = diagonal ? span.left : span.top;
    final bottom = diagonal ? span.right : span.bottom;
    final height = (diagonal ? tileWidth : tileHeight).toDouble();
    return vertical ? height - top : bottom;
  }

  /// Whether each tile is its own image rather than a cell of [atlas].
  bool get isImageCollection => tileImages.isNotEmpty;

  /// The tile's own image in an image-collection tileset, or null.
  TextureHandle? getTileImage(int localId) => tileImages[localId];

  /// The tile's class, or null if none is set.
  String? getTileClass(int localId) => tileClasses[localId];

  /// The texture tile [localId] is drawn from: its own image in an image
  /// collection, otherwise the tileset's atlas.
  TextureHandle getTileTexture(int localId) =>
      tileImages[localId] ?? atlas.texture;

  /// The source rectangle of tile [localId] in [getTileTexture]: the whole
  /// image for an image-collection tile, else its cell of the atlas.
  Rect getTileRect(int localId) {
    final image = tileImages[localId];
    if (image != null) {
      return Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
    }
    return atlas.getSpriteRect(localId);
  }

  /// Checks if a local ID is valid for this tileset.
  bool containsTile(int localId) => isImageCollection
      ? tileImages.containsKey(localId)
      : localId >= 0 && localId < tileCount;

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
