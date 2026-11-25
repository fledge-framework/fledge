import 'package:fledge_ecs/fledge_ecs.dart';

import 'active_camera_view_system.dart';
import 'follow.dart';
import 'parallax.dart';
import 'shake.dart';
import 'transitions.dart';
import 'viewport_size.dart';

/// Plugin that wires camera systems into an [App].
///
/// Adds five systems to `Schedules.postUpdate` with explicit
/// ordering:
///
/// 1. [CameraFollowSystem]     — sets the base camera position from the follow target.
/// 2. [CameraShakeSystem]      — decays trauma, picks this frame's shake offset.
/// 3. [ParallaxSystem]         — reads the shown camera position (shake included), adjusts parallax entities.
/// 4. [CameraTransitionSystem] — advances fade / wipe overlays.
/// 5. [ActiveCameraViewSystem] — publishes the camera position plus shake for the widget render path.
///
/// Also inserts a [ViewportSize] resource (defaults to 1280×720)
/// unless one is already registered.
///
/// ```dart
/// final app = App()
///   ..addPlugin(RenderPlugin())
///   ..addPlugin(CameraPlugin());
/// ```
class CameraPlugin implements Plugin {
  /// Creates a camera plugin.
  const CameraPlugin();

  @override
  void build(App app) {
    if (!app.world.hasResource<ViewportSize>()) {
      app.insertResource(ViewportSize());
    }

    // Ordering is declared on each system's SystemMeta.before/after,
    // but insertion order still matters when the scheduler falls
    // back to registration order for non-conflicting systems.
    app.addSystem(CameraFollowSystem(), schedule: Schedules.postUpdate);
    app.addSystem(CameraShakeSystem(), schedule: Schedules.postUpdate);
    app.addSystem(ParallaxSystem(), schedule: Schedules.postUpdate);
    app.addSystem(CameraTransitionSystem(), schedule: Schedules.postUpdate);
    // Publishes the active camera's world position into
    // ActiveCameraView (fledge_render_2d) so the widget render path
    // can translate its canvas to follow the camera. Runs after the
    // above so it picks up the fresh camera position.
    app.addSystem(
      const ActiveCameraViewSystem(),
      schedule: Schedules.postUpdate,
    );
  }

  @override
  void cleanup() {}
}
