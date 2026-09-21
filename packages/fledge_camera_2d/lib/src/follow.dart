import 'dart:ui' show Offset;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show GlobalTransform2D, PreviousTransform2D, Transform2D;

import 'camera2d.dart';
import 'pixel_perfect.dart';

/// Marker component that identifies the current camera-follow target.
///
/// Attach to any entity (typically the player) instead of hard-wiring
/// a specific `Entity` handle into [CameraFollow]. The follow system
/// picks the first entity carrying this marker each frame, so games
/// can spawn the camera before the player exists, hand off between
/// possessable characters, or point at the boss during a cutscene
/// just by moving the marker around.
///
/// Used only when [CameraFollow.target] is [Entity.placeholder]; if a
/// concrete target is set on the follow component that always wins,
/// so upgrading a game to use the marker is opt-in per-camera.
class CameraFollowTarget {
  const CameraFollowTarget();
}

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
///
/// ## Target resolution
///
/// - When [target] is a concrete entity handle (the default), the
///   follow tracks that entity directly.
/// - When [target] is [Entity.placeholder], the system falls back to
///   the first entity carrying a [CameraFollowTarget] marker. This is
///   the ergonomic form for games where the camera is built before
///   the player exists, or where the "possessed" entity changes.
class CameraFollow {
  /// Entity to follow. If the entity is despawned, the system logs a
  /// warning once and stops updating this camera. Set to
  /// [Entity.placeholder] to opt into marker-based targeting (see
  /// [CameraFollowTarget]).
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

  /// Creates a camera-follow component with an explicit target.
  CameraFollow({
    required this.target,
    this.smoothing = 0.15,
    this.offset = Offset.zero,
  });

  /// Creates a camera-follow component that tracks whichever entity
  /// currently carries [CameraFollowTarget].
  CameraFollow.marker({this.smoothing = 0.15, this.offset = Offset.zero})
    : target = Entity.placeholder;
}

/// System that updates every camera with a [CameraFollow] component.
///
/// Runs in `Schedules.postUpdate`. Declares `after:
/// ['transform_propagate']` so it reads a fresh
/// `GlobalTransform2D` on the follow target.
///
/// **Root-camera fast path.** When the camera entity has no [Parent]
/// (the common case — a top-level camera), the system also writes
/// the camera's own `GlobalTransform2D` at the end of the follow
/// update. That means downstream world-space consumers running in
/// the same tick — a second sprite pass, a debug overlay drawn in
/// world space, a widget that clips around the camera — see the
/// fresh camera position without a second `TransformPropagateSystem`
/// pass. Hierarchical cameras still need propagation to run after
/// this system.
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
    writes: {
      ComponentId.of<Transform2D>(),
      ComponentId.of<GlobalTransform2D>(),
    },
    reads: {
      ComponentId.of<CameraFollow>(),
      ComponentId.of<Camera2D>(),
      ComponentId.of<CameraFollowTarget>(),
      ComponentId.of<Parent>(),
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

    // Cached marker lookup — resolve once per frame instead of once
    // per CameraFollow entity. `null` means "not looked up yet"; a
    // sentinel `Entity.placeholder` means "looked up, none found."
    Entity? markerTarget;
    Entity resolveMarker() {
      if (markerTarget != null) return markerTarget!;
      for (final (entity, _) in world.query1<CameraFollowTarget>().iter()) {
        markerTarget = entity;
        return entity;
      }
      markerTarget = Entity.placeholder;
      return markerTarget!;
    }

    for (final (cameraEntity, follow, camera, transform)
        in world.query3<CameraFollow, Camera2D, Transform2D>().iter()) {
      // Resolve the follow target. Explicit target wins; otherwise
      // fall back to the CameraFollowTarget marker.
      Entity target = follow.target;
      if (target == Entity.placeholder) {
        target = resolveMarker();
      }
      if (target == Entity.placeholder) {
        if (!follow.warnedMissingTarget) {
          // ignore: avoid_print
          print(
            '[fledge_camera_2d] CameraFollow has no target: neither '
            'CameraFollow.target nor a CameraFollowTarget marker was set. '
            'Camera will not update.',
          );
          follow.warnedMissingTarget = true;
        }
        continue;
      }

      final targetTransform = world.get<GlobalTransform2D>(target);
      if (targetTransform == null) {
        if (!follow.warnedMissingTarget) {
          // ignore: avoid_print
          print(
            '[fledge_camera_2d] CameraFollow.target ($target) has '
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
        final prev = world.get<PreviousTransform2D>(target);
        final cur = world.get<Transform2D>(target);
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

      // Root-camera fast path: if the camera has no Parent, its
      // GlobalTransform2D IS its local Transform2D. Write it in place
      // so downstream world-space consumers in the same tick see the
      // fresh camera position without a second TransformPropagateSystem
      // pass. Hierarchical cameras skip this: propagation must still
      // run after this system to compose the parent chain.
      if (!world.has<Parent>(cameraEntity)) {
        final cameraGlobal = world.get<GlobalTransform2D>(cameraEntity);
        if (cameraGlobal != null) {
          cameraGlobal.matrix.setFrom(transform.toMatrix());
        } else {
          world.insert(
            cameraEntity,
            GlobalTransform2D(transform.toMatrix()),
          );
        }
      }
    }
    return Future.value();
  }
}
