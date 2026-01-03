import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:vector_math/vector_math.dart';

import '../transform/global_transform.dart';
import 'sprite.dart';

/// Extracted sprite data for the render world.
///
/// This component is created during extraction and contains all the
/// data needed to render a sprite, pre-computed for efficiency.
///
/// Implements [SortableExtractedData] for draw ordering based on [sortKey].
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

  /// Sort key for draw ordering (typically Y position or layer).
  @override
  final int sortKey;

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
    for (final (entity, sprite, globalTransform) in
        mainWorld.query2<Sprite, GlobalTransform2D>().iter()) {
      // Check visibility
      final visibility = mainWorld.get<Visibility>(entity);
      if (visibility != null && !visibility.isVisible) continue;

      // Compute sort key (Y position for typical 2D sorting)
      final sortKey = (globalTransform.y * 1000).toInt();

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity,
            texture: sprite.texture,
            sourceRect: sprite.effectiveSourceRect,
            transform: globalTransform.matrix,
            color: sprite.color,
            sortKey: sortKey,
            flipFlags:
                ExtractedSprite.computeFlipFlags(sprite.flipX, sprite.flipY),
            anchor: sprite.anchor.clone(),
            size: sprite.size,
          ));
    }
  }
}
