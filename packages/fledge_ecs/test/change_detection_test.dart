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

class Health {
  int value;
  Health(this.value);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('Tick', () {
    test('starts at zero', () {
      final tick = Tick();
      expect(tick.value, equals(0));
    });

    test('advances by one', () {
      final tick = Tick();
      tick.advance();
      expect(tick.value, equals(1));
      tick.advance();
      expect(tick.value, equals(2));
    });

    test('resets to zero', () {
      final tick = Tick();
      tick.advance();
      tick.advance();
      tick.reset();
      expect(tick.value, equals(0));
    });
  });

  group('ComponentTicks', () {
    test('created with added factory', () {
      final ticks = ComponentTicks.added(5);
      expect(ticks.addedTick, equals(5));
      expect(ticks.changedTick, equals(5));
    });

    test('isAdded returns true for newer tick', () {
      final ticks = ComponentTicks.added(5);
      expect(ticks.isAdded(4), isTrue);
      expect(ticks.isAdded(5), isFalse);
      expect(ticks.isAdded(6), isFalse);
    });

    test('isChanged returns true for newer tick', () {
      final ticks = ComponentTicks.added(5);
      expect(ticks.isChanged(4), isTrue);
      expect(ticks.isChanged(5), isFalse);
      expect(ticks.isChanged(6), isFalse);
    });

    test('markChanged updates changedTick', () {
      final ticks = ComponentTicks.added(5);
      ticks.markChanged(10);
      expect(ticks.addedTick, equals(5));
      expect(ticks.changedTick, equals(10));
      expect(ticks.isChanged(9), isTrue);
      expect(ticks.isChanged(10), isFalse);
    });
  });

  group('World tick', () {
    test('world has tick', () {
      final world = World();
      expect(world.currentTick, equals(0));
    });

    test('world advances tick', () {
      final world = World();
      world.advanceTick();
      expect(world.currentTick, equals(1));
    });

    test('spawned entities have correct added tick', () {
      final world = World();
      final entity = world.spawnWith([Position(0, 0)]);

      final location = world.entities.getLocation(entity);
      final table = world.archetypes.tableAt(location!.archetypeIndex);
      final ticks = table.getTicks(location.row, ComponentId.of<Position>());

      expect(ticks, isNotNull);
      expect(ticks!.addedTick, equals(0));
      expect(ticks.changedTick, equals(0));
    });

    test('inserted component updates changed tick', () {
      final world = World();
      final entity = world.spawnWith([Position(0, 0)]);

      world.advanceTick();
      expect(world.currentTick, equals(1));

      // Update the component
      world.insert(entity, Position(5, 5));

      final location = world.entities.getLocation(entity);
      final table = world.archetypes.tableAt(location!.archetypeIndex);
      final ticks = table.getTicks(location.row, ComponentId.of<Position>());

      expect(ticks!.addedTick, equals(0));
      expect(ticks.changedTick, equals(1));
    });
  });

  group('Added filter', () {
    test('Added filter finds newly spawned entities', () {
      final world = World();

      // Spawn entities at tick 0
      world.spawnWith([Position(0, 0)]);
      world.spawnWith([Position(1, 1)]);

      // Query with Added filter - lastSeenTick is 0 by default
      // Since entities were added at tick 0, and lastSeenTick is 0,
      // isAdded(0) returns false. We need to set lastSeenTick to -1
      final query = world.query1<Position>(filter: const Added<Position>());

      // Initially nothing passes because lastSeenTick=0 and addedTick=0
      expect(query.count(), equals(0));

      // Advance tick and spawn new entity
      world.advanceTick();
      world.spawnWith([Position(2, 2)]);

      // Now the new entity should be found (addedTick=1 > lastSeenTick=0)
      expect(query.count(), equals(1));
    });

    test('Added filter state tracks last seen tick', () {
      final world = World();

      // Create a query and cache its state
      final query = world.query1<Position>(filter: const Added<Position>());
      final state = query.state;

      // Initially lastSeenTick is 0
      expect(state.lastSeenTick, equals(0));

      // Advance world tick
      world.advanceTick();

      // Spawn entity at tick 1
      world.spawnWith([Position(0, 0)]);

      // Query finds it (addedTick=1 > lastSeenTick=0)
      expect(query.count(), equals(1));

      // Update lastSeenTick
      state.updateLastSeenTick(world.currentTick);
      expect(state.lastSeenTick, equals(1));

      // Now the same entity is not found
      expect(query.count(), equals(0));
    });
  });

  group('Changed filter', () {
    test('Changed filter finds modified entities', () {
      final world = World();

      // Spawn entity at tick 0
      final entity = world.spawnWith([Position(0, 0)]);

      // Advance tick
      world.advanceTick();

      // Create query with Changed filter
      final query = world.query1<Position>(filter: const Changed<Position>());

      // Entity was added at tick 0, so changedTick=0, not changed yet
      expect(query.count(), equals(0));

      // Modify the component at tick 1
      world.insert(entity, Position(5, 5));

      // Now it shows up (changedTick=1 > lastSeenTick=0)
      expect(query.count(), equals(1));

      // Update lastSeenTick
      query.state.updateLastSeenTick(world.currentTick);

      // No longer changed
      expect(query.count(), equals(0));
    });

    test('Changed filter includes newly added entities', () {
      final world = World();

      // Advance tick first
      world.advanceTick();

      // Spawn entity at tick 1
      world.spawnWith([Position(0, 0)]);

      // Query with Changed filter (lastSeenTick=0)
      final query = world.query1<Position>(filter: const Changed<Position>());

      // New entity is considered changed (changedTick=1 > lastSeenTick=0)
      expect(query.count(), equals(1));
    });
  });

  group('Table tick operations', () {
    test('extractTicks preserves tick data', () {
      final world = World();
      final entity = world.spawnWith([Position(0, 0), Velocity(1, 1)]);

      world.advanceTick();
      world.insert(entity, Position(5, 5));

      final location = world.entities.getLocation(entity);
      final table = world.archetypes.tableAt(location!.archetypeIndex);
      final ticks = table.extractTicks(location.row);

      expect(ticks[ComponentId.of<Position>()]!.addedTick, equals(0));
      expect(ticks[ComponentId.of<Position>()]!.changedTick, equals(1));
      expect(ticks[ComponentId.of<Velocity>()]!.addedTick, equals(0));
      expect(ticks[ComponentId.of<Velocity>()]!.changedTick, equals(0));
    });

    test('archetype migration preserves ticks', () {
      final world = World();
      final entity = world.spawnWith([Position(0, 0)]);

      world.advanceTick();

      // Modify position
      world.insert(entity, Position(5, 5));

      // Add new component, triggering migration
      world.insert(entity, Velocity(1, 1));

      final location = world.entities.getLocation(entity);
      final table = world.archetypes.tableAt(location!.archetypeIndex);

      // Original position ticks should be preserved
      final posTicks = table.getTicks(location.row, ComponentId.of<Position>());
      expect(posTicks!.addedTick, equals(0));
      expect(posTicks.changedTick, equals(1));

      // New velocity has current tick
      final velTicks = table.getTicks(location.row, ComponentId.of<Velocity>());
      expect(velTicks!.addedTick, equals(1));
      expect(velTicks.changedTick, equals(1));
    });
  });

  group('App tick integration', () {
    test('app advances tick each frame', () async {
      final app = App();

      expect(app.world.currentTick, equals(0));

      await app.tick();
      expect(app.world.currentTick, equals(1));

      await app.tick();
      expect(app.world.currentTick, equals(2));
    });
  });
}
