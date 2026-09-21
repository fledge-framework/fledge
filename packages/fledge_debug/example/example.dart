import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

/// Minimal fledge_debug example.
///
/// Adds the [DebugPlugin] to an [App]. The plugin inserts a
/// [DebugConfig], [FrameStats] and [SystemStats] resource, then
/// installs the four systems that keep them fresh and mutate the
/// retained-mode HUD each tick.
///
/// `DebugConfig` is the one thing games actually poke at runtime —
/// flip a flag, insert the new value back on the app, and the next
/// tick reflects the change.
void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(const DebugPlugin());

  // Toggle AABB gizmos on and bump the overlay font — the widget
  // (`DebugGizmosLayer`) reads these back at paint time.
  final cfg = app.world.getResource<DebugConfig>()!;
  app.insertResource(cfg.copyWith(showAabbGizmos: true, overlayFontSize: 14));

  // One tick — FrameStatsSystem consumes `WallTime.delta` and
  // OverlayPopulateSystem rebuilds this frame's HUD entities.
  await app.tick();
}
