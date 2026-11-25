import 'dart:math' as math;

import '../app.dart';
import '../plugin.dart';
import '../system/run_condition.dart';
import '../system/schedule_label.dart';
import '../system/standard_sets.dart';
import '../system/system.dart';
import '../world.dart';

/// Real-time (wall-clock) resource providing delta and elapsed seconds.
///
/// Updated automatically each frame by [WallTimePlugin]. Distinct from
/// in-game calendar time (see `fledge_calendar`'s `Calendar` resource):
/// [WallTime] tracks the real seconds that pass between frames on the
/// host device, regardless of pause, time-scale, or game-world clock.
///
/// ```dart
/// @system
/// void mySystem(Res<WallTime> time) {
///   final deltaSeconds = time.value.delta;
///   final totalSeconds = time.value.elapsed;
/// }
/// ```
class WallTime {
  /// Time since last frame in seconds.
  double delta = 0.0;

  /// Total elapsed time in seconds.
  double elapsed = 0.0;

  /// Frame count since start.
  int frameCount = 0;

  /// The stopwatch used for timing when no [useClock] clock is set.
  final Stopwatch _stopwatch = Stopwatch();

  /// The external clock set by [useClock], if any.
  Duration Function()? _clock;

  /// The [_clock] reading that counts as time zero.
  Duration _clockBase = Duration.zero;

  /// The time of the last frame.
  double _lastTime = 0.0;

  /// Whether a reading has been taken since [start], [useClock] or
  /// [reset]. The first one sets time zero and adds no time: a clock
  /// installed before it ever ticked (Flutter's vsync timestamp reads zero
  /// until the first frame, then the time since the system started) would
  /// otherwise make the first [delta] hours long.
  bool _primed = false;

  /// Starts the time tracking.
  void start() {
    _stopwatch.start();
    _lastTime = 0.0;
    _primed = false;
  }

  /// Reads time from [now] instead of the internal stopwatch, starting
  /// from zero at its first reading in [update] (a clock that hasn't ticked
  /// yet when this is called, as Flutter's vsync timestamp before the first
  /// frame, is fine).
  ///
  /// The stopwatch measures when [update] runs, which wanders by a few
  /// milliseconds from frame to frame. Anything moved by [delta] then
  /// moves unevenly on screen, which shows as judder in scrolling pixel
  /// art. A clock that reports when each frame is shown keeps [delta]
  /// steady. In Flutter, pass the vsync timestamp:
  ///
  /// ```dart
  /// time.useClock(() => SchedulerBinding.instance.currentSystemFrameTimeStamp);
  /// ```
  ///
  /// Vsync timestamps can wobble too (on Windows, frames sometimes report
  /// 13 and 20 ms apart at 60 Hz). Pass the display's [frameInterval] to
  /// count every [delta] in whole refreshes:
  ///
  /// ```dart
  /// final hz = PlatformDispatcher.instance.views.first.display.refreshRate;
  /// time.useClock(
  ///   () => SchedulerBinding.instance.currentSystemFrameTimeStamp,
  ///   frameInterval: WallTime.frameIntervalFor(hz),
  /// );
  /// ```
  ///
  /// The reported rate is only a first guess: it can be wrong, and it
  /// changes when the window moves to another monitor. [update] measures
  /// the real interval from the clock (the median of recent frame gaps,
  /// rounded to a standard rate by [frameIntervalFor]) and switches to it.
  ///
  /// Every frame on an advancing clock counts at least one refresh, even
  /// one that arrives early: Windows sometimes starts a frame a few
  /// milliseconds after the last, then keeps that new phase, and that frame
  /// is presented for a refresh of its own. Counting it as no time showed
  /// the same picture twice, a visible hitch.
  void useClock(Duration Function() now, {Duration? frameInterval}) {
    _clock = now;
    _clockBase = now();
    _frameInterval = frameInterval == null || frameInterval <= Duration.zero
        ? null
        : frameInterval.inMicroseconds / 1000000.0;
    _gaps.clear();
    _lastTime = 0.0;
    _primed = false;
    delta = 0.0;
    elapsed = 0.0;
  }

  /// The length of one display refresh in seconds that [delta] is counted
  /// in, as measured (or as passed to [useClock] until there's enough to
  /// measure); null when [delta] isn't counted in refreshes.
  double? get frameInterval => _clock == null ? null : _frameInterval;

  /// Recent gaps between clock readings, to measure the refresh interval.
  final List<double> _gaps = [];

  /// How many gaps the interval is measured over, and how many are needed
  /// before the measurement replaces the given interval.
  static const _gapWindow = 60;
  static const _gapsNeeded = 20;

  /// Measures the refresh interval from the recent frame gaps.
  void _measure(double gap) {
    if (gap <= 0) return;
    _gaps.add(gap);
    if (_gaps.length > _gapWindow) _gaps.removeAt(0);
    if (_gaps.length < _gapsNeeded) return;
    final sorted = [..._gaps]..sort();
    final median = sorted[sorted.length ~/ 2];
    _frameInterval = frameIntervalFor(1 / median).inMicroseconds / 1000000.0;
  }

  /// Standard display refresh rates, in Hz.
  static const standardRefreshRates = [
    24.0,
    30.0,
    48.0,
    50.0,
    60.0,
    72.0,
    75.0,
    90.0,
    100.0,
    120.0,
    144.0,
    165.0,
    180.0,
    240.0,
    360.0,
  ];

