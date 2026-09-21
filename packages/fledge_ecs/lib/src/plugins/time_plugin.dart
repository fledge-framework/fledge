import '../app.dart';
import '../plugin.dart';
import '../system/run_condition.dart';
import '../system/schedule_label.dart';
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

  /// The stopwatch used for timing.
  final Stopwatch _stopwatch = Stopwatch();

  /// The time of the last frame.
  double _lastTime = 0.0;

  /// Starts the time tracking.
  void start() {
    _stopwatch.start();
    _lastTime = 0.0;
  }

  /// Updates the time for a new frame.
  void update() {
    final currentTime = _stopwatch.elapsedMicroseconds / 1000000.0;
    delta = currentTime - _lastTime;
    elapsed = currentTime;
    _lastTime = currentTime;
    frameCount++;
  }

  /// Resets the time tracking.
  void reset() {
    _stopwatch.reset();
    delta = 0.0;
    elapsed = 0.0;
    frameCount = 0;
    _lastTime = 0.0;
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
  /// Creates a new WallTime update system.
  const WallTimeUpdateSystem();

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'wallTimeUpdate',
        resourceWrites: {WallTime},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    world.getResource<WallTime>()?.update();
    return Future.value();
  }
}

/// Deprecated alias for [WallTimeUpdateSystem].
@Deprecated(
    'Renamed to WallTimeUpdateSystem in v0.2. Use WallTimeUpdateSystem.')
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
