import 'package:fledge_ecs/fledge_ecs.dart';

import 'resources/debug_config.dart';
import 'resources/frame_stats.dart';
import 'resources/system_stats.dart';
import 'systems/frame_stats_system.dart';
import 'systems/overlay_populate_system.dart';
import 'systems/system_stats_system.dart';

/// Wires runtime observability into an [App].
///
/// Inserts three resources ([DebugConfig], [FrameStats], [SystemStats])
/// and adds four systems:
///
/// - [FrameStatsSystem]      → `Schedules.first`, updates FPS/history.
/// - [SystemStatsStartSystem] → `Schedules.first`, snapshots start-of-
///   frame monotonic time and refreshes the per-schedule system counts.
/// - [SystemStatsEndSystem]   → `Schedules.last`, snapshots end-of-frame
///   monotonic time.
/// - [OverlayPopulateSystem]  → `Schedules.preUpdate`, mutates the UI
///   entities that back the HUD. Sits before any game's HUD writes in
///   `update`, so the two never claim the same UiText component in the
///   same schedule — a common false-positive-ambiguity source.
///   `LayoutSystem` from `fledge_ui` still runs later, in `postUpdate`,
///   so both this frame's debug text and the game's HUD text are laid
///   out together.
///
/// The plugin also captures the app's `checkScheduleOrdering()` output
/// at [build] time and publishes it as an internal resource so the
/// overlay's ambiguity block reflects the current schedule graph. Games
/// that add plugins later can call [refreshAmbiguityReport] to update
/// the readout.
///
/// ```dart
/// app.addPlugin(
///   const DebugPlugin(
///     config: DebugConfig(showAabbGizmos: true),
///   ),
/// );
/// ```
class DebugPlugin implements Plugin {
  /// The initial debug configuration.
  final DebugConfig config;

  /// Creates a debug plugin with the given [config].
  const DebugPlugin({this.config = const DebugConfig()});

  @override
  void build(App app) {
    app.insertResource(config);
    app.insertResource(FrameStats());
    app.insertResource(SystemStats());

    app.addSystem(const FrameStatsSystem(), schedule: Schedules.first);
    app.addSystem(
      SystemStatsStartSystem(app.scheduler),
      schedule: Schedules.first,
    );
    app.addSystem(const SystemStatsEndSystem(), schedule: Schedules.last);
    app.addSystem(const OverlayPopulateSystem(), schedule: Schedules.preUpdate);

    // Snapshot ambiguities at build time so the overlay has data on
    // its very first paint. Games that add plugins after the debug
    // plugin can call [refreshAmbiguityReport] to update the readout.
    refreshAmbiguityReport(app);
  }

  @override
  void cleanup() {}
}

/// Re-runs `App.checkScheduleOrdering()` and updates the internal
/// resource that [OverlayPopulateSystem] reads.
///
/// Cheap enough to call from a game's `onTick` or from a debug menu
/// action, but it walks every stage in the scheduler — don't invoke it
/// inside a hot loop.
void refreshAmbiguityReport(App app) {
  final issues = app.checkScheduleOrdering();
  final items = issues
      .map((a) => '${a.schedule}: ${a.systemA} <-> ${a.systemB}')
      .toList();
  publishAmbiguityReport(app.world, items);
}
