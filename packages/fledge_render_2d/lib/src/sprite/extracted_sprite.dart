import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/extract/draw_layer.dart';
import '../render/extract/extract.dart';
import '../render/extract/extracted_data.dart';
import '../render/world/render_world.dart';
import '../transform/global_transform.dart';
import '../transform/previous_transform.dart';
import '../transform/transform2d.dart';
import 'sprite.dart';

/// Extracted sprite data for the render world.
///
/// This component is created during extraction and contains all the
/// data needed to render a sprite, pre-computed for efficiency.
///
/// Implements [SortableExtractedData] for draw ordering based on [sortKey].
///
/// The [sortKey] is derived from [layer] and a sub-order (Y-position by
/// default, or [layerSubOrder] when non-zero) via
/// [DrawLayerExtension.sortKey]. The sub-order is clamped into the layer's
/// range so a Y-based sub-order cannot bleed into the next layer.
class ExtractedSprite with ExtractedData, SortableExtractedData {
  /// The original entity (for debugging/identification).
  final Entity entity;

  /// The texture to render.
  final TextureHandle texture;

  /// Source rectangle in texture coordinates.
  final Rect sourceRect;

  /// World-space transformation matrix.
  final Matrix3 transform;

  /// Tint color.
  final Color color;

  /// Sort key for draw ordering.
  ///
  /// Computed from [layer] and a sub-order (Y-position by default, or
  /// [layerSubOrder] when non-zero) using [DrawLayerExtension.sortKey].
  @override
  final int sortKey;

  /// Draw layer this sprite belongs to.
  final DrawLayer layer;

  /// Explicit sub-order within [layer], or 0 to use Y-based sub-order.
  final int layerSubOrder;

  /// Flip flags packed as bits.
  final int flipFlags;

  /// Anchor point.
  final Vector2 anchor;

  /// Sprite size.
  final Vector2 size;

  /// Creates extracted sprite data.
  const ExtractedSprite({
    required this.entity,
    required this.texture,
    required this.sourceRect,
    required this.transform,
    required this.color,
    required this.sortKey,
    this.layer = DrawLayer.characters,
    this.layerSubOrder = 0,
    this.flipFlags = 0,
    required this.anchor,
    required this.size,
  });

  /// Whether the sprite is flipped horizontally.
  bool get flipX => (flipFlags & 1) != 0;

  /// Whether the sprite is flipped vertically.
  bool get flipY => (flipFlags & 2) != 0;

  /// Compute flip flags from booleans.
  static int computeFlipFlags(bool flipX, bool flipY) {
    return (flipX ? 1 : 0) | (flipY ? 2 : 0);
  }
}

/// Extractor for sprite components.
///
/// Copies sprite data from the main world to the render world,
/// computing final render data. Entities carrying
/// [PreviousTransform2D] have their translation lerped between the
/// snapshot and the current `Transform2D` by
/// `FixedTimestep.alpha` so 60 Hz simulation stays smooth on higher-
/// refresh displays.
class SpriteExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final alpha = _interpolationAlpha(mainWorld);

    for (final (entity, sprite, globalTransform)
        in mainWorld.query2<Sprite, GlobalTransform2D>().iter()) {
      // Check visibility
      final visibility = mainWorld.get<Visibility>(entity);
      if (visibility != null && !visibility.isVisible) continue;

      // Compute sort key from the sprite's draw layer plus a sub-order.
      // The sub-order defaults to Y-position (top-down painter's algorithm)
      // and is clamped into the layer's range so it can't bleed into the next
      // layer bucket. An explicit `layerSubOrder` overrides the Y-based value.
      final layer = sprite.layer;
      final renderMatrix = interpolatedRenderMatrix(
        mainWorld,
        entity,
        globalTransform,
        alpha,
      );
      final sub = sprite.layerSubOrder != 0
          ? sprite.layerSubOrder
          : (renderMatrix.storage[7] * DrawLayerExtension.ySortScale)
                .toInt()
                .clamp(0, DrawLayerExtension.layerMultiplier - 1);
      final sortKey = layer.sortKey(subOrder: sub);

      renderWorld.spawn().insert(
        ExtractedSprite(
          entity: entity,
          texture: sprite.texture,
          sourceRect: sprite.effectiveSourceRect,
          transform: renderMatrix,
          color: sprite.color,
          sortKey: sortKey,
          layer: layer,
          layerSubOrder: sprite.layerSubOrder,
          flipFlags: ExtractedSprite.computeFlipFlags(
            sprite.flipX,
            sprite.flipY,
          ),
          anchor: sprite.anchor.clone(),
          size: sprite.size,
        ),
      );
    }
  }
}

/// Return `FixedTimestep.alpha` if a `FixedTimestep` resource is
/// installed, otherwise 1.0 (no interpolation).
double _interpolationAlpha(World world) {
  final ft = world.getResource<FixedTimestep>();
  return ft?.alpha ?? 1.0;
}

/// Compute the render-time transform matrix for [entity], applying
/// translation interpolation when the entity carries a
/// [PreviousTransform2D] snapshot. If the entity has no snapshot, or
/// [alpha] is at 1.0, [globalTransform.matrix] is returned unchanged.
///
/// Only translation is interpolated; rotation/scale stays at the
/// current step's values. This matches the common use case (moving
/// player / NPC on a static parent) and avoids the SLERP cost for
/// rotation. The result is a *new* Matrix3 for the interpolated
/// case so mutating it does not affect the source `GlobalTransform2D`.
Matrix3 interpolatedRenderMatrix(
  World world,
  Entity entity,
  GlobalTransform2D globalTransform,
  double alpha,
) {
  if (alpha >= 1.0) return globalTransform.matrix;
  final prev = world.get<PreviousTransform2D>(entity);
  if (prev == null) return globalTransform.matrix;
  final current = world.get<Transform2D>(entity);
  if (current == null) return globalTransform.matrix;

  // Interpolate LOCAL translation. Only correct for root entities;
  // see PreviousTransform2D's docstring.
  final ix =
      prev.translation.x + (current.translation.x - prev.translation.x) * alpha;
  final iy =
      prev.translation.y + (current.translation.y - prev.translation.y) * alpha;

  // Rebuild the matrix from the current rotation/scale + interpolated
  // translation. Cheaper than cloning and rewriting the storage.
  final result = globalTransform.matrix.clone();
  result.storage[6] = ix;
  result.storage[7] = iy;
  return result;
}
