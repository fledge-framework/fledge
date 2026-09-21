import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show Extractor, GlobalTransform2D, RenderWorld;
import 'package:vector_math/vector_math.dart';

import 'extracted_light.dart';
import 'light2d.dart';

/// Copies every `Light2D + GlobalTransform2D` pair from the main world
/// into an [ExtractedLight] on the render world.
///
/// Mirrors `SpriteExtractor`'s shape: registered on the shared
/// `Extractors` registry (see [LightingPlugin]) so it runs during the
/// existing extract pass — no new scheduler wiring required.
class LightExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    for (final (entity, light, globalTransform)
        in mainWorld.query2<Light2D, GlobalTransform2D>().iter()) {
      renderWorld.spawn().insert(ExtractedLight(
            entity: entity,
            type: light.type,
            position: Vector2(globalTransform.x, globalTransform.y),
            color: light.color,
            intensity: light.intensity,
            radius: light.radius,
            innerRadius: light.innerRadius,
            angle: light.angle,
            direction: light.direction.clone(),
            castsShadow: light.castsShadow,
          ));
    }
  }
}
