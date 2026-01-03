import 'dart:ui' show Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart';
import 'package:vector_math/vector_math.dart';

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
    for (final (entity, atlasSprite, globalTransform) in
        mainWorld.query2<AtlasSprite, GlobalTransform2D>().iter()) {
      // Check visibility
      final visibility = mainWorld.get<Visibility>(entity);
      if (visibility != null && !visibility.isVisible) continue;

      // Get the source rect for current sprite index
      final sourceRect = atlasSprite.sourceRect;

      // Compute sort key (Y position for typical 2D sorting)
      final sortKey = (globalTransform.y * 1000).toInt();

      renderWorld.spawn().insert(ExtractedSprite(
            entity: entity,
            texture: atlasSprite.texture,
            sourceRect: sourceRect,
            transform: globalTransform.matrix,
            color: atlasSprite.color,
            sortKey: sortKey,
            flipFlags: ExtractedSprite.computeFlipFlags(
              atlasSprite.flipX,
              atlasSprite.flipY,
            ),
            anchor: _centerAnchor.clone(),
            size: _sizeFromRect(sourceRect),
          ));
    }
  }

  static final _centerAnchor = Vector2(0.5, 0.5);

  static Vector2 _sizeFromRect(Rect rect) {
    return Vector2(rect.width, rect.height);
  }
}
