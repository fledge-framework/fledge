import 'dart:math' show max;

/// Per-frame timing stats derived from [WallTime] deltas.
///
/// [FrameStatsSystem] updates this resource once per frame in
/// `Schedules.first`. The overlay reads it directly.
///
/// FPS is exponentially smoothed so a single slow frame does not
/// yank the displayed number around; percentile / max / average are
/// computed from the raw ring buffer so the "there was a hitch" signal
/// still comes through.
///
/// ```dart
/// final stats = world.getResource<FrameStats>()!;
/// print('fps=${stats.smoothedFps.toStringAsFixed(1)} '
///       'p99=${(stats.p99FrameSeconds * 1000).toStringAsFixed(1)}ms');
/// ```
class FrameStats {
  /// The delta seconds of the most recent frame.
  double lastFrameSeconds = 0.0;

  /// Exponentially smoothed FPS, driven towards `1 / delta` each frame.
  double smoothedFps = 0.0;

  /// Smoothing factor for [smoothedFps] — 0.1 favours stability, 0.5
  /// tracks the current frame more closely. Public so games can tune
  /// it if they need a snappier readout during profiling.
  double smoothingFactor;

  final List<double> _history = <double>[];
  final int _historyCap;

  /// Creates a frame-stats resource.
  ///
  /// [historyCap] bounds the ring buffer of samples used to derive
  /// [avgFrameSeconds], [p99FrameSeconds], and [maxFrameSeconds]. 120
  /// covers roughly two seconds at 60Hz, which is enough context to
  /// notice a stutter without keeping a huge buffer around.
  FrameStats({int historyCap = 120, this.smoothingFactor = 0.15})
    : _historyCap = historyCap;

  /// The size of the rolling history buffer.
  int get historyCapacity => _historyCap;

  /// Number of frame samples currently held.
  int get sampleCount => _history.length;

  /// Push a raw frame delta (seconds) into the history and update the
  /// smoothed FPS.
  ///
  /// The scheduler already gives us a non-negative delta, but real
  /// hosts occasionally hand back a zero for the very first frame —
  /// we treat that as a no-op instead of dividing.
  void recordFrame(double deltaSeconds) {
    if (deltaSeconds <= 0.0) return;
    lastFrameSeconds = deltaSeconds;

    _history.add(deltaSeconds);
    if (_history.length > _historyCap) {
      // Drop the oldest sample so the buffer stays bounded. A queue
      // would be cheaper for very large caps, but at 120 the shift is
      // fine and the flat List keeps sorting cheap in p99.
      _history.removeAt(0);
    }

    final instantFps = 1.0 / deltaSeconds;
    if (smoothedFps == 0.0) {
      smoothedFps = instantFps;
    } else {
      smoothedFps = smoothedFps + (instantFps - smoothedFps) * smoothingFactor;
    }
  }

  /// Average frame time across the current window.
  double get avgFrameSeconds {
    if (_history.isEmpty) return 0.0;
    var sum = 0.0;
    for (final s in _history) {
      sum += s;
    }
    return sum / _history.length;
  }

  /// 99th percentile frame time — the "when this game hitches, how big
  /// is the hitch" metric. Returns 0 when there aren't yet any samples.
  ///
  /// Uses the `floor(n * 0.99)` variant so that with `n=100` samples
  /// the reported p99 is the single slowest one — matching the "worst
  /// frame in the last 1%" intuition games typically want.
  double get p99FrameSeconds {
    if (_history.isEmpty) return 0.0;
    final sorted = List<double>.from(_history)..sort();
    final idx = max(
      0,
      (sorted.length * 0.99).floor(),
    ).clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  /// Slowest frame in the current window.
  double get maxFrameSeconds {
    if (_history.isEmpty) return 0.0;
    var worst = 0.0;
    for (final s in _history) {
      if (s > worst) worst = s;
    }
    return worst;
  }

  /// Reset all state. Useful when the game switches scenes and you
  /// want a fresh readout.
  void reset() {
    lastFrameSeconds = 0.0;
    smoothedFps = 0.0;
    _history.clear();
  }
}
