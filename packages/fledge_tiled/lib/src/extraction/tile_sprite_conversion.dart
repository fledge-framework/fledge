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
/// - Flip flags become a rotation about the centre, plus a horizontal
///   mirror (`ExtractedSprite.flipX`, applied in the tile's own space)
///   for the four combinations that mirror (H alone, V alone, D alone,
///   H+V+D), so all eight of Tiled's orientations draw as in Tiled.
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

  final (:rotation, :mirror) = _flipsToOrientation(flipFlags);
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
    flipFlags: ExtractedSprite.computeFlipFlags(mirror, false),
    anchor: Vector2(0.5, 0.5),
    size: Vector2(tileWidth, tileHeight),
  );
}

/// The rotation (radians, clockwise) and whether to mirror the tile
/// horizontally first, for a tile's Tiled flip flags.
///
/// Tiled applies D (swap x and y) first, then H (negate x), then V
/// (negate y). That linear map is written as a rotation after an optional
/// horizontal mirror: a mirror exactly when the map's determinant is
/// negative (H alone, V alone, D alone, H+V+D).
({double rotation, bool mirror}) _flipsToOrientation(int flags) {
  final h = (flags & TileFlipFlags.horizontal) != 0;
  final v = (flags & TileFlipFlags.vertical) != 0;
  final d = (flags & TileFlipFlags.diagonal) != 0;
  // Columns of the map: where the x and y axes go.
  var (ax, ay, bx, by) = d ? (0, 1, 1, 0) : (1, 0, 0, 1);
  if (h) (ax, bx) = (-ax, -bx);
  if (v) (ay, by) = (-ay, -by);
  final mirror = ax * by - bx * ay < 0;
  // Undo the mirror (negate the x column) to leave a pure rotation.
  if (mirror) (ax, ay) = (-ax, -ay);
  return (rotation: math.atan2(ay.toDouble(), ax.toDouble()), mirror: mirror);
}
