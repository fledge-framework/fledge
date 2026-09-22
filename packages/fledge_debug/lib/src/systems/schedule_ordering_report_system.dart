import 'package:fledge_ecs/fledge_ecs.dart';

import '../resources/schedule_ordering_report.dart';

/// Refreshes [ScheduleOrderingReport] whenever a
/// [RefreshScheduleOrderingReportRequested] event fires.
///
/// Registered by [DebugStatsPlugin] and by [DebugPlugin]. Reads the
/// event queue, re-runs `Scheduler.checkOrderingAmbiguities()` on the
/// scheduler it was built with, and publishes the fresh list.
class ScheduleOrderingReportSystem implements System {
  /// The scheduler whose stages the report describes.
  final Scheduler scheduler;

  /// Creates the report-refresh system for [scheduler].
  ScheduleOrderingReportSystem(this.scheduler);

  @override
  SystemMeta get meta => const SystemMeta(
    name: 'debug_schedule_ordering_report',
    // Order after every known exclusive init system in Schedules.first
    // so this system doesn't add a fresh registration-order ambiguity
    // to games that install the window / audio / tilemap plugins.
    // Names refer to systems that may not exist in every app — the
    // scheduler ignores unresolved after-names.
    after: [
      'WindowInitSystem',
      'AudioInitSystem',
      'wallTimeUpdate',
    ],
    before: [
      'tilemap_spawn',
    ],
    resourceWrites: {ScheduleOrderingReport},
    eventReads: {RefreshScheduleOrderingReportRequested},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final reader = world.eventReader<RefreshScheduleOrderingReportRequested>();
    if (reader.isEmpty) return Future.value();
    // Drain the queue.
    for (final _ in reader.read()) {}
    final issues = scheduler.checkOrderingAmbiguities();
    final items = issues
        .map((a) => '${a.stage}: ${a.systemA} <-> ${a.systemB}')
        .toList(growable: false);
    world.insertResource(ScheduleOrderingReport(List.unmodifiable(items)));
    return Future.value();
  }
}
