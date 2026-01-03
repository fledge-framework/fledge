import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

import '../app.dart';
import '../plugin.dart';
import '../system/run_condition.dart';
import '../system/system.dart';
import '../world.dart';

/// Configuration for frame rate limiting.
class FrameLimiterConfig {
  /// Target frames per second.
  final double targetFps;

  /// Target frame time in seconds.
  double get targetFrameTime => 1.0 / targetFps;

  /// Target frame time as a Duration.
  Duration get targetDuration =>
      Duration(microseconds: (targetFrameTime * 1000000).round());

  const FrameLimiterConfig({this.targetFps = 60.0});
}

/// Resource tracking frame timing.
class FrameTime {
  /// Time spent in the last frame (before limiting).
  double frameTime = 0.0;

  /// Time spent sleeping to limit frame rate.
  double sleepTime = 0.0;

  /// Actual time between frames (including sleep).
  double totalTime = 0.0;

  /// Current effective FPS.
  double get fps => totalTime > 0 ? 1.0 / totalTime : 0.0;

  final Stopwatch _stopwatch = Stopwatch();

  void startFrame() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  void endFrame() {
    _stopwatch.stop();
    frameTime = _stopwatch.elapsedMicroseconds / 1000000.0;
  }

  void recordSleep(double seconds) {
    sleepTime = seconds;
    totalTime = frameTime + sleepTime;
  }
}

/// System that records frame start time.
class FrameStartSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'frameStart',
        resourceWrites: {FrameTime},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    world.getResource<FrameTime>()?.startFrame();
    return Future.value();
  }
}

/// System that limits frame rate by sleeping.
class FrameLimiterSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'frameLimiter',
        resourceReads: {FrameLimiterConfig},
        resourceWrites: {FrameTime},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final config = world.getResource<FrameLimiterConfig>();
    final frameTime = world.getResource<FrameTime>();

    if (config == null || frameTime == null) return;

    frameTime.endFrame();

    final targetTime = config.targetFrameTime;
    final elapsed = frameTime.frameTime;

    if (elapsed < targetTime) {
      final sleepDuration = targetTime - elapsed;
      await Future.delayed(
          Duration(microseconds: (sleepDuration * 1000000).round()));
      frameTime.recordSleep(sleepDuration);
    } else {
      frameTime.recordSleep(0);
    }
  }
}

/// Plugin that provides frame rate limiting.
///
/// Limits the game to a target FPS by sleeping at the end of each frame.
///
/// ```dart
/// App()
///   .addPlugin(FrameLimiterPlugin(targetFps: 60))
///   .run();
/// ```
class FrameLimiterPlugin implements Plugin {
  final double targetFps;

  const FrameLimiterPlugin({this.targetFps = 60.0});

  @override
  void build(App app) {
    app.insertResource(FrameLimiterConfig(targetFps: targetFps));
    app.insertResource(FrameTime());
    app.addSystem(FrameStartSystem(), stage: CoreStage.first);
    app.addSystem(FrameLimiterSystem(), stage: CoreStage.last);
  }

  @override
  void cleanup() {}
}
