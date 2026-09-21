import 'dart:ui' show Offset;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show GlobalTransform2D, PreviousTransform2D, Transform2D;

import 'camera2d.dart';
import 'pixel_perfect.dart';

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
/// Runs in `Schedules.postUpdate`. Declares `after:
/// ['transform_propagate']` so it reads a fresh
/// `GlobalTransform2D` on the follow target — otherwise a target
/// entity that moved earlier in the same tick would still expose
/// the previous frame's global position and the camera would lag.
///
/// Games that need the camera's new position to feed further
/// world-space computations in the same frame (a second sprite
/// pass, a debug overlay drawn in world space, ...) should
/// re-run `TransformPropagateSystem` after this system so the
/// camera's own `GlobalTransform2D` is fresh. Otherwise the follow
/// output is visible next frame, one tick late.
///
/// Also declares `before: ['CameraShakeSystem']` so shake applies
/// on top of a stable follow-updated camera.
///
/// When `Camera2D.pixelPerfect` is set on the followed camera, the
/// system snaps the resulting `Transform2D.translation` to whole
/// pixels so pixel-art tiles don't develop seams from sub-pixel
/// camera positions.
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
    after: const ['transform_propagate'],
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
    final ft = world.getResource<FixedTimestep>();
    final alpha = ft?.alpha ?? 1.0;

    for (final (_, follow, camera, transform)
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

      // If the target opted into render interpolation, follow the
      // interpolated position instead of the raw current one. Keeps
      // the camera-follow feel smooth on displays running faster than
      // the physics fixed step.
      double tx = targetTransform.x + follow.offset.dx;
      double ty = targetTransform.y + follow.offset.dy;
      if (alpha < 1.0) {
        final prev = world.get<PreviousTransform2D>(follow.target);
        final cur = world.get<Transform2D>(follow.target);
        if (prev != null && cur != null) {
          final ix =
              prev.translation.x +
              (cur.translation.x - prev.translation.x) * alpha;
          final iy =
              prev.translation.y +
              (cur.translation.y - prev.translation.y) * alpha;
          tx = ix + follow.offset.dx;
          ty = iy + follow.offset.dy;
        }
      }

      final smoothing = follow.smoothing.clamp(0.0, 1.0);
      transform.translation.x += (tx - transform.translation.x) * smoothing;
      transform.translation.y += (ty - transform.translation.y) * smoothing;

      // Pixel-perfect camera: snap the follow output to whole pixels
      // so pixel-art tiles don't develop seams from sub-pixel camera
      // positions. Only applies when the camera opted in; games that
      // want a smooth non-integer camera keep pixelPerfect=false.
      if (camera.pixelPerfect) {
        transform.translation.x = snapToPixel(transform.translation.x);
        transform.translation.y = snapToPixel(transform.translation.y);
      }
    }
    return Future.value();
  }
}
