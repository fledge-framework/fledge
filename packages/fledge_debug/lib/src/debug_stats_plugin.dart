import 'package:fledge_ecs/fledge_ecs.dart';

import 'resources/frame_stats.dart';
import 'resources/schedule_ordering_report.dart';
import 'resources/system_stats.dart';
import 'systems/frame_stats_system.dart';
import 'systems/schedule_ordering_report_system.dart';
import 'systems/system_stats_system.dart';

/// Installs the debug **stats** — FPS, per-schedule system counts,
/// per-frame timing — without the overlay or gizmo machinery.
///
/// Meant for games that ship their own perf HUD (Porios does — a
/// Flutter panel driven by these resources) or that want to render
/// the debug data in world-space, away from `fledge_ui`'s screen-
/// space overlay.
///
/// Resources inserted:
///
/// - [FrameStats] — smoothed FPS + rolling window.
/// - [SystemStats] — per-frame monotonic start/end + per-schedule
///   system counts.
/// - [ScheduleOrderingReport] — public snapshot of
///   `App.checkScheduleOrdering()` output, refreshed on
///   [RefreshScheduleOrderingReportRequested] (and once at plugin
///   build time).
///
/// Systems added:
///
/// - [FrameStatsSystem]         → `Schedules.first`.
/// - [SystemStatsStartSystem]   → `Schedules.first`.
/// - [SystemStatsEndSystem]     → `Schedules.last`.
/// - [ScheduleOrderingReportSystem] → `Schedules.first`.
///
/// The `first`-schedule systems declare `after: [WindowInitSystem,
/// AudioInitSystem, wallTimeUpdate]` and `before: [tilemap_spawn]`
/// so they don't add new registration-order ambiguities to any
/// checkScheduleOrdering baseline.
///
/// **Standalone / composable.** Games using [DebugPlugin] get the
/// same stats plumbing (that plugin composes this one). Games that
/// only want stats install this plugin alone — the overlay-populate
/// system and its fledge_ui entities are skipped.
class DebugStatsPlugin implements Plugin {
  /// Creates the stats-only plugin.
  const DebugStatsPlugin();

  @override
  void build(App app) {
    if (!app.world.hasResource<FrameStats>()) {
      app.insertResource(FrameStats());
    }
    if (!app.world.hasResource<SystemStats>()) {
      app.insertResource(SystemStats());
    }
    if (!app.world.hasResource<ScheduleOrderingReport>()) {
      app.insertResource(ScheduleOrderingReport.empty);
    }

    app.addEvent<RefreshScheduleOrderingReportRequested>();

    app.addSystem(const FrameStatsSystem(), schedule: Schedules.first);
    app.addSystem(
      SystemStatsStartSystem(app.scheduler),
      schedule: Schedules.first,
    );
    app.addSystem(const SystemStatsEndSystem(), schedule: Schedules.last);
    app.addSystem(
      ScheduleOrderingReportSystem(app.scheduler),
      schedule: Schedules.first,
    );

    // Snapshot once at build time so the resource has data before the
    // first tick — the same courtesy DebugPlugin has given to its
    // internal ambiguity report.
    refreshScheduleOrderingReport(app);
  }

  @override
  void cleanup() {}
}

/// Re-runs `App.checkScheduleOrdering()` and publishes the result to
/// [ScheduleOrderingReport]. Cheap enough to call from a menu action.
///
/// The stats plugin already refreshes on
/// [RefreshScheduleOrderingReportRequested]; this is the direct entry
/// point for games that want to trigger a refresh without going
/// through the event bus.
void refreshScheduleOrderingReport(App app) {
  final issues = app.checkScheduleOrdering();
  final items = issues
      .map((a) => '${a.schedule}: ${a.systemA} <-> ${a.systemB}')
      .toList(growable: false);
  app.insertResource(ScheduleOrderingReport(List.unmodifiable(items)));
}
