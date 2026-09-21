import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show GlobalTransform2D, Transform2D;

import 'camera2d.dart';

/// Parallax multiplier for a background/foreground entity.
///
/// [factor] is a scalar in `[0, 1]`:
/// - `1.0` — foreground; entity moves 1:1 with the world (default
///   behaviour, i.e. no parallax).
/// - `0.5` — mid-ground; entity moves at half the camera speed.
/// - `0.0` — infinitely far; entity never moves relative to the
///   viewport.
///
/// The [ParallaxSystem] queries every entity with `Parallax +
/// Transform2D + GlobalTransform2D` and rewrites their
/// `GlobalTransform2D.translation` to:
///
/// ```
/// effective = transform.translation + (1 - factor) * cameraPosition
/// ```
///
/// This works only for **root** entities (no parent). Nested
/// parallax hierarchies aren't a common need for 2D games; support
/// can be added later if a real use case appears.
class Parallax {
  /// Speed multiplier vs. the camera. `1.0` disables parallax;
  /// `0.0` locks to the viewport; values in between scroll slower.
  final double factor;

  /// Creates a parallax component.
  const Parallax(this.factor);
}

/// System that adjusts `GlobalTransform2D` of parallax entities based
/// on the active camera position.
///
/// Runs in `Schedules.postUpdate` **after** [CameraShakeSystem] so
/// parallax reads the final camera position (follow + shake baked in).
class ParallaxSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'ParallaxSystem',
        writes: {ComponentId.of<GlobalTransform2D>()},
        reads: {
          ComponentId.of<Parallax>(),
          ComponentId.of<Transform2D>(),
          ComponentId.of<Camera2D>(),
        },
        after: const ['CameraFollowSystem', 'CameraShakeSystem'],
        before: const ['CameraTransitionSystem'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    // Find the active camera with the lowest order — this matches
    // CameraDriverNode's selection.
    double camX = 0;
    double camY = 0;
    var found = false;
    var bestOrder = double.maxFinite.toInt();
    for (final (_, camera, cameraTransform)
        in world.query2<Camera2D, Transform2D>().iter()) {
      if (!camera.isActive) continue;
      if (camera.order < bestOrder) {
        bestOrder = camera.order;
        camX = cameraTransform.translation.x;
        camY = cameraTransform.translation.y;
        found = true;
      }
    }
    if (!found) return Future.value();

    for (final (_, parallax, transform, global)
        in world.query3<Parallax, Transform2D, GlobalTransform2D>().iter()) {
      final k = 1.0 - parallax.factor;
      global.matrix[6] = transform.translation.x + camX * k;
      global.matrix[7] = transform.translation.y + camY * k;
    }
    return Future.value();
  }
}
