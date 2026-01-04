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

class Marker {}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('Commands', () {
    group('spawn', () {
      test('spawns entity when applied', () {
        final world = World();
        final commands = Commands();

        commands.spawn().insert(Position(1, 2));

        expect(world.entityCount, equals(0));
        commands.apply(world);
        expect(world.entityCount, equals(1));
      });

      test('returns SpawnCommand with entity after apply', () {
        final world = World();
        final commands = Commands();

        final spawnCmd = commands.spawn()..insert(Position(1, 2));

        expect(spawnCmd.entity, isNull);
        commands.apply(world);
        expect(spawnCmd.entity, isNotNull);
        expect(world.isAlive(spawnCmd.entity!), isTrue);
      });

      test('spawns entity with multiple components', () {
        final world = World();
        final commands = Commands();

        final spawnCmd = commands.spawn()
          ..insert(Position(1, 2))
          ..insert(Velocity(3, 4));
        commands.apply(world);

        expect(world.has<Position>(spawnCmd.entity!), isTrue);
        expect(world.has<Velocity>(spawnCmd.entity!), isTrue);
      });
    });

    group('despawn', () {
      test('despawns entity when applied', () {
        final world = World();
        final entity = world.spawnWith([Position(0, 0)]);
        final commands = Commands();

        commands.despawn(entity);

        expect(world.isAlive(entity), isTrue);
        commands.apply(world);
        expect(world.isAlive(entity), isFalse);
      });
    });

    group('insert', () {
      test('inserts component when applied', () {
        final world = World();
        final entity = world.spawnWith([Position(0, 0)]);
        final commands = Commands();

        commands.insert(entity, Velocity(1, 1));

        expect(world.has<Velocity>(entity), isFalse);
        commands.apply(world);
        expect(world.has<Velocity>(entity), isTrue);
      });

      test('does nothing for despawned entity', () {
        final world = World();
        final entity = world.spawnWith([Position(0, 0)]);
        world.despawn(entity);
        final commands = Commands();

        commands.insert(entity, Velocity(1, 1));
        commands.apply(world);

        // Should not throw
      });
    });

    group('remove', () {
      test('removes component when applied', () {
        final world = World();
        final entity = world.spawnWith([Position(0, 0), Velocity(1, 1)]);
        final commands = Commands();

        commands.remove<Velocity>(entity);

        expect(world.has<Velocity>(entity), isTrue);
        commands.apply(world);
        expect(world.has<Velocity>(entity), isFalse);
      });
    });

    group('custom', () {
      test('executes custom action', () {
        final world = World();
        var executed = false;
        final commands = Commands();

        commands.custom((world) {
          executed = true;
        });

        expect(executed, isFalse);
        commands.apply(world);
        expect(executed, isTrue);
      });
    });

    group('command ordering', () {
      test('commands execute in order', () {
        final world = World();
        final commands = Commands();
        final order = <String>[];

        commands.custom((_) => order.add('first'));
        commands.custom((_) => order.add('second'));
        commands.custom((_) => order.add('third'));

        commands.apply(world);

        expect(order, equals(['first', 'second', 'third']));
      });

      test('spawn then modify works', () {
        final world = World();
        final commands = Commands();

        final spawnCmd = commands.spawn()..insert(Position(0, 0));
        // Note: Can't use spawnCmd.entity here since it's not set yet
        // Must use custom command to get the entity after spawn
        commands.custom((world) {
          world.insert(spawnCmd.entity!, Velocity(1, 1));
        });

        commands.apply(world);

        expect(world.has<Velocity>(spawnCmd.entity!), isTrue);
      });
    });

    group('clear', () {
      test('clears queue without executing', () {
        final world = World();
        final commands = Commands();

        commands.spawn().insert(Position(0, 0));
        commands.spawn().insert(Position(1, 1));

        expect(commands.length, equals(2));
        commands.clear();
        expect(commands.isEmpty, isTrue);

        commands.apply(world);
        expect(world.entityCount, equals(0));
      });
    });

    group('isEmpty/isNotEmpty', () {
      test('isEmpty is true for new Commands', () {
        final commands = Commands();
        expect(commands.isEmpty, isTrue);
        expect(commands.isNotEmpty, isFalse);
      });

      test('isNotEmpty after adding command', () {
        final commands = Commands();
        commands.spawn();
        expect(commands.isEmpty, isFalse);
        expect(commands.isNotEmpty, isTrue);
      });

      test('isEmpty after apply', () {
        final world = World();
        final commands = Commands();
        commands.spawn();
        commands.apply(world);
        expect(commands.isEmpty, isTrue);
      });
    });
  });
}
