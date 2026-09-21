import 'package:fledge_ecs/fledge_ecs.dart';

import '../components/tilemap_animator.dart';

/// System that updates tile animations.
///
/// Uses the [WallTime] resource for delta time to advance
/// all [TilemapAnimator] components each frame.
///
/// This system should run in the update stage after WallTimePlugin
/// has updated the WallTime resource.
class TileAnimationSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'tile_animation',
        writes: {ComponentId.of<TilemapAnimator>()},
        resourceReads: {WallTime},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<WallTime>();
    if (time == null) return;

    for (final (_, animator) in world.query1<TilemapAnimator>().iter()) {
      animator.update(time.delta);
    }
  }
}
