import 'dart:ui' show Color, Offset;
import 'package:tiled/tiled.dart' show Layer;

/// Component for a single tile layer.
///
/// Each tile layer is a child entity of the Tilemap entity.
/// Contains pre-computed tile data for efficient rendering.
///
/// Example:
/// ```dart
/// for (final (entity, layer) in world.query1<TileLayer>().iter()) {
///   if (layer.visible) {
///     print('Layer ${layer.name} has ${layer.tiles?.length ?? 0} tiles');
///   }
/// }
/// ```
class TileLayer {
  /// Layer name from Tiled.
  final String name;

  /// Layer index for sorting (lower = rendered first).
  final int layerIndex;

  /// Reference to the parsed layer data.
  final Layer tiledLayer;

  /// Opacity (0.0 - 1.0).
  double opacity;

  /// Visibility flag.
  bool visible;

  /// Offset from map origin in pixels.
  final Offset offset;

  /// Parallax factor (1.0 = no parallax).
  final Offset parallax;

  /// Tint color applied to all tiles in this layer.
  Color tintColor;

  /// The layer class from Tiled (e.g., "above" for foreground layers).
  ///
  /// This corresponds to the `class` attribute in Tiled 1.9+, used for
  /// custom layer classification. Common values:
  /// - `null` or empty: Normal ground layer
  /// - `"above"`: Layer renders above characters (foreground)
  final String? layerClass;

  /// Pre-computed tile data for efficient rendering.
  ///
  /// Only populated for finite maps. For infinite maps, use [chunks].
  List<TileData>? tiles;

  /// Chunks for infinite maps.
  ///
  /// Only populated for infinite maps. For finite maps, use [tiles].
  Map<ChunkKey, TileChunk>? chunks;

  TileLayer({
    required this.name,
    required this.layerIndex,
    required this.tiledLayer,
    this.opacity = 1.0,
    this.visible = true,
    this.offset = Offset.zero,
    this.parallax = const Offset(1.0, 1.0),
    this.tintColor = const Color(0xFFFFFFFF),
    this.layerClass,
    this.tiles,
    this.chunks,
  });

  /// Returns the effective opacity (0-255) as an integer.
  int get opacityByte => (opacity * 255).round().clamp(0, 255);

  /// Returns the combined tint color with layer opacity.
  Color get effectiveColor {
    final alpha = (opacity * tintColor.a * 255).round().clamp(0, 255);
    return Color.fromARGB(alpha, (tintColor.r * 255).round(),
        (tintColor.g * 255).round(), (tintColor.b * 255).round());
  }
}

/// Pre-computed tile data for a single tile.
///
/// This is computed once when the map loads and cached for efficient
/// extraction to the render world.
class TileData {
  /// Global tile ID (with flip flags removed).
  final int gid;

  /// Grid X position.
  final int x;

  /// Grid Y position.
  final int y;

  /// Index of the tileset this tile belongs to.
  final int tilesetIndex;

  /// Local tile ID within the tileset.
  final int localId;

  /// Whether to flip horizontally.
  final bool flipHorizontal;

  /// Whether to flip vertically.
  final bool flipVertical;

  /// Whether to flip diagonally (rotate 90 degrees).
  final bool flipDiagonal;

  /// Whether this tile has an animation.
  final bool animated;

  const TileData({
    required this.gid,
    required this.x,
    required this.y,
    required this.tilesetIndex,
    required this.localId,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.flipDiagonal = false,
    this.animated = false,
  });

  /// Computes flip flags as a packed integer.
  ///
  /// Bit 0: horizontal flip
  /// Bit 1: vertical flip
  /// Bit 2: diagonal flip
  int get flipFlags {
    int flags = 0;
    if (flipHorizontal) flags |= 1;
    if (flipVertical) flags |= 2;
    if (flipDiagonal) flags |= 4;
    return flags;
  }

  /// Creates TileData from a raw GID with flip flags.
  static TileData fromGid(
    int rawGid,
    int x,
    int y,
    int tilesetIndex,
    int firstGid, {
    bool animated = false,
  }) {
    // Extract flip flags from GID (Tiled stores them in the high bits)
    const flipHorizontalFlag = 0x80000000;
    const flipVerticalFlag = 0x40000000;
    const flipDiagonalFlag = 0x20000000;

    final flipH = (rawGid & flipHorizontalFlag) != 0;
    final flipV = (rawGid & flipVerticalFlag) != 0;
    final flipD = (rawGid & flipDiagonalFlag) != 0;

    // Clear flip flags to get actual GID
    final gid = rawGid & 0x1FFFFFFF;
    final localId = gid - firstGid;

    return TileData(
      gid: gid,
      x: x,
      y: y,
      tilesetIndex: tilesetIndex,
      localId: localId,
      flipHorizontal: flipH,
      flipVertical: flipV,
      flipDiagonal: flipD,
      animated: animated,
    );
  }
}

/// Key for identifying chunks in infinite maps.
class ChunkKey {
  /// Chunk X coordinate (in chunks, not tiles).
  final int x;

  /// Chunk Y coordinate (in chunks, not tiles).
  final int y;

  const ChunkKey(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is ChunkKey && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ChunkKey($x, $y)';
}

/// Chunk data for infinite maps.
///
/// Each chunk contains a fixed-size grid of tiles.
class TileChunk {
  /// The chunk's key (position in chunk coordinates).
  final ChunkKey key;

  /// Width of this chunk in tiles.
  final int width;

  /// Height of this chunk in tiles.
  final int height;

  /// Tiles in this chunk.
  final List<TileData> tiles;

  /// World X offset in pixels.
  final double worldX;

  /// World Y offset in pixels.
  final double worldY;

  const TileChunk({
    required this.key,
    required this.width,
    required this.height,
    required this.tiles,
    required this.worldX,
    required this.worldY,
  });
}
