import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Simple position component for testing.
class _Position {
  double x;
  double y;
  _Position(this.x, this.y);
}

void main() {
  setUp(() {
    ComponentId.resetRegistry();
  });

  group('InterestManager', () {
    test('with no positionGetter, all entities are relevant', () {
      final manager = InterestManager();
      final world = World();
      final registry = NetworkEntityRegistry();

      final e1 = world.spawnWith([]);
      final e2 = world.spawnWith([]);
      final e3 = world.spawnWith([]);

      registry.register(e1, 1);
      registry.register(e2, 2);
      registry.register(e3, 3);

      final relevant = manager.getRelevantEntities(1, world, registry);
      expect(relevant, containsAll([1, 2, 3]));
      expect(relevant.length, 3);
    });

    test('radius-based filtering with positionGetter', () {
      final world = World();
      final registry = NetworkEntityRegistry();

      // Create entities with positions.
      final peerEntity = world.spawnWith([]);
      final nearEntity = world.spawnWith([]);
      final farEntity = world.spawnWith([]);

      // Store positions in a map keyed by entity.
      final positions = <Entity, _Position>{};
      positions[peerEntity] = _Position(0, 0);
      positions[nearEntity] = _Position(50, 50);
      positions[farEntity] = _Position(5000, 5000);

      // Mark the peer entity as owned by peer 1.
      world.insert<NetworkIdentity>(
          peerEntity, NetworkIdentity(netId: 1, ownerId: 1));

      registry.register(peerEntity, 1);
      registry.register(nearEntity, 2);
      registry.register(farEntity, 3);

      final manager = InterestManager(
        relevanceRadius: 100,
        positionGetter: (w, e) {
          final pos = positions[e]!;
          return (pos.x, pos.y);
        },
      );

      final relevant = manager.getRelevantEntities(1, world, registry);

      // Peer entity (distance 0) and near entity (distance ~70.7) are within
      // radius 100. Far entity (distance ~7071) is not.
      expect(relevant, contains(1));
      expect(relevant, contains(2));
      expect(relevant, isNot(contains(3)));
    });

    test('isRelevant returns true for entities inside radius', () {
      final world = World();
      final registry = NetworkEntityRegistry();

      final peerEntity = world.spawnWith([]);
      final nearEntity = world.spawnWith([]);

      final positions = <Entity, _Position>{};
      positions[peerEntity] = _Position(0, 0);
      positions[nearEntity] = _Position(10, 10);

      world.insert<NetworkIdentity>(
          peerEntity, NetworkIdentity(netId: 1, ownerId: 1));

      registry.register(peerEntity, 1);
      registry.register(nearEntity, 2);

      final manager = InterestManager(
        relevanceRadius: 100,
        positionGetter: (w, e) {
          final pos = positions[e]!;
          return (pos.x, pos.y);
        },
      );

      expect(manager.isRelevant(1, 2, world, registry), true);
    });

    test('isRelevant returns false for entities outside radius', () {
      final world = World();
      final registry = NetworkEntityRegistry();

      final peerEntity = world.spawnWith([]);
      final farEntity = world.spawnWith([]);

      final positions = <Entity, _Position>{};
      positions[peerEntity] = _Position(0, 0);
      positions[farEntity] = _Position(500, 500);

      world.insert<NetworkIdentity>(
          peerEntity, NetworkIdentity(netId: 1, ownerId: 1));

      registry.register(peerEntity, 1);
      registry.register(farEntity, 2);

      final manager = InterestManager(
        relevanceRadius: 100,
        positionGetter: (w, e) {
          final pos = positions[e]!;
          return (pos.x, pos.y);
        },
      );

      expect(manager.isRelevant(1, 2, world, registry), false);
    });

    test('isRelevant returns true when no positionGetter', () {
      final manager = InterestManager();
      final world = World();
      final registry = NetworkEntityRegistry();

      final entity = world.spawnWith([]);
      registry.register(entity, 1);

      expect(manager.isRelevant(1, 1, world, registry), true);
    });
  });
}
