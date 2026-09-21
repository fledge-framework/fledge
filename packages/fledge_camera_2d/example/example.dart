import 'dart:ui';

import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:vector_math/vector_math.dart';

/// End-to-end example: a sprite followed by a camera with shake.
void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin());

  // Spawn a player.
  final player = app.world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(GlobalTransform2D())
    ..insert(
      Sprite(
        texture: const TextureHandle(id: 0, width: 32, height: 32),
        color: const Color(0xFF00FF00),
        customSize: Vector2(32, 32),
      ),
    );

  // Spawn a camera that follows the player.
  app.world.spawn()
    ..insert(Transform2D.from(0, 0))
    ..insert(GlobalTransform2D())
    ..insert(
      Camera2D(
        projection: OrthographicProjection(viewportHeight: 600),
        pixelPerfect: true,
      ),
    )
    ..insert(CameraFollow(target: player.entity, smoothing: 0.15))
    ..insert(CameraShake());

  // Trigger a screen shake.
  app.world.query1<CameraShake>().iter().first.$2.addTrauma(0.6);

  // Add propagation before the camera systems.
  app.addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

  app.tick();
}
