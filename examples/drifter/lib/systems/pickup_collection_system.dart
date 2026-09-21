import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';

import '../components.dart';
import '../resources.dart';

/// Drains this frame's `CollisionEvent`s that involve the player,
/// despawns any collided pickups, and bumps the run score + high score.
///
/// Reads from the ECS event queue (`world.eventReader<CollisionEvent>()`)
/// rather than a per-entity component, so archetype churn on collisions
/// is zero and multiple collisions per frame all survive.
///
/// Ordering: must run after `collision_detection` so we see the events
/// it produced this frame — `SystemMeta.after` pins that explicitly.
class PickupCollectionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'PickupCollectionSystem',
        reads: {
          ComponentId.of<Player>(),
          ComponentId.of<Pickup>(),
        },
        eventReads: {CollisionEvent},
        resourceWrites: {RunScore, HighScore},
        // The events we consume are produced by `collision_detection`
        // (last frame; the queue is double-buffered). Even though the
        // read/write cross frames semantically, we still declare
        // `after: ['collision_detection']` so the ordering intent is
        // explicit and `checkScheduleOrdering()` sees no ambiguity.
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

    // Each collision produces exactly one event (unordered pair). Look
    // for a (player, pickup) pair on either side.
    for (final evt in world.eventReader<CollisionEvent>().read()) {
      final Entity? pickup;
      if (world.has<Player>(evt.entityA) && world.has<Pickup>(evt.entityB)) {
        pickup = evt.entityB;
      } else if (world.has<Player>(evt.entityB) &&
          world.has<Pickup>(evt.entityA)) {
        pickup = evt.entityA;
      } else {
        pickup = null;
      }
      if (pickup != null) toDespawn.add(pickup);
    }

    for (final pickup in toDespawn) {
      world.despawn(pickup);
      run.value++;
      if (run.value > high.value) high.value = run.value;
    }
  }
}
