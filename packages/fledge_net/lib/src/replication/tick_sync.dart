/// Client-side tick synchronisation.
///
/// The client simulates (and produces inputs for) a **local tick** that
/// leads the host tick, so that an input for tick `t` reaches the host
/// just before the host simulates `t`:
///
/// ```
/// lead over the newest snapshot = RTT / step + bufferTicks
///   (one-way latency for the snapshot to arrive, one-way latency for the
///    input to travel back, plus a small safety buffer)
/// ```
///
/// [initialSync] sets the local tick from the connect-time handshake
/// (server tick + measured RTT). Afterwards every new snapshot tick is an
/// [observe] sample; the smoothed error is corrected by time dilation:
/// [step] returns a small fraction of a fixed step to add to (speed up) or
/// remove from (slow down) the `FixedTimestep` accumulator. Errors larger
/// than [hardResetTicks] snap the local tick directly ([consumeJump]
/// reports it so prediction history can be discarded).
///
/// The simulation clock is deliberately *not* used directly as the render
/// clock for interpolated entities: dilation, lead changes and resets
/// would show up as visible steps. [timeline] removes exactly those
/// corrections; `InterpolationClock` builds the render timeline on it.
class ClientTickSync {
  /// Fixed step length in milliseconds.
  final double stepMs;

  /// Safety margin in ticks on top of the RTT-derived lead.
  final int bufferTicks;

  /// Extra buffer added when the host reports late inputs (adaptive).
  int extraBufferTicks = 0;

  /// Cap for [extraBufferTicks].
  final int maxExtraBufferTicks;

  /// Error (ticks) beyond which the local tick is reset outright.
  final double hardResetTicks;

  /// Error (ticks) tolerated without correction.
  final double deadbandTicks;

  /// Fraction of a step added/removed per fixed step while correcting.
  final double dilation;

  /// Whether [initialSync] happened.
  bool synced = false;

  /// Tick the client is currently simulating / producing input for.
  int localTick = 0;

  /// Smoothed round-trip time in milliseconds used for the lead.
  double rttMs = 0;

  /// Number of hard resets so far (diagnostics).
  int resets = 0;

  double _error = 0;
  double _corrections = 0;
  int _lastObservedTick = -1;
  bool _jumped = false;
  int _lastLateCount = 0;

  ClientTickSync({
    required this.stepMs,
    this.bufferTicks = 2,
    this.maxExtraBufferTicks = 6,
    this.hardResetTicks = 10,
    this.deadbandTicks = 0.5,
    this.dilation = 0.1,
  });

  /// RTT in ticks.
  double get rttTicks => rttMs / stepMs;

  /// Desired lead of [localTick] over the newest snapshot tick.
  double get leadTicks => rttTicks + bufferTicks + extraBufferTicks;

  /// Smoothed error (desired minus actual local tick), in ticks.
  double get error => _error;

  /// Estimate of the current host tick.
  int get serverTickEstimate {
    final est = (localTick - rttTicks / 2 - bufferTicks - extraBufferTicks)
        .round();
    return est < 0 ? 0 : est;
  }

  /// Server tick to render interpolated entities at: the newest snapshot
  /// tick the client can expect to hold, minus [delayTicks].
  ///
  /// Follows every simulation-clock correction (dilation, lead changes,
  /// resets) one to one, so it is **not** smooth; `NetworkSession` renders
  /// on an `InterpolationClock` driven by [timeline] instead.
  double renderTick({required double alpha, required double delayTicks}) =>
      localTick + alpha - leadTicks - delayTicks;

  /// Handshake result: the host was at [serverTick] when it answered a
  /// request whose round trip took [rttSampleMs]; the answer arrived
  /// [elapsedMs] ago.
  void initialSync({
    required int serverTick,
    required double rttSampleMs,
    double elapsedMs = 0,
  }) {
    if (rttMs <= 0) rttMs = rttSampleMs;
    final desired =
        serverTick +
        (rttSampleMs + elapsedMs) / stepMs +
        bufferTicks +
        extraBufferTicks;
    _setLocalTick(desired.ceil());
    _error = 0;
    _lastObservedTick = serverTick;
    synced = true;
    _jumped = true;
  }

  /// A snapshot for [serverTick] arrived; [alpha] is the fraction of the
  /// current fixed step that has already elapsed (`FixedTimestep.alpha`).
  void observe({required int serverTick, double alpha = 0}) {
    if (!synced || serverTick <= _lastObservedTick) return;
    _lastObservedTick = serverTick;
    final desired = serverTick + leadTicks;
    final err = desired - (localTick + alpha);
    if (err.abs() > hardResetTicks) {
      _setLocalTick(desired.round());
      _error = 0;
      resets++;
      _jumped = true;
      return;
    }
    _error = _error * 0.8 + err * 0.2;
  }

