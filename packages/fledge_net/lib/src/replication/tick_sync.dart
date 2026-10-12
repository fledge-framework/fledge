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
    localTick = desired.ceil();
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
      localTick = desired.round();
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
  double step() {
    localTick++;
    if (_error > deadbandTicks) {
      _error -= dilation;
      return dilation;
    }
    if (_error < -deadbandTicks) {
      _error += dilation;
      return -dilation;
    }
    return 0;
  }

  /// Whether [localTick] jumped (handshake or hard reset) since the last
  /// call.
  bool consumeJump() {
    final j = _jumped;
    _jumped = false;
    return j;
  }
}
