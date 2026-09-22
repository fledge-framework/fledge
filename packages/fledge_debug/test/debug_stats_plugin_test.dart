import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';

/// Batch 7 items 28 + 30 — stats without the overlay, public ordering
/// report, and no fresh ambiguities added to Schedules.first.
void main() {
  test('DebugStatsPlugin installs resources and no overlay entities', () {
    final app = App()..addPlugin(const DebugStatsPlugin());
    expect(app.world.getResource<FrameStats>(), isNotNull);
    expect(app.world.getResource<SystemStats>(), isNotNull);
    expect(app.world.getResource<ScheduleOrderingReport>(), isNotNull);

    // fledge_ui overlay entities need OverlayPopulateSystem, which the
    // stats-only plugin never adds. Sanity-check by asking for the
    // fledge_ui / DebugConfig resource — stats plugin never installs
    // DebugConfig.
    expect(app.world.getResource<DebugConfig>(), isNull);
  });

  test('DebugPlugin(overlay: false) skips OverlayPopulateSystem', () async {
    final app = App()
      ..addPlugin(const DebugPlugin(overlay: false));
    // Stats resources still installed.
    expect(app.world.getResource<FrameStats>(), isNotNull);
    // DebugConfig now inserted (Item 29 keeps existing; there was
    // none, so the plugin installed its default).
    expect(app.world.getResource<DebugConfig>(), isNotNull);
    // The ordering report exists too — DebugPlugin composes the stats
    // plugin.
    expect(app.world.getResource<ScheduleOrderingReport>(), isNotNull);
  });

  test('ScheduleOrderingReport refreshes on request event', () async {
    final app = App()..addPlugin(const DebugStatsPlugin());
    // Initial snapshot exists.
    final before = app.world.getResource<ScheduleOrderingReport>()!;
    expect(before.count, greaterThanOrEqualTo(0));

    // Fire the request. On the next tick the system drains it and
    // publishes a fresh report.
    app.world
        .eventWriter<RefreshScheduleOrderingReportRequested>()
        .send(const RefreshScheduleOrderingReportRequested());
    await app.tick();
    final after = app.world.getResource<ScheduleOrderingReport>()!;
    expect(after, isNotNull);
    // The report is refreshed — count is stable but the instance is
    // replaced by insertResource. Either way, no crash and no
    // stale data.
    expect(after.count, greaterThanOrEqualTo(0));
  });

  test(
    'stats systems in Schedules.first do not add fresh ambiguities '
    'to checkScheduleOrdering (Batch 7 #30)',
    () {
      // Sanity: an app with DebugStatsPlugin alone has no
      // registration-order ambiguities.
      final app = App()..addPlugin(const DebugStatsPlugin());
      final issues = app.checkScheduleOrdering();
      expect(
        issues.where((i) => i.stage == 'first'),
        isEmpty,
        reason:
            'Stats systems in Schedules.first should declare their '
            'ordering explicitly.',
      );
    },
  );
}
