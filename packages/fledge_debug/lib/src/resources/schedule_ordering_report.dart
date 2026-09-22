/// Public, read-only snapshot of the schedule-ordering ambiguities in
/// the running app.
///
/// [DebugStatsPlugin] (and [DebugPlugin]) install this resource and
/// keep it fresh: they refresh it at build time and again whenever a
/// [RefreshScheduleOrderingReportRequested] event is received. Games
/// that build a custom debug panel can read [items] / [count]
/// straight off the world without knowing that the overlay used to
/// publish the same data as a private resource.
///
/// The report is refresh-on-demand, not per-frame, because
/// `App.checkScheduleOrdering()` walks every stage in the scheduler —
/// cheap enough to fire from a menu action, expensive enough to skip
/// in a hot loop.
class ScheduleOrderingReport {
  /// Human-readable descriptions of each ambiguity — one line per
  /// item, formatted as `"<stage>: <systemA> <-> <systemB>"`.
  final List<String> items;

  /// Number of ambiguities in [items]. Sugar over `items.length`.
  int get count => items.length;

  /// Creates the report. The list is stored as-is; typical callers
  /// pass an unmodifiable list.
  const ScheduleOrderingReport(this.items);

  /// Empty report used before the first refresh.
  static const ScheduleOrderingReport empty = ScheduleOrderingReport([]);
}

/// Fire on the event bus to ask [DebugStatsPlugin] (or [DebugPlugin])
/// to re-run `App.checkScheduleOrdering()` and publish an updated
/// [ScheduleOrderingReport]. The refresh happens on the next tick;
/// consumers can read the resource immediately after.
class RefreshScheduleOrderingReportRequested {
  const RefreshScheduleOrderingReportRequested();
}
