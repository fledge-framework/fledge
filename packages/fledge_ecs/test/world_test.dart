import 'package:fledge_ecs/src/component.dart';
import 'package:fledge_ecs/src/entity.dart';
import 'package:fledge_ecs/src/world.dart';
import 'package:test/test.dart';

class Position {
  double x, y;
  Position(this.x, this.y);

  @override
  String toString() => 'Position($x, $y)';
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);

  @override
  String toString() => 'Velocity($dx, $dy)';
}

class Sprite {
  String name;
  Sprite(this.name);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('World', () {
    group('spawn', () {
      test('creates entity with no components', () {
        final world = World();

        final entity = world.spawn().entity;

        expect(world.isAlive(entity), isTrue);
        expect(world.entityCount, equals(1));
      });

      test('returns EntityCommands for fluent API', () {
        final world = World();

        final entity = world.spawn().insert(Position(1, 2)).entity;

        expect(world.get<Position>(entity)?.x, equals(1));
        expect(world.get<Position>(entity)?.y, equals(2));
      });

      test('sequential spawns get different IDs', () {
        final world = World();

        final e1 = world.spawn().entity;
        final e2 = world.spawn().entity;
        final e3 = world.spawn().entity;

        expect(e1.id, isNot(equals(e2.id)));
        expect(e2.id, isNot(equals(e3.id)));
      });
    });

    group('spawnWith', () {
      test('spawns entity with multiple components', () {
        final world = World();

        final entity = world.spawnWith([
          Position(1, 2),
          Velocity(3, 4),
        ]);

        expect(world.isAlive(entity), isTrue);
        expect(world.get<Position>(entity)?.x, equals(1));
        expect(world.get<Velocity>(entity)?.dx, equals(3));
      });

      test('spawns with empty list creates entity in empty archetype', () {
        final world = World();

        final entity = world.spawnWith([]);

        expect(world.isAlive(entity), isTrue);
        expect(world.has<Position>(entity), isFalse);
      });
    });

    group('despawn', () {
      test('removes entity from world', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;

        final result = world.despawn(entity);

        expect(result, isTrue);
        expect(world.isAlive(entity), isFalse);
        expect(world.entityCount, equals(0));
      });

      test('returns false for already despawned entity', () {
        final world = World();
        final entity = world.spawn().entity;

        world.despawn(entity);
        final result = world.despawn(entity);

        expect(result, isFalse);
      });

      test('returns false for entity with wrong generation', () {
        final world = World();
        final e1 = world.spawn().entity;
        world.despawn(e1);
        final e2 = world.spawn().entity; // Reuses e1's id

        // Try to despawn with old generation
        final result = world.despawn(e1);

        expect(result, isFalse);
        expect(world.isAlive(e2), isTrue);
      });
    });

    group('get', () {
      test('returns component for alive entity', () {
        final world = World();
        final pos = Position(5, 10);
        final entity = world.spawn().insert(pos).entity;

        final retrieved = world.get<Position>(entity);

        expect(retrieved, same(pos));
      });

      test('returns null for missing component', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;

        expect(world.get<Velocity>(entity), isNull);
      });

      test('returns null for despawned entity', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;
        world.despawn(entity);

        expect(world.get<Position>(entity), isNull);
      });
    });

    group('has', () {
      test('returns true for present component', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;

        expect(world.has<Position>(entity), isTrue);
      });

      test('returns false for missing component', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;

        expect(world.has<Velocity>(entity), isFalse);
      });

      test('returns false for despawned entity', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;
        world.despawn(entity);

        expect(world.has<Position>(entity), isFalse);
      });
    });

    group('insert', () {
      test('adds new component to entity', () {
        final world = World();
        final entity = world.spawn().entity;

        world.insert(entity, Position(1, 2));

        expect(world.has<Position>(entity), isTrue);
        expect(world.get<Position>(entity)?.x, equals(1));
      });

      test('replaces existing component', () {
        final world = World();
        final entity = world.spawn().insert(Position(1, 2)).entity;

        world.insert(entity, Position(10, 20));

        expect(world.get<Position>(entity)?.x, equals(10));
        expect(world.get<Position>(entity)?.y, equals(20));
      });

      test('moves entity to new archetype', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;

        world.insert(entity, Velocity(1, 1));

        expect(world.has<Position>(entity), isTrue);
        expect(world.has<Velocity>(entity), isTrue);
      });

      test('throws for despawned entity', () {
        final world = World();
        final entity = world.spawn().entity;
        world.despawn(entity);

        expect(
          () => world.insert(entity, Position(0, 0)),
          throwsStateError,
        );
      });
    });

    group('remove', () {
      test('removes component from entity', () {
        final world = World();
        final entity = world.spawn().insert(Position(1, 2)).entity;

        final removed = world.remove<Position>(entity);

        expect(removed, isNotNull);
        expect(removed?.x, equals(1));
        expect(world.has<Position>(entity), isFalse);
      });

      test('returns null for missing component', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;

        final removed = world.remove<Velocity>(entity);

        expect(removed, isNull);
      });

      test('returns null for despawned entity', () {
        final world = World();
        final entity = world.spawn().insert(Position(0, 0)).entity;
        world.despawn(entity);

        expect(world.remove<Position>(entity), isNull);
      });

      test('preserves other components', () {
        final world = World();
        final entity = world.spawnWith([
          Position(1, 2),
          Velocity(3, 4),
          Sprite('test'),
        ]);

        world.remove<Velocity>(entity);

        expect(world.has<Position>(entity), isTrue);
        expect(world.has<Velocity>(entity), isFalse);
        expect(world.has<Sprite>(entity), isTrue);
      });
    });

    group('entity recycling', () {
      test('reuses entity IDs after despawn', () {
        final world = World();
        final e1 = world.spawn().entity;
        world.despawn(e1);
        final e2 = world.spawn().entity;

        expect(e2.id, equals(e1.id));
        expect(e2.generation, equals(e1.generation + 1));
      });

      test('stale references dont affect new entities', () {
        final world = World();
        final e1 = world.spawn().insert(Position(1, 1)).entity;
        world.despawn(e1);
        final e2 = world.spawn().insert(Position(2, 2)).entity;

        // e1 is stale, should not access e2's data
        expect(world.get<Position>(e1), isNull);
        expect(world.get<Position>(e2)?.x, equals(2));
      });
    });

    group('multiple entities', () {
      test('handles many entities with same archetype', () {
        final world = World();
        final entities = <Entity>[];

        for (int i = 0; i < 100; i++) {
          entities.add(world.spawnWith([Position(i.toDouble(), 0)]));
        }

        expect(world.entityCount, equals(100));

        for (int i = 0; i < 100; i++) {
          expect(world.get<Position>(entities[i])?.x, equals(i.toDouble()));
        }
      });

      test('handles entities with different archetypes', () {
        final world = World();

        final e1 = world.spawnWith([Position(1, 0)]);
        final e2 = world.spawnWith([Velocity(2, 0)]);
        final e3 = world.spawnWith([Position(3, 0), Velocity(3, 0)]);

        expect(world.get<Position>(e1)?.x, equals(1));
        expect(world.get<Velocity>(e2)?.dx, equals(2));
        expect(world.get<Position>(e3)?.x, equals(3));
        expect(world.get<Velocity>(e3)?.dx, equals(3));
      });

      test('despawning updates other entity locations', () {
        final world = World();
        final e1 = world.spawnWith([Position(1, 0)]);
        final e2 = world.spawnWith([Position(2, 0)]);
        final e3 = world.spawnWith([Position(3, 0)]);

        world.despawn(e1);

        // e3 was swapped into e1's slot
        expect(world.get<Position>(e3)?.x, equals(3));
        expect(world.get<Position>(e2)?.x, equals(2));
      });
    });

    group('clear', () {
      test('removes all entities', () {
        final world = World();
        world.spawnWith([Position(1, 0)]);
        world.spawnWith([Position(2, 0)]);
        world.spawnWith([Position(3, 0)]);

        world.clear();

        expect(world.entityCount, equals(0));
      });
    });
  });
}
