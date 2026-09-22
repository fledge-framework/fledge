import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show ActiveCameraView, GlobalTransform2D, TransformPropagateSystem;

import 'camera2d.dart';
import 'follow.dart';

/// Publishes the active camera's world position into
/// [ActiveCameraView] each frame so `fledge_render_2d`'s widget
/// render path (`FledgeRenderView`, `LitFledgeRenderView`,
/// `DebugGizmosLayer`) can translate the canvas to follow it.
///
/// Runs in `Schedules.postUpdate` after `CameraFollowSystem` so it
/// picks up the fresh camera position. Picks the lowest-order active
/// `Camera2D` (matching the render-graph `CameraDriverNode`'s tie-
/// breaker), and falls back to leaving the resource unchanged when no
/// active camera exists — widgets then use their world = screen
/// default.
///
/// Registered by `CameraPlugin`; games that construct camera plumbing
/// manually should register this system themselves.
class ActiveCameraViewSystem implements System {
  const ActiveCameraViewSystem();

  /// The `SystemMeta.name` of [ActiveCameraViewSystem]. Games that
  /// order their own systems relative to this one use it in
  /// `before:` / `after:`.
  static const String systemName = 'active_camera_view';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Camera2D>(), ComponentId.of<GlobalTransform2D>()},
    resourceWrites: {ActiveCameraView},
    after: const [
      CameraFollowSystem.systemName,
      'CameraShakeSystem',
      'CameraTransitionSystem',
      // ParallaxSystem writes GlobalTransform2D on parallax entities.
      // Order after it so the ambiguity check stays clean; the pair
      // doesn't actually race (parallax touches non-camera entities)
      // but the scheduler can't tell that.
      'ParallaxSystem',
      // Also order against transform_propagate so games that re-run
      // propagation in postUpdate (Batch 6 item 26) don't generate a
      // fresh ambiguity — this system reads GlobalTransform2D, which
      // the propagate pass writes.
      TransformPropagateSystem.systemName,
    ],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    Camera2D? best;
    GlobalTransform2D? bestTransform;
    var bestOrder = double.maxFinite.toInt();

    for (final (_, camera, transform)
        in world.query2<Camera2D, GlobalTransform2D>().iter()) {
      if (!camera.isActive) continue;
      if (camera.order < bestOrder) {
        bestOrder = camera.order;
        best = camera;
        bestTransform = transform;
      }
    }
    if (best == null || bestTransform == null) return Future.value();

    final view = world.getResource<ActiveCameraView>();
    if (view != null) {
      view.set(bestTransform.x, bestTransform.y);
      view.pixelPerfect = best.pixelPerfect;
    } else {
      world.insertResource(
        ActiveCameraView(
          x: bestTransform.x,
          y: bestTransform.y,
          pixelPerfect: best.pixelPerfect,
        ),
      );
    }
    return Future.value();
  }
}
