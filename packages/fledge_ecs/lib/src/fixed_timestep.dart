/// Configuration + accumulator state for the fixed-timestep loop.
///
/// The `Scheduler` runs the fixed-timestep chain
/// (`Schedules.fixedFirst` → `Schedules.fixedPreUpdate` →
/// `Schedules.fixedUpdate` → `Schedules.fixedPostUpdate` →
/// `Schedules.fixedLast`) 0..[maxCatchupSteps] times per frame based on
/// the accumulated real-time delta. Users configure the cadence by
/// inserting this resource into the app before `run()`; if not
/// inserted, `App` provides a default 60Hz instance.
///
/// ## Example
///
/// ```dart
/// App()
///   ..insertResource(FixedTimestep(
///     stepDuration: const Duration(microseconds: 8333), // 120Hz
///     maxCatchupSteps: 3,
///   ))
///   .run();
/// ```
class FixedTimestep {
  /// Target duration of one fixed step (default: 1/60 s).
  final Duration stepDuration;

  /// Maximum number of fixed steps to run in a single frame before
  /// dropping the remaining accumulated time. Prevents a "spiral of
  /// death" when a real frame runs long.
  final int maxCatchupSteps;

  /// Elapsed real time (in seconds) since the last fixed step. The
  /// scheduler owns this — reading from user code is fine (see [alpha]
  /// / [accumulatorSeconds]), but do not mutate.
  double _accumulatorSeconds = 0.0;

  /// Number of fixed steps that ran in the most recent frame. Read-only
  /// diagnostic; useful for a debug overlay.
  int stepsThisFrame = 0;

  FixedTimestep({
    this.stepDuration = const Duration(microseconds: 16667), // ~60 Hz
    this.maxCatchupSteps = 5,
  });

  /// One fixed step, in seconds.
  double get stepSeconds => stepDuration.inMicroseconds / 1e6;

  /// Interpolation alpha for rendering (0..1) between the last completed
  /// fixed step and the next. Render systems can use this to smooth
  /// world-state changes over the visual frame.
  double get alpha {
    final s = stepSeconds;
    if (s <= 0) return 0.0;
    return (_accumulatorSeconds / s).clamp(0.0, 1.0);
  }

  /// Current accumulator value, in seconds. Read-only diagnostic.
  double get accumulatorSeconds => _accumulatorSeconds;
}

/// Package-internal handles onto [FixedTimestep] state that the
/// scheduler uses to advance the accumulator. User code should not
/// import or call these.
///
/// Kept in the same library as [FixedTimestep] so the private
/// `_accumulatorSeconds` field is reachable.
extension FixedTimestepInternal on FixedTimestep {
  /// Adds real-time [seconds] to the accumulator. Called by
  /// `Scheduler.runFixedIfDue` at the top of each frame's fixed pass.
  void addAccumulated(double seconds) {
    _accumulatorSeconds += seconds;
  }

  /// Consumes one fixed step's worth of accumulated time.
  void consumeStep() {
    _accumulatorSeconds -= stepSeconds;
  }

  /// Drops all remaining accumulated time — used when the catch-up cap
  /// is hit to avoid a spiral of death.
  void dropRemainder() {
    _accumulatorSeconds = 0.0;
  }
}
