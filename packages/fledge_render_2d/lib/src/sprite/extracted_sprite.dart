import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/extract/draw_layer.dart';
import '../render/extract/extract.dart';
import '../render/extract/extracted_data.dart';
import '../render/world/render_world.dart';
import '../transform/global_transform.dart';
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
/// computing final render data.
class SpriteExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
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
      final sub = sprite.layerSubOrder != 0
          ? sprite.layerSubOrder
          : (globalTransform.y * 1000)
              .toInt()
              .clamp(0, DrawLayerExtension.layerMultiplier - 1);
      final sortKey = layer.sortKey(subOrder: sub);

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity,
            texture: sprite.texture,
            sourceRect: sprite.effectiveSourceRect,
            transform: globalTransform.matrix,
            color: sprite.color,
            sortKey: sortKey,
            layer: layer,
            layerSubOrder: sprite.layerSubOrder,
            flipFlags:
                ExtractedSprite.computeFlipFlags(sprite.flipX, sprite.flipY),
            anchor: sprite.anchor.clone(),
            size: sprite.size,
          ));
    }
  }
}
