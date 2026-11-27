import 'package:fledge_ecs/fledge_ecs.dart';

import 'dart:ui' show Offset, Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart'
    show
        ActiveCameraView,
        Extractor,
        SpriteExtractor,
        GlobalTransform2D,
        RenderWorld;
import 'package:vector_math/vector_math.dart';

import 'extracted_light.dart';
import 'light2d.dart';

/// Copies every `Light2D + GlobalTransform2D` pair near the view from the
/// main world into an [ExtractedLight] on the render world.
///
/// Culled like sprites: a point or spot light whose pool (its radius, its
/// height scaled by `aspect`) misses the camera's last view, widened by
/// [SpriteExtractor.cullMargin], is skipped. Directional lights are always
/// extracted, and so is everything before the first paint (no view yet).
///
/// Mirrors `SpriteExtractor`'s shape: registered on the shared
/// `Extractors` registry (see [LightingPlugin]) so it runs during the
/// existing extract pass — no new scheduler wiring required.
class LightExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final visible = mainWorld
        .getResource<ActiveCameraView>()
        ?.visibleWorldRect
        ?.inflate(SpriteExtractor.cullMargin);
    for (final (entity, light, globalTransform)
        in mainWorld.query2<Light2D, GlobalTransform2D>().iter()) {
      if (visible != null && light.type != LightType.directional) {
        final reach = light.radius.abs();
        final pool = Rect.fromCenter(
          center: Offset(globalTransform.x, globalTransform.y),
          width: reach * 2,
          height: reach * 2 * light.aspect.abs(),
        );
        if (!pool.overlaps(visible)) continue;
      }
      renderWorld.add(
        ExtractedLight(
          entity: entity,
          type: light.type,
          position: Vector2(globalTransform.x, globalTransform.y),
          color: light.color,
          intensity: light.intensity,
          radius: light.radius,
          innerRadius: light.innerRadius,
          bands: light.bands,
          aspect: light.aspect,
          glow: light.glow,
          angle: light.angle,
          direction: light.direction.clone(),
          castsShadow: light.castsShadow,
        ),
      );
    }
  }
}
