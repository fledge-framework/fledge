import 'package:fledge_ecs/fledge_ecs.dart';

import 'debug_stats_plugin.dart';
import 'resources/debug_config.dart';
import 'systems/overlay_populate_system.dart';

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

  /// Whether the plugin registers `OverlayPopulateSystem` (which
  /// spawns fledge_ui entities for the FPS / entity-count / ambiguity
  /// readout).
  ///
  /// - `true` (the default) — the pre-Batch-7 behaviour: the plugin
  ///   installs the overlay populate system and games that also add
  ///   `UiPlugin` see the readout.
  /// - `false` — skip the overlay populate system entirely. Games
  ///   without `UiPlugin` (or those that draw their own perf HUD in
  ///   Flutter, like Porios) install the plugin with `overlay: false`.
  ///   The stats resources and gizmo config are still installed;
  ///   `DebugGizmosLayer` and any custom UI can consume them.
  final bool overlay;

  /// Creates a debug plugin with the given [config].
  const DebugPlugin({this.config = const DebugConfig(), this.overlay = true});

  @override
  void build(App app) {
    // Keep an existing DebugConfig — a game may have inserted its own
    // (e.g. everything off by default) before adding the debug plugin.
    // Overwriting it silently would re-enable the overlay's defaults.
    // Games that want the plugin's config to win should insert it
    // themselves after building the plugin, or configure the resource
    // in a system that reacts to a request event.
    if (!app.world.hasResource<DebugConfig>()) {
      app.insertResource(config);
    }

    // Stats resources + systems come from the standalone plugin so
    // both entry points wire the same schedule and the same public
    // ScheduleOrderingReport resource.
    app.addPlugin(const DebugStatsPlugin());

    if (overlay) {
      app.addSystem(
        const OverlayPopulateSystem(),
        schedule: Schedules.preUpdate,
      );
    }

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
