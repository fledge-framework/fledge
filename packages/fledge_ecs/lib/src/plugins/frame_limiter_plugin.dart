import 'dart:async';

import '../app.dart';
import '../plugin.dart';
import '../system/run_condition.dart';
import '../system/schedule_label.dart';
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
  SystemMeta get meta =>
      const SystemMeta(name: 'frameStart', resourceWrites: {FrameTime});

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

/// System that limits frame rate to a target FPS.
///
/// Uses a drift-corrected schedule based on a monotonic [Stopwatch]: the
/// system tracks the wall-clock time at which the *next* frame should
/// begin and waits until that instant, rather than adding `1/fps` to
/// wherever the current frame happens to finish. This prevents the
/// slow accumulating drift that `Future.delayed` produces when frames
/// are shorter or longer than the target budget.
///
/// The wait itself is scheduled with a zero-duration [Timer] so we
/// yield to the event loop and let microtasks/UI events drain (a naive
/// spin-lock would starve the isolate). When Fledge is embedded in a
/// Flutter app, a follow-up pass will replace this with
/// `SchedulerBinding.scheduleFrame` / `Ticker` so the loop aligns with
/// vsync — that requires a widget-layer refactor (`App.tick` becomes a
/// ticker callback instead of a `while (running) tick()` loop) and is
/// tracked separately.
class FrameLimiterSystem implements System {
  /// The next monotonic instant (as microseconds since [Stopwatch.start])
  /// at which a frame should begin. Rolled forward by `targetDuration`
  /// each tick so temporary hitches don't cause a permanent phase shift.
  final Stopwatch _clock = Stopwatch();
  int _nextFrameMicros = 0;

  FrameLimiterSystem();

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

    final targetMicros = (config.targetFrameTime * 1000000).round();

    if (!_clock.isRunning) {
      _clock.start();
      // First frame: seed the schedule to "one target period from now"
      // so subsequent frames land on a stable cadence.
      _nextFrameMicros = _clock.elapsedMicroseconds + targetMicros;
      frameTime.recordSleep(0);
      return;
    }

    final nowMicros = _clock.elapsedMicroseconds;
    final waitMicros = _nextFrameMicros - nowMicros;

    if (waitMicros > 0) {
      // Zero-duration Timer yields to the event loop so I/O and UI can
      // drain during the wait. We loop until we reach the target
      // instant instead of trusting a single `Future.delayed(waitMicros)`,
      // because the OS scheduler routinely returns from a delay early
      // or late; polling the monotonic clock keeps us on schedule.
      while (_clock.elapsedMicroseconds < _nextFrameMicros) {
        final remaining = _nextFrameMicros - _clock.elapsedMicroseconds;
        // Round trip to the event queue. For "close to deadline" waits
        // (<1ms) we use a zero-duration timer; for larger waits we let
        // the OS sleep the isolate.
        if (remaining <= 1000) {
          await Future<void>(() {});
        } else {
          // Sleep for at most half the remaining budget so we wake up
          // early and busy-wait the last stretch — this is friendlier
          // to power than a single big delay that overshoots.
          final chunk = Duration(microseconds: remaining ~/ 2);
          await Future<void>.delayed(chunk);
        }
      }
      frameTime.recordSleep(waitMicros / 1000000.0);
    } else {
      // Frame took longer than the target. Don't try to "catch up" by
      // shortening future frames — that just makes the next frame late
      // too. Instead, resync the schedule to now so drift stays bounded
      // to at most one period.
      _nextFrameMicros = nowMicros;
      frameTime.recordSleep(0);
    }

    _nextFrameMicros += targetMicros;
  }
}

/// Plugin that provides frame rate limiting.
///
/// Limits the game to a target FPS using a drift-corrected schedule
/// (see [FrameLimiterSystem]). This is the recommended way to cap the
/// frame rate for a standalone (non-Flutter) Fledge game.
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
    app.addSystem(FrameStartSystem(), schedule: Schedules.first);
    app.addSystem(FrameLimiterSystem(), schedule: Schedules.last);
  }

  @override
  void cleanup() {}
}
