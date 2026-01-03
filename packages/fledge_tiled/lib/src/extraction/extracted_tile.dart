import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_render/fledge_render.dart'
    show ExtractedData, SortableExtractedData;
import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;

/// Extracted tile data for the render world.
///
/// Created by [TilemapExtractor] from [TileLayer] components.
/// Batched by tileset texture for efficient rendering.
///
/// Implements [SortableExtractedData] for draw ordering based on [sortKey].
class ExtractedTile with ExtractedData, SortableExtractedData {
  /// The tileset texture.
  final TextureHandle texture;

  /// Source rectangle in the tileset.
  final Rect sourceRect;

  /// Destination position in world space.
  final Offset position;

  /// Tile size in pixels.
  final double tileWidth;
  final double tileHeight;

  /// Tint color (from layer opacity/tint).
  final Color color;

  /// Sort key (layer index * 10000 + Y position).
  @override
  final int sortKey;

  /// Flip flags (bit 0: horizontal, bit 1: vertical, bit 2: diagonal).
  final int flipFlags;

  const ExtractedTile({
    required this.texture,
    required this.sourceRect,
    required this.position,
    required this.tileWidth,
    required this.tileHeight,
    required this.color,
    required this.sortKey,
    this.flipFlags = 0,
  });

  /// Whether the tile is flipped horizontally.
  bool get flipHorizontal => (flipFlags & 1) != 0;

  /// Whether the tile is flipped vertically.
  bool get flipVertical => (flipFlags & 2) != 0;

  /// Whether the tile is flipped diagonally (90 degree rotation).
  bool get flipDiagonal => (flipFlags & 4) != 0;

  /// Computes flip flags from booleans.
  static int computeFlipFlags({
    bool horizontal = false,
    bool vertical = false,
    bool diagonal = false,
  }) {
    int flags = 0;
    if (horizontal) flags |= 1;
    if (vertical) flags |= 2;
    if (diagonal) flags |= 4;
    return flags;
  }

  /// Returns the destination rectangle for this tile.
  Rect get destRect => Rect.fromLTWH(
        position.dx,
        position.dy,
        tileWidth,
        tileHeight,
      );
}
