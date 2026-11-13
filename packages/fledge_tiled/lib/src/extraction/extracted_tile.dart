import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart'
    show
        DrawLayerExtension,
        ExtractedData,
        SortableExtractedData,
        TextureHandle;

/// Extracted tile data for the render world.
///
/// **Deprecated as of v0.3**: `TilemapExtractor` and
/// `CulledTilemapExtractor` now emit `ExtractedSprite` directly (via
/// `tileToSprite`) so the shared render-widget pipeline
/// (`FledgeRenderView` / `LitFledgeRenderView`) can draw tiles
/// without a separate consumer. The class is kept as a public shape
/// only so downstream code that still references it compiles; new
/// consumers should read `ExtractedSprite` from the render world.
///
/// Implements [SortableExtractedData] for draw ordering based on [sortKey].
@Deprecated(
  'Tiled extractors now emit ExtractedSprite directly. Read '
  'ExtractedSprite from the render world instead of ExtractedTile.',
)
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

  /// Sort key for draw ordering.
  ///
  /// `DrawLayer.ground` (or `DrawLayer.foreground` for `class="above"`
  /// layers) plus the sub-order `row * 100 + layerIndex`, clamped into
  /// the layer's range (see `tileSortKey`). From tile row 1,000 on the
  /// key saturates; order by [compareDrawOrder] to break those ties
  /// with [preciseSubOrder].
  @override
  final int sortKey;

  /// Unclamped tie-breaking sub-order (`row * 100 + layerIndex`, see
  /// `tilePreciseSubOrder`), or `null` to fall back to the sub-order
  /// packed into [sortKey]. Only consulted when [sortKey]s tie, so it
  /// never moves a tile across draw layers.
  final double? preciseSubOrder;

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
    this.preciseSubOrder,
  });

  /// Draw-order comparator: [sortKey] first, then [preciseSubOrder]
  /// (or the packed sub-order when that is `null`). Mirrors
  /// `ExtractedSprite.compareDrawOrder`; any two tiles whose sort keys
  /// differ order exactly as with [sortKey] alone.
  static int compareDrawOrder(ExtractedTile a, ExtractedTile b) {
    final byKey = a.sortKey.compareTo(b.sortKey);
    if (byKey != 0) return byKey;
    return a._effectiveSubOrder.compareTo(b._effectiveSubOrder);
  }

  double get _effectiveSubOrder =>
      preciseSubOrder ??
      (sortKey % DrawLayerExtension.layerMultiplier).toDouble();

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
  Rect get destRect =>
      Rect.fromLTWH(position.dx, position.dy, tileWidth, tileHeight);
}
