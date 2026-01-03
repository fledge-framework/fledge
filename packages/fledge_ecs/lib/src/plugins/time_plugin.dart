import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import '../app.dart';
import '../plugin.dart';
import '../system/run_condition.dart';
import '../system/system.dart';
import '../world.dart';

/// Time resource providing delta time and elapsed time.
///
/// Updated automatically each frame by [TimePlugin].
///
/// ```dart
/// @system
/// void mySystem(Res<Time> time) {
///   final deltaSeconds = time.value.delta;
///   final totalSeconds = time.value.elapsed;
/// }
/// ```
class Time {
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
      'Time(delta: ${delta.toStringAsFixed(4)}s, elapsed: ${elapsed.toStringAsFixed(2)}s, frame: $frameCount)';
}

/// System that updates the [Time] resource each frame.
class TimeUpdateSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'timeUpdate',
        resourceWrites: {Time},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    world.getResource<Time>()?.update();
    return Future.value();
  }
}

/// Plugin that provides time tracking functionality.
///
/// Adds a [Time] resource that tracks delta time, elapsed time,
/// and frame count. The time is updated at the start of each frame.
///
/// ```dart
/// App()
///   .addPlugin(TimePlugin())
///   .run();
/// ```
class TimePlugin implements Plugin {
  @override
  void build(App app) {
    final time = Time()..start();
    app.insertResource(time);
    app.addSystem(TimeUpdateSystem(), stage: CoreStage.first);
  }

  @override
  void cleanup() {}
}
