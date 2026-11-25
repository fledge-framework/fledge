import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:vector_math/vector_math.dart';

import '../render/extract/draw_layer.dart';
import '../sprite/culled_sprite_extractor.dart';
import '../sprite/extracted_sprite.dart';
import 'texture_atlas.dart';

/// Extractor for atlas sprite components.
///
/// Extracts [AtlasSprite] components to the render world as [ExtractedSprite].
/// Works with [AnimationPlayer] to animate sprites.
///
/// Behaves exactly like `SpriteExtractor`: sprites further than
/// [cullMargin] world units outside the camera's last view
/// (`ActiveCameraView.visibleWorldRect`) are skipped (nothing is culled
/// without a view), `StaticTransform` scenery is looked up through a
/// spatial grid, hidden (`Visibility`) and fully transparent sprites are
/// skipped, `PreviousTransform2D` translation is interpolated by
/// `FixedTimestep.alpha`, and [AtlasSprite.emissive] is carried through so
/// the sprite draws after the view passes.
class AtlasSpriteExtractor extends CulledSpriteExtractor<AtlasSprite> {
  /// World units beyond the camera's last view that are still extracted.
  static const double cullMargin = CulledSpriteExtractor.cullMargin;

  @override
  Vector2 sizeOf(AtlasSprite component) {
    final rect = component.sourceRect;
    return Vector2(rect.width, rect.height);
  }

  @override
  Color colorOf(AtlasSprite component) => component.color;

  @override
  DrawLayer layerOf(AtlasSprite component) => component.layer;

  @override
  int layerSubOrderOf(AtlasSprite component) => component.layerSubOrder;

  @override
  ExtractedSprite build(
    AtlasSprite component, {
    required Entity entity,
    required Matrix3 transform,
    required Vector2 size,
    required int sortKey,
    required double? preciseSubOrder,
  }) => ExtractedSprite(
    entity: entity,
    texture: component.texture,
    sourceRect: component.sourceRect,
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
