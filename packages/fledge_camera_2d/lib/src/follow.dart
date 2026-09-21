import 'dart:ui' show Offset;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show GlobalTransform2D, Transform2D;

import 'camera2d.dart';

/// Component making a [Camera2D] entity smoothly follow another entity.
///
/// Attach alongside `Camera2D` on the same entity. Each frame,
/// [CameraFollowSystem] lerps the camera's `Transform2D.translation`
/// toward the target's `GlobalTransform2D` position plus [offset],
/// scaled by [smoothing]:
///
/// ```dart
/// camera.translation += (target - camera) * smoothing;
/// ```
///
/// `smoothing = 1.0` teleports (instant). `smoothing = 0.15` gives a
/// smooth, damped follow (roughly 100ms catch-up at 60fps). Values
/// outside `[0, 1]` are clamped.
class CameraFollow {
  /// Entity to follow. If the entity is despawned, the system logs a
  /// warning once and stops updating this camera.
  Entity target;

  /// Damping factor in `[0, 1]`. 1 = instant snap, 0.1 = smooth
  /// catch-up. Higher values feel snappier; lower values feel more
  /// cinematic.
  double smoothing;

  /// Optional world-space offset added to the target's position.
  ///
  /// Useful for offsetting the camera above/below the player, or
  /// looking ahead based on facing direction.
  Offset offset;

  /// Internal: `true` once we've logged the "target despawned"
  /// warning so we don't spam the console.
  bool warnedMissingTarget = false;

  /// Creates a camera-follow component.
  CameraFollow({
    required this.target,
    this.smoothing = 0.15,
    this.offset = Offset.zero,
  });
}

/// System that updates every camera with a [CameraFollow] component.
///
/// Runs in `Schedules.postUpdate` after `TransformPropagateSystem`
/// (which lives in `Schedules.preUpdate`) so it reads fresh target
/// positions. Declares `before: ['CameraShakeSystem']` so shake
/// applies on top of a stable follow-updated camera.
class CameraFollowSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'CameraFollowSystem',
    writes: {ComponentId.of<Transform2D>()},
    reads: {
      ComponentId.of<CameraFollow>(),
      ComponentId.of<Camera2D>(),
      ComponentId.of<GlobalTransform2D>(),
    },
    before: const [
      'CameraShakeSystem',
      'ParallaxSystem',
      'CameraTransitionSystem',
    ],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    for (final (_, follow, _, transform)
        in world.query3<CameraFollow, Camera2D, Transform2D>().iter()) {
      final targetTransform = world.get<GlobalTransform2D>(follow.target);
      if (targetTransform == null) {
        if (!follow.warnedMissingTarget) {
          // ignore: avoid_print
          print(
            '[fledge_camera_2d] CameraFollow.target (${follow.target}) has '
            'no GlobalTransform2D; skipping this camera.',
          );
          follow.warnedMissingTarget = true;
        }
        continue;
      }
      // Reset the warning if the target reappears.
      follow.warnedMissingTarget = false;

      final smoothing = follow.smoothing.clamp(0.0, 1.0);
      final tx = targetTransform.x + follow.offset.dx;
      final ty = targetTransform.y + follow.offset.dy;
      transform.translation.x += (tx - transform.translation.x) * smoothing;
      transform.translation.y += (ty - transform.translation.y) * smoothing;
    }
    return Future.value();
  }
}