  /// The frame interval to pass to [useClock] for a display reporting
  /// [refreshRate] Hz.
  ///
  /// Displays often report a rate just under a standard one: a 59.94 Hz
  /// mode reads as 59 on Windows. A [delta] of 1/59 s moves things by
  /// uneven fractions of a pixel each frame (a 120 units/s walk is 2.034
  /// units, not 2), which a pixel-snapped camera turns into steps of
  /// different sizes. A rate within 1.5 Hz of a standard one counts as
  /// that rate, so per-frame movement stays a whole number of pixels. Any
  /// other positive rate is used as it is; zero or less (unknown) counts
  /// as 60 Hz.
  static Duration frameIntervalFor(double refreshRate) {
    var hz = refreshRate > 0 ? refreshRate : 60.0;
    for (final standard in standardRefreshRates) {
      if ((hz - standard).abs() <= 1.5) {
        hz = standard;
        break;
      }
    }
    return Duration(microseconds: (1e6 / hz).round());
  }

  /// The [useClock] frame interval in seconds, if any.
  double? _frameInterval;

  double get _now {
    final clock = _clock;
    if (clock == null) return _stopwatch.elapsedMicroseconds / 1000000.0;
    return (clock() - _clockBase).inMicroseconds / 1000000.0;
  }

  /// Updates the time for a new frame.
  void update() {
    if (!_primed) {
      // The first reading is time zero: no time has passed yet.
      _primed = true;
      final clock = _clock;
      if (clock != null) _clockBase = clock();
      _lastTime = _clock == null ? _now : 0.0;
      delta = 0.0;
      frameCount++;
      return;
    }
    final currentTime = _now;
    // A clock that hasn't advanced (or stepped back) adds no time.
    final raw = currentTime > _lastTime ? currentTime - _lastTime : 0.0;
    final interval = _clock == null ? null : _frameInterval;
    if (interval == null) {
      delta = raw;
      // Summed, not read from the clock, so time before the first reading
      // (which adds no delta) is not counted either.
      elapsed += delta;
    } else {
      _measure(raw);
      final measured = _frameInterval!;
      // Whole refreshes, at least one for a frame the clock moved for (it's
      // shown for a refresh); the remainder (vsync wobble) is dropped, so
      // game time stays locked to the refresh count.
      final frames = raw <= 0 ? 0 : math.max(1, (raw / measured).round());
      delta = frames * measured;
      elapsed += delta;
    }
    _lastTime = currentTime;
    frameCount++;
  }

  /// Resets the time tracking.
  void reset() {
    _stopwatch.reset();
    final clock = _clock;
    if (clock != null) _clockBase = clock();
    delta = 0.0;
    elapsed = 0.0;
    frameCount = 0;
    _lastTime = 0.0;
    _primed = false;
  }

  @override
  String toString() =>
      'WallTime(delta: ${delta.toStringAsFixed(4)}s, elapsed: ${elapsed.toStringAsFixed(2)}s, frame: $frameCount)';
}

/// Deprecated alias for [WallTime].
///
/// Renamed to [WallTime] in v0.2 to clarify the distinction from
/// `fledge_calendar`'s in-game `Calendar` resource. Update call sites to
/// [WallTime]; this typedef will be removed in a future release.
@Deprecated('Renamed to WallTime in v0.2. Use WallTime instead.')
typedef Time = WallTime;

/// System that updates the [WallTime] resource each frame.
class WallTimeUpdateSystem implements System {
  /// The `SystemMeta.name` of [WallTimeUpdateSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'wallTimeUpdate';

  /// Creates a new WallTime update system.
  const WallTimeUpdateSystem();

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    resourceWrites: {WallTime},
    sets: [FirstSets.frameStart],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    world.getResource<WallTime>()?.update();
  }
}

/// Deprecated alias for [WallTimeUpdateSystem].
@Deprecated(
  'Renamed to WallTimeUpdateSystem in v0.2. Use WallTimeUpdateSystem.',
)
typedef TimeUpdateSystem = WallTimeUpdateSystem;

/// Plugin that provides wall-clock time tracking.
///
/// Adds a [WallTime] resource that tracks delta time, elapsed time,
/// and frame count. The time is updated at the start of each frame.
///
/// ```dart
/// App()
///   .addPlugin(WallTimePlugin())
///   .run();
/// ```
class WallTimePlugin implements Plugin {
  /// Creates a new wall-time plugin.
  const WallTimePlugin();

  @override
  void build(App app) {
    final time = WallTime()..start();
    app.insertResource(time);
    app.addSystem(const WallTimeUpdateSystem(), schedule: Schedules.first);
  }

  @override
  void cleanup() {}
}

/// Deprecated alias for [WallTimePlugin].
///
/// Renamed to [WallTimePlugin] in v0.2 to clarify the distinction from
/// `fledge_calendar`'s in-game `CalendarPlugin`. Update call sites to
/// [WallTimePlugin]; this class will be removed in a future release.
@Deprecated('Renamed to WallTimePlugin in v0.2. Use WallTimePlugin instead.')
class TimePlugin extends WallTimePlugin {
  /// Creates a new deprecated time plugin (forwards to [WallTimePlugin]).
  const TimePlugin();
}
