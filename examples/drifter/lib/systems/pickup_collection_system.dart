import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';

import '../components.dart';
import '../resources.dart';

/// Drains this frame's `CollisionEvent`s on the player, despawns any
/// collided pickups, and bumps the run score + high score.
///
/// Must run after `CollisionDetectionSystem` (so this frame's events
/// exist) and before `CollisionCleanupSystem` (which is at
/// `CoreStage.last`). Since detection is `CoreStage.update`, registering
/// this system in `CoreStage.update` after the physics plugin keeps it
/// ordered correctly.
class PickupCollectionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'PickupCollectionSystem',
        reads: {
          ComponentId.of<Player>(),
          ComponentId.of<Pickup>(),
          ComponentId.of<CollisionEvent>(),
        },
        resourceWrites: {RunScore, HighScore},
        // The events we consume are produced by `collision_detection`
        // this frame. Note: the registered system name is the
        // snake_case one, not the class name.
        after: const ['collision_detection'],
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final run = world.getResource<RunScore>();
    final high = world.getResource<HighScore>();
    if (run == null || high == null) return;

    final toDespawn = <Entity>{};

    // Each collision fires bidirectionally, so querying on the player
    // side gives us every (player, pickup) pair in one pass.
    for (final (_, event, _) in world.query2<CollisionEvent, Player>().iter()) {
      final other = event.other;
      if (!world.has<Pickup>(other)) continue;
      toDespawn.add(other);
    }

    for (final pickup in toDespawn) {
      world.despawn(pickup);
      run.value++;
      if (run.value > high.value) high.value = run.value;
    }
  }
}
