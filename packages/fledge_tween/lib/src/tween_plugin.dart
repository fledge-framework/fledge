import 'package:fledge_ecs/fledge_ecs.dart';

import 'tween_system.dart';

/// Which schedule [TweenSystem] runs in.
///
/// Wall-time gives smooth visual animation and is the right default for
/// most tweens (menu fades, camera moves, UI transitions). Fixed-timestep
/// gives deterministic behaviour and is the right choice when a tween
/// drives physics, replay-critical state, or networked-replicated
/// values.
enum TweenSchedule {
  /// Run in [Schedules.update] — advances by variable frame delta.
  wall,

  /// Run in [Schedules.fixedUpdate] — advances by the fixed timestep.
  fixed,
}

/// Plugin that installs the [TweenSystem] on either the wall-time or
/// fixed-timestep update schedule.
///
/// The plugin registers no resources of its own — [TweenSystem] reads
/// the [WallTime] resource that `WallTimePlugin` populates, so games
/// should still add `WallTimePlugin` (or otherwise maintain a
/// [WallTime] resource) for tweens to advance.
///
/// ```dart
/// App()
///   ..addPlugin(WallTimePlugin())
///   ..addPlugin(const TweenPlugin());
///
/// // Or, for a deterministic / physics-driving tween:
/// App()
///   ..addPlugin(WallTimePlugin())
///   ..addPlugin(const TweenPlugin(schedule: TweenSchedule.fixed));
/// ```
class TweenPlugin implements Plugin {
  /// Which schedule [TweenSystem] runs in.
  final TweenSchedule schedule;

  /// Creates the tween plugin.
  const TweenPlugin({this.schedule = TweenSchedule.wall});

  @override
  void build(App app) {
    app.addSystem(
      TweenSystem(),
      schedule: schedule == TweenSchedule.wall
          ? Schedules.update
          : Schedules.fixedUpdate,
    );
  }

  @override
  void cleanup() {}
}
