import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:vector_math/vector_math.dart';

/// Minimal fledge_lighting_2d example.
///
/// [LightingPlugin] registers the [LightExtractor] on top of
/// [RenderPlugin]'s render pipeline and inserts an [AmbientLight]
/// resource. Attach a [Light2D] alongside `Transform2D` +
/// `GlobalTransform2D` and the extractor emits an `ExtractedLight`
/// each frame — the additive light pass then runs inside
/// [LitFledgeRenderView].
void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const LightingPlugin(ambient: AmbientLight.dark));

  // A torch: warm point light with a soft falloff from 40..180 units.
  app.world.spawn()
    ..insert(Transform2D.from(200, 200))
    ..insert(GlobalTransform2D.identity())
    ..insert(
      Light2D.point(
        color: const Color(0xFFFFDD88),
        radius: 180,
        innerRadius: 40,
      ),
    );

  // A directional moon tint — parallel rays across the whole viewport.
  app.world.spawn()
    ..insert(Transform2D.identity())
    ..insert(GlobalTransform2D.identity())
    ..insert(
      Light2D.directional(
        color: const Color(0x3040507A),
        direction: Vector2(1, 1),
      ),
    );

  await app.tick();
}
