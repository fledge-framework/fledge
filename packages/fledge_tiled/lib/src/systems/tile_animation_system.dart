import 'package:fledge_ecs/fledge_ecs.dart';

import '../components/tilemap_animator.dart';

/// System that updates tile animations.
///
/// Uses the [WallTime] resource for delta time to advance
/// all [TilemapAnimator] components each frame.
///
/// `TiledPlugin` adds it to `Schedules.update`; `WallTime` is advanced in
/// `Schedules.first` by `WallTimePlugin`, which the app must add.
class TileAnimationSystem implements System {
  /// The `SystemMeta.name` of [TileAnimationSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'tile_animation';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<TilemapAnimator>()},
    resourceReads: {WallTime},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final time = world.getResource<WallTime>();
    if (time == null) return;

    for (final (_, animator) in world.query1<TilemapAnimator>().iter()) {
      animator.update(time.delta);
    }
  }
}
