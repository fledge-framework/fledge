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
}) {
  final centerX = tileTopLeft.dx + tileWidth / 2;
  final centerY = tileTopLeft.dy + tileHeight / 2;

  final rotation = _flipsToRotation(flipFlags) ?? 0.0;
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  // Column-major 3x3 affine: [a, b, 0, c, d, 0, tx, ty, 1].
  final transform = Matrix3(
    cos, sin, 0,
    -sin, cos, 0,
    centerX, centerY, 1,
  );

  final layer = DrawLayer.values[
      (sortKey ~/ DrawLayerExtension.layerMultiplier)
          .clamp(0, DrawLayer.values.length - 1)];

  return ExtractedSprite(
    entity: Entity.placeholder,
    texture: texture,
    sourceRect: sourceRect,
    transform: transform,
    color: color,
    sortKey: sortKey,
    layer: layer,
    layerSubOrder: sortKey % DrawLayerExtension.layerMultiplier,
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
