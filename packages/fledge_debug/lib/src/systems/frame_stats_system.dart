import 'package:fledge_ecs/fledge_ecs.dart';

import '../resources/frame_stats.dart';

/// Pushes each frame's `WallTime.delta` into [FrameStats].
///
/// Runs in `Schedules.first` so the smoothed FPS and rolling window
/// reflect the previous frame's delta by the time the overlay populate
/// system runs later in the same tick.
///
/// Reads [WallTime] and writes [FrameStats] — both resources — so it
/// doesn't fight anything for entity access.
class FrameStatsSystem implements System {
  /// Creates the frame-stats system.
  const FrameStatsSystem();

  @override
  SystemMeta get meta => const SystemMeta(
    name: 'debug_frame_stats',
    resourceReads: {WallTime},
    resourceWrites: {FrameStats},
    // WallTime is written by `wallTimeUpdate` in the same schedule
    // (`Schedules.first`). Declare the dependency explicitly so
    // ordering doesn't fall back to registration order — see
    // `App.checkScheduleOrdering()` for why that matters.
    //
    // Also order after the exclusive init systems that live in
    // Schedules.first (WindowInitSystem / AudioInitSystem) and before
    // fledge_tiled's tilemap_spawn, so this debug system doesn't
    // introduce fresh registration-order ambiguities to any app
    // that installs those plugins.
    after: ['wallTimeUpdate', 'WindowInitSystem', 'AudioInitSystem'],
    before: ['tilemap_spawn'],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final time = world.getResource<WallTime>();
    final stats = world.getResource<FrameStats>();
    if (time == null || stats == null) return Future.value();
    stats.recordFrame(time.delta);
    return Future.value();
  }
}
