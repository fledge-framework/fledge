import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show DrawLayer, DrawLayerExtension, ExtractedSprite, TextureHandle;
import 'package:vector_math/vector_math.dart' show Matrix3, Vector2;

/// Bit flag layout used by fledge_tiled for flipped/rotated tiles.
///
/// Matches Tiled's TMX encoding: horizontal (bit 0), vertical (bit 1),
/// diagonal (bit 2). Diagonal alone is a 90° rotation *and* a mirror;
/// combined with H or V it's a pure 90° / -90° rotation.
class TileFlipFlags {
  static const int horizontal = 1;
  static const int vertical = 2;
  static const int diagonal = 4;
}

/// Packed sub-order stride per tile row: `row * tileRowStride +
/// layerIndex`. Tile layer indices 0..99 sort correctly within a row.
const int tileRowStride = 100;

/// Integer draw-order key for a tile at grid [row] on Tiled layer
/// [layerIndex], in [drawLayer] (`DrawLayer.ground`, or
/// `DrawLayer.foreground` for `class="above"` layers).
///
/// The sub-order is `row * tileRowStride + layerIndex` (row first, then
/// layer index), **clamped** into `0..DrawLayerExtension.layerMultiplier
/// - 1` so it can never spill into the next [DrawLayer]'s range. Rows
/// 0..999 get distinct keys exactly as before; from row 1,000 on the
/// keys saturate at the top of the layer range and the draw order comes
/// from [tilePreciseSubOrder], carried as
/// `ExtractedSprite.preciseSubOrder` / `ExtractedTile.preciseSubOrder`.
int tileSortKey({
  required DrawLayer drawLayer,
  required int row,
  required int layerIndex,
}) => drawLayer.sortKey(
  subOrder: (row * tileRowStride + layerIndex).clamp(
    0,
    DrawLayerExtension.layerMultiplier - 1,
  ),
);

/// Unclamped tie-breaking sub-order for a tile at grid [row] on Tiled
/// layer [layerIndex]: `row * tileRowStride + layerIndex`, in the same
/// units as the sub-order packed into [tileSortKey].
///
/// `ExtractedSprite.compareDrawOrder` only consults it when the integer
/// sort keys tie (i.e. for rows >= 1,000 where [tileSortKey] clamps),
/// so tiles of any map size sort by row, then layer index, and never
/// leave their [DrawLayer].
double tilePreciseSubOrder({required int row, required int layerIndex}) =>
    row * tileRowStride.toDouble() + layerIndex;

/// Convert a single tile's data into an [ExtractedSprite] suitable for
/// the shared render-widget pipeline (`FledgeRenderView` /
/// `LitFledgeRenderView`).
///
/// - The sprite is anchored at (0.5, 0.5) with the tile's world
///   position placed at the tile's centre.
/// - Flip flags become a rotation about the centre when they encode
///   one of the four cardinal orientations (0°, 90° cw, 180°, 90° ccw).
///   Pure mirrors (H alone, V alone, D alone, H+V+D) cannot be
///   expressed by `RSTransform` and are drawn unflipped.
///
/// [preciseSubOrder] becomes `ExtractedSprite.preciseSubOrder`: the
/// unclamped tie-breaker for equal [sortKey]s (see
/// [tilePreciseSubOrder]). `null` (the default) falls back to the
/// sub-order packed into [sortKey].
///
/// Kept as a top-level helper so both `TilemapExtractor` and
/// `CulledTilemapExtractor` share the same conversion.
ExtractedSprite tileToSprite({
  required TextureHandle texture,
  required Rect sourceRect,
  required Offset tileTopLeft,
  required double tileWidth,
  required double tileHeight,
  required Color color,
  required int sortKey,
  required int flipFlags,
  double? preciseSubOrder,
}) {
  final centerX = tileTopLeft.dx + tileWidth / 2;
  final centerY = tileTopLeft.dy + tileHeight / 2;

  final rotation = _flipsToRotation(flipFlags) ?? 0.0;
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  // Column-major 3x3 affine: [a, b, 0, c, d, 0, tx, ty, 1].
  final transform = Matrix3(cos, sin, 0, -sin, cos, 0, centerX, centerY, 1);

  final layer =
      DrawLayer.values[(sortKey ~/ DrawLayerExtension.layerMultiplier).clamp(
        0,
        DrawLayer.values.length - 1,
      )];

  return ExtractedSprite(
    entity: Entity.placeholder,
    texture: texture,
    sourceRect: sourceRect,
    transform: transform,
    color: color,
    sortKey: sortKey,
    layer: layer,
    layerSubOrder: sortKey % DrawLayerExtension.layerMultiplier,
    preciseSubOrder: preciseSubOrder,
    anchor: Vector2(0.5, 0.5),
    size: Vector2(tileWidth, tileHeight),
  );
}

/// Return the rotation (radians, clockwise) that maps a tile's flip
/// flags to a pure rotation, or `null` if the flags encode a mirror
/// that `RSTransform` cannot express.
///
/// Tiled encoding:
/// - none        → 0
/// - H + V       → π (180°)
/// - D + H       → π/2 (90° cw)
/// - D + V       → -π/2 (90° ccw)
///
/// H alone, V alone, D alone, and H+V+D are mirrors and return null.
double? _flipsToRotation(int flags) {
  final h = (flags & TileFlipFlags.horizontal) != 0;
  final v = (flags & TileFlipFlags.vertical) != 0;
  final d = (flags & TileFlipFlags.diagonal) != 0;
  if (!d) {
    if (h == v) return h ? math.pi : 0;
    return null; // H alone or V alone.
  }
  // d == true
  if (h != v) return h ? math.pi / 2 : -math.pi / 2;
  return null; // D alone or H+V+D.
}
