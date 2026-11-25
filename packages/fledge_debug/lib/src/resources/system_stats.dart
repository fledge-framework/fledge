/// Per-frame system-execution stats.
///
/// Two invariants live here today:
///
/// - [frameStartMicros] / [frameEndMicros] — a monotonic-clock bracket
///   written by [SystemStatsSystem] at `Schedules.first` and
///   `Schedules.last` respectively. [totalFrameMicros] is their
///   difference, in the absence of a per-system hook. Note this
///   deliberately excludes `extract` and `render` — those run after
///   `Schedules.last`; putting the end marker in a later schedule would
///   pull them in but also risk running before the render pipeline has
///   registered its own systems in some plugin configurations.
///
/// - [scheduleSystemCounts] — filled once by [SystemStatsSystem] the
///   first time it runs, by walking the [Scheduler]'s stages. Cheap and
///   stable — the count only changes when a plugin adds or removes a
///   system, which is not something we need to poll every frame.
///
/// Full per-system wall-clock is a follow-up: it would need the
/// scheduler to invoke a hook around each `System.run` (see
/// [SystemProfilerHook] for the intended shape). Games that want it
/// today can wrap individual systems with their own decorator and push
/// samples in through [timings].
class SystemStats {
  /// Monotonic microseconds at the start of the current frame, as read
  /// by [SystemStatsSystem] in `Schedules.first`.
  int frameStartMicros = 0;

  /// Monotonic microseconds at the end of the current frame, as read
  /// by [SystemStatsSystem] in `Schedules.last`.
  int frameEndMicros = 0;

  /// [frameEndMicros] − [frameStartMicros], capped at 0.
  int get totalFrameMicros {
    final diff = frameEndMicros - frameStartMicros;
    return diff < 0 ? 0 : diff;
  }

  /// [totalFrameMicros] in milliseconds. Convenience for overlay lines.
  double get totalFrameMilliseconds => totalFrameMicros / 1000.0;

  /// Per-schedule system counts. Keys are `Schedule.name` (e.g. "update"),
  /// values are the number of systems registered on that schedule.
  ///
  /// Empty until [SystemStatsSystem] has run at least once.
  final Map<String, int> scheduleSystemCounts = <String, int>{};

  /// Optional per-system timing store. Populated by games that plug in
  /// their own [SystemProfilerHook] decorators. Keys are
  /// `"$scheduleName.$systemName"`; values are the most recent sample's
  /// duration in microseconds. Empty in MVP builds.
  final Map<String, int> timings = <String, int>{};

  /// Reset every counter — useful after a scene reset so the readout
  /// doesn't lag with stale numbers.
  void reset() {
    frameStartMicros = 0;
    frameEndMicros = 0;
    scheduleSystemCounts.clear();
    timings.clear();
  }
}

/// Callback shape for the (future) per-system profiler hook.
///
/// A `Scheduler`-level integration would call this around every
/// `System.run` with the elapsed microseconds. It is defined here now
/// so games can build their own decorators against a stable signature
/// even before the scheduler-side hook lands.
typedef SystemProfilerHook = void Function(
  String scheduleName,
  String systemName,
  int durationMicros,
);
