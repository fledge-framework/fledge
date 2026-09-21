import 'package:fledge_ecs/fledge_ecs.dart';

import '../resources/system_stats.dart';

/// Shared monotonic clock for [SystemStats].
///
/// One [Stopwatch] shared between the "start" and "end" systems below.
/// `App` construction goes through the plugin so both systems see the
/// same instance without stashing anything on the world.
///
/// A top-level stopwatch is fine for a debug package — there is only
/// one `App` per process for any realistic Fledge deployment. Games
/// that run multiple apps in parallel can build their own scoped
/// resource; the MVP does not.
final Stopwatch _clock = Stopwatch()..start();

/// Marks the start of the current frame's stats window.
///
/// Registered in `Schedules.first` by the plugin. Also refreshes the
/// per-schedule system counts each frame (cheap: it walks the
/// `Scheduler`'s stage list, not the world) so a plugin that swaps
/// systems out mid-run shows up on the overlay by the next tick.
class SystemStatsStartSystem implements System {
  /// The scheduler whose stages we count. Held so we don't rely on the
  /// app being reachable from the world.
  final Scheduler scheduler;

  /// Creates a start system rooted at [scheduler].
  SystemStatsStartSystem(this.scheduler);

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'debug_system_stats_start',
        resourceWrites: {SystemStats},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final stats = world.getResource<SystemStats>();
    if (stats == null) return Future.value();
    stats.frameStartMicros = _clock.elapsedMicroseconds;

    // Refresh the per-schedule counts. `Scheduler.getStage` returns
    // null for unregistered schedules — a schedule with zero systems
    // is reported as `0` rather than being omitted, so the overlay
    // can list every schedule consistently.
    stats.scheduleSystemCounts
      ..clear()
      ..addAll(_countSchedules(scheduler));
    return Future.value();
  }

  Map<String, int> _countSchedules(Scheduler scheduler) {
    final out = <String, int>{};
    for (final schedule in Schedules.all) {
      final stage = scheduler.getStage(schedule.name);
      out[schedule.name] = stage?.length ?? 0;
    }
    return out;
  }
}

/// Marks the end of the current frame's stats window.
///
/// Registered in `Schedules.last` by the plugin.
class SystemStatsEndSystem implements System {
  /// Creates an end system.
  const SystemStatsEndSystem();

  @override
  SystemMeta get meta => const SystemMeta(
        name: 'debug_system_stats_end',
        resourceWrites: {SystemStats},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final stats = world.getResource<SystemStats>();
    if (stats == null) return Future.value();
    stats.frameEndMicros = _clock.elapsedMicroseconds;
    return Future.value();
  }
}
