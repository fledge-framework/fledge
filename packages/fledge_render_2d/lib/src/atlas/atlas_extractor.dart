import 'dart:ui' show Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/extract/draw_layer.dart';
import '../render/extract/extract.dart';
import '../render/world/render_world.dart';
import '../sprite/extracted_sprite.dart';
import '../sprite/sprite.dart';
import '../transform/global_transform.dart';
import 'texture_atlas.dart';

/// Extractor for atlas sprite components.
///
/// Extracts [AtlasSprite] components to the render world as [ExtractedSprite].
/// Works with [AnimationPlayer] to animate sprites.
class AtlasSpriteExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, atlasSprite, globalTransform)
        in mainWorld.query2<AtlasSprite, GlobalTransform2D>().iter()) {
      // Check visibility
      final visibility = mainWorld.get<Visibility>(entity);
      if (visibility != null && !visibility.isVisible) continue;

      // Get the source rect for current sprite index
      final sourceRect = atlasSprite.sourceRect;

      // Compute sort key: explicit layerSubOrder wins; otherwise derive
      // from y-position, clamped inside the layer's range.
      final sub = atlasSprite.layerSubOrder != 0
          ? atlasSprite.layerSubOrder
          : (globalTransform.y * 1000).toInt().clamp(
              0,
              DrawLayerExtension.layerMultiplier - 1,
            );
      final sortKey = atlasSprite.layer.sortKey(subOrder: sub);

      renderWorld.spawn().insert(
        ExtractedSprite(
          entity: entity,
          texture: atlasSprite.texture,
          sourceRect: sourceRect,
          transform: globalTransform.matrix,
          color: atlasSprite.color,
          sortKey: sortKey,
          layer: atlasSprite.layer,
          layerSubOrder: atlasSprite.layerSubOrder,
          flipFlags: ExtractedSprite.computeFlipFlags(
            atlasSprite.flipX,
            atlasSprite.flipY,
          ),
          anchor: _centerAnchor.clone(),
          size: _sizeFromRect(sourceRect),
        ),
      );
    }
  }

  static final _centerAnchor = Vector2(0.5, 0.5);

  static Vector2 _sizeFromRect(Rect rect) {
    return Vector2(rect.width, rect.height);
  }
}
