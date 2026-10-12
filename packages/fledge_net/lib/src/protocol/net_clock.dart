/// Monotonic millisecond clock used for protocol timestamps and RTT.
///
/// Protocol timestamps are **local** values: a peer only ever compares a
/// timestamp against its own clock (a ping carries the sender's timestamp,
/// the pong echoes it back unchanged). Clocks on different machines are
/// never compared, so they do not need to be synchronised.
///
/// On the wire timestamps are 32-bit and wrap roughly every 49.7 days of
/// uptime. Always compute differences with [elapsed32], which is correct
/// across the wrap boundary.
///
/// [NetClock.system] is backed by a [Stopwatch] started on first use, so
/// it is immune to wall-clock adjustments (NTP, DST, user edits).
/// [ManualNetClock] is a deterministic clock for tests; pair it with a
/// manual-mode `LoopbackNetwork` to get exact, reproducible RTT figures.
abstract class NetClock {
  const NetClock();

  /// Process-wide monotonic clock backed by a [Stopwatch].
  static final NetClock system = SystemNetClock();

  /// Mask for 32-bit wire timestamps.
  static const int mask32 = 0xFFFFFFFF;

  /// Current monotonic time in milliseconds (arbitrary origin).
  int get nowMs;

  /// Current time truncated to a 32-bit wrapping wire timestamp.
  int get nowMs32 => nowMs & mask32;

  /// Truncate [ms] to a 32-bit wrapping wire timestamp.
  static int wrap32(int ms) => ms & mask32;

  /// Signed, wrap-safe difference `now32 - then32` between two 32-bit
  /// wire timestamps, in milliseconds.
  ///
  /// Results are in `[-2^31, 2^31)`; a negative result means [then32] is
  /// in the future relative to [now32] (e.g. a forged or corrupt echo).
  static int elapsed32(int now32, int then32) {
    final diff = (now32 - then32) & mask32;
    return diff >= 0x80000000 ? diff - 0x100000000 : diff;
  }
}

/// [NetClock] backed by a [Stopwatch] (monotonic, starts at 0).
class SystemNetClock extends NetClock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  int get nowMs => _stopwatch.elapsedMilliseconds;
}

/// Deterministic [NetClock] that only moves when told to.
///
/// Useful in tests together with a manual-mode `LoopbackNetwork`, which
/// advances this clock as it delivers packets.
class ManualNetClock extends NetClock {
  int _nowMs;

  /// Create a manual clock starting at [startMs].
  ManualNetClock([int startMs = 0]) : _nowMs = startMs;

  @override
  int get nowMs => _nowMs;

  /// Set the clock to an absolute time. Must not move backwards.
  set nowMs(int value) {
    if (value < _nowMs) {
      throw ArgumentError.value(value, 'nowMs', 'clock cannot move backwards');
    }
    _nowMs = value;
  }

  /// Advance the clock by [duration].
  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    _nowMs += duration.inMilliseconds;
  }
}
