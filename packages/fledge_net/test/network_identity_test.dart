import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('NetworkIdentity', () {
    test('stores netId', () {
      final id = NetworkIdentity(netId: 42);
      expect(id.netId, 42);
    });

    test('defaults to host-owned with no authority', () {
      final id = NetworkIdentity(netId: 1);
      expect(id.ownerId, 0);
      expect(id.hasAuthority, false);
      expect(id.spawnType, isNull);
    });

    test('accepts all parameters', () {
      final id = NetworkIdentity(
        netId: 5,
        ownerId: 3,
        hasAuthority: true,
        spawnType: 'player',
      );
      expect(id.netId, 5);
      expect(id.ownerId, 3);
      expect(id.hasAuthority, true);
      expect(id.spawnType, 'player');
    });

    test('ownerId and hasAuthority are mutable', () {
      final id = NetworkIdentity(netId: 1);
      id.ownerId = 5;
      id.hasAuthority = true;
      expect(id.ownerId, 5);
      expect(id.hasAuthority, true);
    });
  });

  group('NetworkSyncConfig', () {
    test('defaults to empty sets and 20hz', () {
      final config = NetworkSyncConfig();
      expect(config.syncedComponents, isEmpty);
      expect(config.interpolatedComponents, isEmpty);
      expect(config.syncRate, 20);
    });

    test('accepts custom sync rate', () {
      final config = NetworkSyncConfig(syncRate: 60);
      expect(config.syncRate, 60);
    });
  });

  group('NetworkEntityRegistry', () {
    late NetworkEntityRegistry registry;
    late World world;

    setUp(() {
      registry = NetworkEntityRegistry();
      world = World();
    });

    test('starts empty', () {
      expect(registry.count, 0);
      expect(registry.entities, isEmpty);
    });

    test('generateNetId returns incrementing IDs', () {
      expect(registry.generateNetId(), 1);
      expect(registry.generateNetId(), 2);
      expect(registry.generateNetId(), 3);
    });

    test('register and getEntity', () {
      final entity = world.spawnWith([]);
      registry.register(entity, 10);

      expect(registry.getEntity(10), entity);
      expect(registry.count, 1);
    });

    test('register and getNetId', () {
      final entity = world.spawnWith([]);
      registry.register(entity, 10);

      expect(registry.getNetId(entity), 10);
    });

    test('isRegistered returns correct value', () {
      final entity = world.spawnWith([]);
      expect(registry.isRegistered(entity), false);

      registry.register(entity, 1);
      expect(registry.isRegistered(entity), true);
    });

    test('unregister removes entity', () {
      final entity = world.spawnWith([]);
      registry.register(entity, 5);
      expect(registry.count, 1);

      registry.unregister(entity);
      expect(registry.count, 0);
      expect(registry.getEntity(5), isNull);
      expect(registry.getNetId(entity), isNull);
      expect(registry.isRegistered(entity), false);
    });

    test('unregister is safe for unregistered entity', () {
      final entity = world.spawnWith([]);
      registry.unregister(entity); // should not throw
    });

    test('entities returns all registered entities', () {
      final e1 = world.spawnWith([]);
      final e2 = world.spawnWith([]);
      final e3 = world.spawnWith([]);

      registry.register(e1, 1);
      registry.register(e2, 2);
      registry.register(e3, 3);

      expect(registry.entities.toSet(), {e1, e2, e3});
    });

    test('clear removes all registrations', () {
      final e1 = world.spawnWith([]);
      final e2 = world.spawnWith([]);
      registry.register(e1, 1);
      registry.register(e2, 2);

      registry.clear();
      expect(registry.count, 0);
      expect(registry.getEntity(1), isNull);
      expect(registry.getEntity(2), isNull);
    });

    test('multiple entities with different net IDs', () {
      final entities = List.generate(10, (_) => world.spawnWith([]));
      for (var i = 0; i < entities.length; i++) {
        final netId = registry.generateNetId();
        registry.register(entities[i], netId);
      }

      expect(registry.count, 10);
      for (var i = 0; i < entities.length; i++) {
        expect(registry.getEntity(i + 1), entities[i]);
        expect(registry.getNetId(entities[i]), i + 1);
      }
    });
  });

  group('PendingSpawn', () {
    test('stores all fields', () {
      final spawn = PendingSpawn(
        netId: 5,
        spawnType: 'enemy',
        ownerId: 0,
        initialState: {'x': 10.0, 'y': 20.0},
      );
      expect(spawn.netId, 5);
      expect(spawn.spawnType, 'enemy');
      expect(spawn.ownerId, 0);
      expect(spawn.initialState['x'], 10.0);
    });

    test('auto-populates requestTime', () {
      final before = DateTime.now();
      final spawn = PendingSpawn(
        netId: 1,
        spawnType: 'test',
        ownerId: 0,
        initialState: {},
      );
      expect(spawn.requestTime.isAfter(before.subtract(const Duration(milliseconds: 1))), true);
    });
  });

  group('PendingDespawn', () {
    test('stores netId', () {
      final despawn = PendingDespawn(netId: 7);
      expect(despawn.netId, 7);
    });

    test('auto-populates requestTime', () {
      final before = DateTime.now();
      final despawn = PendingDespawn(netId: 1);
      expect(despawn.requestTime.isAfter(before.subtract(const Duration(milliseconds: 1))), true);
    });
  });
}