  /// The running count of late inputs from this client reported by the
  /// host; each increase widens the buffer by one tick (up to the cap).
  void reportLateInputs(int lateCount) {
    if (lateCount > _lastLateCount) {
      _lastLateCount = lateCount;
      if (extraBufferTicks < maxExtraBufferTicks) extraBufferTicks++;
    }
  }

  /// Advance one fixed step. Returns the accumulator adjustment in
  /// **steps** (positive: run the next step sooner).
  ///
  /// The caller must apply the returned adjustment to the `FixedTimestep`
  /// accumulator (`nudge`); [timeline] assumes it did.
  double step() {
    localTick++;
    if (_error > deadbandTicks) {
      _error -= dilation;
      _corrections += dilation;
      return dilation;
    }
    if (_error < -deadbandTicks) {
      _error += dilation;
      _corrections -= dilation;
      return -dilation;
    }
    return 0;
  }

  /// Real elapsed time in ticks (arbitrary origin), given the current
  /// `FixedTimestep` accumulator in steps (`accumulatorSeconds /
  /// stepSeconds`, unclamped).
  ///
  /// `localTick + accumulatorSteps` is the simulation clock; this
  /// subtracts every correction this class made to it (dilation returned
  /// by [step], handshake and hard-reset jumps), so it advances by exactly
  /// the frame time the `FixedTimestep` received, however many fixed steps
  /// each frame ran and however the lead changes.
  double timeline(double accumulatorSteps) =>
      localTick + accumulatorSteps - _corrections;

  void _setLocalTick(int tick) {
    _corrections += tick - localTick;
    localTick = tick;
  }

  /// Whether [localTick] jumped (handshake or hard reset) since the last
  /// call.
  bool consumeJump() {
    final j = _jumped;
    _jumped = false;
    return j;
  }
}

/// Smooth render timeline (in server ticks) for interpolated entities.
///
/// Snapshot arrivals are noisy (jitter, loss) and the client simulation
/// clock is corrected all the time (time dilation, lead changes, tick
/// resets). Rendering must not inherit either: an interpolated entity has
/// to advance by exactly one frame of motion per frame.
///
/// - [observe] records, for each new snapshot tick, its offset from a
///   correction-free local timeline (`ClientTickSync.timeline`) and
///   low-pass filters it (the mean arrival offset).
/// - [advance] moves the render tick forward by the elapsed timeline,
///   running at most [maxSlew] faster or slower than real time to converge
///   on `offset + timeline - delay`. It never moves backwards unless the
///   error exceeds the snap threshold (start, long stalls, huge delay
///   changes), where it jumps.
class InterpolationClock {
  /// Low-pass gain applied to each new snapshot offset sample.
  final double offsetGain;

  /// Rate change per tick of error (proportional slew).
  final double slewGain;

  /// Maximum fractional speed-up / slow-down of the render clock.
  final double maxSlew;

  /// Minimum error (ticks) beyond which the render tick snaps to target.
  final double snapTicks;

  double? _offset;
  double? _render;
  double _lastTimeline = 0;
  int _lastObservedTick = -1;

  InterpolationClock({
    this.offsetGain = 0.1,
    this.slewGain = 0.1,
    this.maxSlew = 0.1,
    this.snapTicks = 10,
  });

  /// Whether at least one snapshot was observed.
  bool get hasOffset => _offset != null;

  /// Smoothed `serverTick - timeline` of snapshot arrivals.
  double? get offset => _offset;

  /// Last value returned by [advance].
  double? get renderTick => _render;

  /// Forget the arrival offset (the host clock moved discontinuously, e.g.
  /// a client tick reset); the next [observe] re-seeds it and [advance]
  /// snaps if the render tick is then far off.
  void resetOffset() => _offset = null;

  /// Snapshot [serverTick] arrived when the local timeline was [timeline].
  /// Older or repeated ticks are ignored.
  void observe({required int serverTick, required double timeline}) {
    if (serverTick <= _lastObservedTick) return;
    _lastObservedTick = serverTick;
    final sample = serverTick - timeline;
    final o = _offset;
    _offset = o == null ? sample : o + (sample - o) * offsetGain;
  }

  /// Advance to [timeline] and return the server tick to render at,
  /// [delayTicks] behind the expected newest snapshot. Requires
  /// [hasOffset].
  double advance({required double timeline, required double delayTicks}) {
    final target = timeline + _offset! - delayTicks;
    final render = _render;
    final elapsed = timeline - _lastTimeline;
    _lastTimeline = timeline;
    if (render == null || elapsed < 0) return _render = target;
    // Error after a nominal (real-time) advance.
    final error = target - (render + elapsed);
    final snap = snapTicks > delayTicks ? snapTicks : delayTicks;
    if (error.abs() > snap) return _render = target;
    final rate = 1 + (error * slewGain).clamp(-maxSlew, maxSlew);
    return _render = render + elapsed * rate;
  }
}
