import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/extract/draw_layer.dart';
import '../render/extract/extracted_data.dart';
import '../transform/global_transform.dart';
import '../transform/previous_transform.dart';
import '../transform/transform2d.dart';
import 'culled_sprite_extractor.dart';
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
///
/// Because that clamp only leaves room for y = 0..9,999.9, draw order is
/// the composite `(sortKey, preciseSubOrder)`: see [compareDrawOrder]
/// and [sortByDrawOrder], which every framework sprite path uses.
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

  /// Unclamped, full-precision sub-order used to break ties between
  /// sprites with an equal [sortKey], or `null` to fall back to the
  /// sub-order packed into [sortKey] (`sortKey % layerMultiplier`).
  ///
  /// Uses the same units as the packed sub-order. Y-sorted extractors
  /// set it to `y * DrawLayerExtension.ySortScale` (no clamp, no
  /// truncation), so sprites outside the integer key's 0..9,999.9 Y
  /// window, or closer than 0.1 px apart, still order by position.
  /// Never consulted when the [sortKey]s differ, so it cannot move a
  /// sprite across layers.
  final double? preciseSubOrder;

  /// Flip flags packed as bits.
  final int flipFlags;

  /// Anchor point.
  final Vector2 anchor;

  /// Sprite size.
  final Vector2 size;

  /// Whether it's drawn after the view passes, at full brightness
  /// (`Sprite.emissive`).
  final bool emissive;

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
    this.preciseSubOrder,
    this.flipFlags = 0,
    required this.anchor,
    required this.size,
    this.emissive = false,
  });

  /// Whether the sprite is flipped horizontally.
  bool get flipX => (flipFlags & 1) != 0;

  /// Whether the sprite is flipped vertically.
  bool get flipY => (flipFlags & 2) != 0;

  /// Compute flip flags from booleans.
  static int computeFlipFlags(bool flipX, bool flipY) {
    return (flipX ? 1 : 0) | (flipY ? 2 : 0);
  }

  /// The tie-breaking sub-order: [preciseSubOrder], or the sub-order
  /// packed into [sortKey] when that is `null`.
  double get effectiveSubOrder =>
      preciseSubOrder ??
      (sortKey % DrawLayerExtension.layerMultiplier).toDouble();

  /// Draw-order comparator: [sortKey] first, then [effectiveSubOrder].
  ///
  /// A strict refinement of comparing [sortKey] alone: any two sprites
  /// whose keys differ order exactly as before, so layers always
  /// dominate. Only sprites whose integer keys tie (e.g. two Y-sorted
  /// sprites both clamped at y > 9,999.9 or y < 0) are separated by
  /// their precise sub-order. Returns 0 for a full tie; use
  /// [sortByDrawOrder] for a stable sort.
  static int compareDrawOrder(ExtractedSprite a, ExtractedSprite b) {
    final byKey = a.sortKey.compareTo(b.sortKey);
    if (byKey != 0) return byKey;
    return a.effectiveSubOrder.compareTo(b.effectiveSubOrder);
  }

  /// Sort [sprites] in place into draw order ([compareDrawOrder]).
  ///
  /// Stable: sprites with an identical composite key keep their
  /// relative order (render-world extraction order), so equal-key
  /// sprites don't swap from frame to frame.
  static void sortByDrawOrder(List<ExtractedSprite> sprites) {
    final n = sprites.length;
    if (n < 2) return;
    final copy = List<ExtractedSprite>.of(sprites);
    final order = List<int>.generate(n, (i) => i);
    order.sort((i, j) {
      final c = compareDrawOrder(copy[i], copy[j]);
      return c != 0 ? c : i.compareTo(j);
    });
    for (var i = 0; i < n; i++) {
      sprites[i] = copy[order[i]];
    }
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
///
/// Sprites further than [cullMargin] world units outside the camera's
/// last view (`ActiveCameraView.visibleWorldRect`) are skipped; with no
/// view (headless, before the first paint) nothing is. `StaticTransform`
/// scenery is kept in a spatial grid so only the cells near the view are
/// visited. `AtlasSpriteExtractor` does all of this the same way.
class SpriteExtractor extends CulledSpriteExtractor<Sprite> {
  /// World units beyond the camera's last view that are still extracted.
  static const double cullMargin = CulledSpriteExtractor.cullMargin;

  @override
  Vector2 sizeOf(Sprite component) => component.size;

  @override
  Color colorOf(Sprite component) => component.color;

  @override
  DrawLayer layerOf(Sprite component) => component.layer;

  @override
  int layerSubOrderOf(Sprite component) => component.layerSubOrder;

  @override
  ExtractedSprite build(
    Sprite component, {
    required Entity entity,
    required Matrix3 transform,
    required Vector2 size,
    required int sortKey,
    required double? preciseSubOrder,
  }) => ExtractedSprite(
    entity: entity,
    texture: component.texture,
    sourceRect: component.effectiveSourceRect,
    transform: transform,
    color: component.color,
    sortKey: sortKey,
    layer: component.layer,
    layerSubOrder: component.layerSubOrder,
    preciseSubOrder: preciseSubOrder,
    flipFlags: ExtractedSprite.computeFlipFlags(
      component.flipX,
      component.flipY,
    ),
    anchor: component.anchor.clone(),
    size: size,
    emissive: component.emissive,
  );
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
