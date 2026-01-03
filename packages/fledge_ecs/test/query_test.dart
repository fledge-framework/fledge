import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Sprite {
  String name;
  Sprite(this.name);
}

class Player {}

class Enemy {}

class Static {}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('Query1', () {
    test('iterates over entities with single component', () {
      final world = World();
      world.spawnWith([Position(1, 0)]);
      world.spawnWith([Position(2, 0)]);
      world.spawnWith([Position(3, 0)]);

      final results = world.query1<Position>().iter().toList();

      expect(results.length, equals(3));
      expect(results.map((r) => r.$2.x).toSet(), equals({1, 2, 3}));
    });

    test('returns empty for no matches', () {
      final world = World();
      world.spawnWith([Velocity(1, 0)]);

      final results = world.query1<Position>().iter().toList();

      expect(results, isEmpty);
    });

    test('single() returns first match', () {
      final world = World();
      world.spawnWith([Position(1, 0)]);
      world.spawnWith([Position(2, 0)]);

      final result = world.query1<Position>().single();

      expect(result, isNotNull);
      expect(result!.$2.x, anyOf(equals(1), equals(2)));
    });

    test('single() returns null for no matches', () {
      final world = World();

      final result = world.query1<Position>().single();

      expect(result, isNull);
    });

    test('count() returns number of matches', () {
      final world = World();
      world.spawnWith([Position(1, 0)]);
      world.spawnWith([Position(2, 0)]);
      world.spawnWith([Velocity(3, 0)]);

      expect(world.query1<Position>().count(), equals(2));
      expect(world.query1<Velocity>().count(), equals(1));
      expect(world.query1<Sprite>().count(), equals(0));
    });
  });

  group('Query2', () {
    test('iterates over entities with both components', () {
      final world = World();
      world.spawnWith([Position(1, 0), Velocity(10, 0)]);
      world.spawnWith([Position(2, 0), Velocity(20, 0)]);
      world.spawnWith([Position(3, 0)]); // No Velocity

      final results = world.query2<Position, Velocity>().iter().toList();

      expect(results.length, equals(2));
    });

    test('components are mutable references', () {
      final world = World();
      final entity = world.spawnWith([Position(0, 0), Velocity(1, 1)]);

      for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
        pos.x += vel.dx;
        pos.y += vel.dy;
      }

      expect(world.get<Position>(entity)?.x, equals(1));
      expect(world.get<Position>(entity)?.y, equals(1));
    });
  });

  group('Query3', () {
    test('iterates over entities with all three components', () {
      final world = World();
      world.spawnWith([Position(1, 0), Velocity(1, 0), Sprite('a')]);
      world.spawnWith([Position(2, 0), Velocity(2, 0), Sprite('b')]);
      world.spawnWith([Position(3, 0), Velocity(3, 0)]); // No Sprite

      final results =
          world.query3<Position, Velocity, Sprite>().iter().toList();

      expect(results.length, equals(2));
    });
  });

  group('Query4', () {
    test('iterates over entities with all four components', () {
      final world = World();
      world.spawnWith([Position(1, 0), Velocity(1, 0), Sprite('a'), Player()]);
      world.spawnWith(
          [Position(2, 0), Velocity(2, 0), Sprite('b')]); // No Player

      final results =
          world.query4<Position, Velocity, Sprite, Player>().iter().toList();

      expect(results.length, equals(1));
    });
  });

  group('With filter', () {
    test('filters entities that have the required component', () {
      final world = World();
      world.spawnWith([Position(1, 0), Player()]);
      world.spawnWith([Position(2, 0), Enemy()]);
      world.spawnWith([Position(3, 0)]);

      final results =
          world.query1<Position>(filter: const With<Player>()).iter().toList();

      expect(results.length, equals(1));
      expect(results[0].$2.x, equals(1));
    });
  });

  group('Without filter', () {
    test('filters entities that dont have the excluded component', () {
      final world = World();
      world.spawnWith([Position(1, 0), Static()]);
      world.spawnWith([Position(2, 0)]);
      world.spawnWith([Position(3, 0)]);

      final results = world
          .query1<Position>(filter: const Without<Static>())
          .iter()
          .toList();

      expect(results.length, equals(2));
      expect(results.map((r) => r.$2.x).toSet(), equals({2, 3}));
    });
  });

  group('Query caching', () {
    test('updates cache when new archetypes are created', () {
      final world = World();
      final query = world.query1<Position>();

      // Query before any entities
      expect(query.count(), equals(0));

      // Add entity
      world.spawnWith([Position(1, 0)]);

      // Query should find new entity
      expect(query.count(), equals(1));

      // Add entity with different archetype
      world.spawnWith([Position(2, 0), Velocity(1, 0)]);

      // Query should find both
      expect(query.count(), equals(2));
    });
  });

  group('Multiple archetypes', () {
    test('query iterates across archetypes', () {
      final world = World();
      // Different archetypes, all have Position
      world.spawnWith([Position(1, 0)]);
      world.spawnWith([Position(2, 0), Velocity(1, 0)]);
      world.spawnWith([Position(3, 0), Sprite('a')]);
      world.spawnWith([Position(4, 0), Velocity(1, 0), Sprite('b')]);

      final results = world.query1<Position>().iter().toList();

      expect(results.length, equals(4));
      expect(results.map((r) => r.$2.x).toSet(), equals({1, 2, 3, 4}));
    });
  });

  group('Entity access', () {
    test('query provides entity reference', () {
      final world = World();
      final e1 = world.spawnWith([Position(1, 0)]);
      final e2 = world.spawnWith([Position(2, 0)]);

      final entities = world.query1<Position>().iter().map((r) => r.$1).toSet();

      expect(entities, contains(e1));
      expect(entities, contains(e2));
    });

    test('can use entity from query to access other components', () {
      final world = World();
      world.spawnWith([Position(1, 0), Velocity(10, 0), Sprite('player')]);

      for (final (entity, _) in world.query1<Position>().iter()) {
        final sprite = world.get<Sprite>(entity);
        expect(sprite?.name, equals('player'));
      }
    });
  });

  group('Edge cases', () {
    test('empty world returns empty results', () {
      final world = World();

      expect(world.query1<Position>().isEmpty, isTrue);
      expect(world.query2<Position, Velocity>().isEmpty, isTrue);
    });

    test('query after despawn excludes despawned entities', () {
      final world = World();
      final e1 = world.spawnWith([Position(1, 0)]);
      world.spawnWith([Position(2, 0)]);

      world.despawn(e1);

      final results = world.query1<Position>().iter().toList();
      expect(results.length, equals(1));
      expect(results[0].$2.x, equals(2));
    });

    test('query after component removal updates correctly', () {
      final world = World();
      final entity = world.spawnWith([Position(1, 0), Velocity(1, 0)]);

      expect(world.query2<Position, Velocity>().count(), equals(1));

      world.remove<Velocity>(entity);

      expect(world.query2<Position, Velocity>().count(), equals(0));
      expect(world.query1<Position>().count(), equals(1));
    });
  });
}
