// Regression tests for archetype-mutation-mid-iteration correctness.
//
// Prior to Task 13, `world.queryN().iter()` walked archetype tables lazily,
// which meant that if a system inserted a component on an entity during
// iteration the entity's swap-remove out of its source table silently
// dropped it from the yielded sequence. That bit `TransformPropagateSystem`
// (adding `GlobalTransform2D` on the fly): the next query for the entity's
// new archetype saw fewer entities than expected.
//
// The fix is Approach A — snapshot matching entities at iter start and
// resolve their current location + validate archetype match on each yield.
// These tests pin that behavior.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class ComponentA {
  int value;
  ComponentA([this.value = 0]);
}

class ComponentB {
  int value;
  ComponentB([this.value = 0]);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('archetype mutation during iteration', () {
    test('inserting a component during iteration does not drop the entity '
        'from a later query', () {
      final world = World();

      // Spawn 10 entities with A but no B.
      final spawned = <Entity>[];
      for (int i = 0; i < 10; i++) {
        final commands = world.spawn()..insert(ComponentA(i));
        spawned.add(commands.entity);
      }

      // System 1 analogue: iterate entities with A and no B, insert B on each.
      // The `Without<ComponentB>` filter ensures we only touch not-yet-migrated
      // entities. Under the old iterator, adding B mid-iter migrated entities
      // to a different archetype and left the "current archetype" iterator
      // out of sync — silently skipping half the entities.
      for (final (e, _)
          in world
              .query1<ComponentA>(filter: const Without<ComponentB>())
              .iter()) {
        world.insert(e, ComponentB(0));
      }

      // System 2 analogue: iterate query<A, B>. Should see all 10 entities.
      final seen = <Entity>[];
      for (final (e, _, _) in world.query2<ComponentA, ComponentB>().iter()) {
        seen.add(e);
      }
      expect(seen.length, equals(10));
      expect(seen.toSet(), equals(spawned.toSet()));
    });

    test('modification during a single iter must not double-visit', () {
      final world = World();

      final spawned = <Entity>[];
      for (int i = 0; i < 20; i++) {
        final commands = world.spawn()..insert(ComponentA(i));
        spawned.add(commands.entity);
      }

      // Iterate query<A> and insert B on each entity inside the loop.
      // Because the snapshot is taken at iter start, each entity is visited
      // exactly once even though every insert migrates it to a new archetype.
      final visitCount = <Entity, int>{};
      for (final (e, _) in world.query1<ComponentA>().iter()) {
        visitCount[e] = (visitCount[e] ?? 0) + 1;
        world.insert(e, ComponentB(0));
      }

      expect(
        visitCount.length,
        equals(20),
        reason: 'every entity should be visited',
      );
      for (final entry in visitCount.entries) {
        expect(
          entry.value,
          equals(1),
          reason: '${entry.key} was visited ${entry.value} times, expected 1',
        );
      }
    });

    test('removal during iter must not crash', () {
      final world = World();

      for (int i = 0; i < 15; i++) {
        world.spawn().insert(ComponentA(i));
      }

      // Remove A from every third entity during iteration. The iterator
      // should complete without throwing; entities whose A was removed
      // are simply skipped (they no longer match).
      final visited = <Entity>[];
      int i = 0;
      for (final (e, _) in world.query1<ComponentA>().iter()) {
        visited.add(e);
        if (i % 3 == 0) {
          world.remove<ComponentA>(e);
        }
        i++;
      }

      // We shouldn't have crashed. The iterator visits each entity that
      // was in the snapshot at iter start, but skips ones that had A
      // removed *before* their yield.
      expect(visited, isNotEmpty);
    });

    test('despawn during iteration is safely skipped', () {
      final world = World();

      final entities = <Entity>[];
      for (int i = 0; i < 10; i++) {
        entities.add((world.spawn()..insert(ComponentA(i))).entity);
      }

      // Despawn every entity as we visit it. The snapshot yields each
      // entity at most once; we then despawn it. Subsequent yields for
      // already-despawned entities are impossible (each is only in the
      // snapshot once), but if any hypothetical yield hit a dead entity
      // the iterator would just skip it.
      int count = 0;
      for (final (e, _) in world.query1<ComponentA>().iter()) {
        expect(world.isAlive(e), isTrue);
        world.despawn(e);
        count++;
      }
      expect(count, equals(10));
      expect(world.entityCount, equals(0));
    });

    test('newly spawned entities during iter are NOT observed by the '
        'current iterator (snapshot semantics)', () {
      final world = World();

      for (int i = 0; i < 5; i++) {
        world.spawn().insert(ComponentA(i));
      }

      // While iterating, spawn 5 more matching entities. These should
      // NOT be observed by this iterator — that's the semantics of the
      // snapshot. They will be visible to any subsequent query.
      int seenDuringIter = 0;
      for (final (_, _) in world.query1<ComponentA>().iter()) {
        world.spawn().insert(ComponentA(99));
        seenDuringIter++;
      }

      expect(
        seenDuringIter,
        equals(5),
        reason: 'iterator should only yield the pre-iter entities',
      );
      // But a subsequent query sees all 10.
      expect(world.query1<ComponentA>().count(), equals(10));
    });
  });
}
