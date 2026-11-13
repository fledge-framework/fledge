import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:meta/meta.dart';

/// Network identity of a replicated entity: its network id and owner.
///
/// The replication layer inserts it (from `Replicated` on the host, from
/// spawn messages on clients); games read it and, on the host, change
/// ownership by assigning [ownerId].
class NetworkIdentity {
  /// Unique network ID for this entity.
  final int netId;

  /// Owner peer ID (0 = host-owned, >0 = client-owned).
  ///
  /// Assign it on the host to move ownership; the change is replicated.
  /// Assigning it on a client has no effect on what the host accepts.
  int ownerId;

  /// Peer id of the instance holding this component: `0` on the host,
  /// the client's own peer id on a client.
  final int localPeerId;

  NetworkIdentity({
    required this.netId,
    this.ownerId = 0,
    this.localPeerId = 0,
  });

  /// Whether the local instance owns (controls) this entity: it submits
  /// the entity's inputs and, on a client, predicts it.
  ///
  /// `ownerId == localPeerId`, so it follows ownership changes. On the
  /// host it is `true` only for host-owned entities; the host still
  /// simulates every entity, but a client-owned entity is driven by that
  /// client's inputs.
  bool get hasAuthority => ownerId == localPeerId;

  /// Check if a given peer owns this entity.
  bool isOwnedBy(int peerId) => ownerId == peerId;
}

/// Resource mapping network ids to entities (inserted by `NetworkPlugin`).
///
/// Maintained by the replication layer: the host registers an entity when
/// it first replicates it, clients when a spawn arrives. Games only look
/// entities up.
class NetworkEntityRegistry {
  final Map<int, Entity> _entities = {};
  final Map<Entity, int> _netIds = {};
  int _nextNetId = 1;

  /// Register an entity with a network ID.
  @internal
  void register(Entity entity, int netId) {
    _entities[netId] = entity;
    _netIds[entity] = netId;
  }

  /// Unregister an entity.
  @internal
  void unregister(Entity entity) {
    final netId = _netIds.remove(entity);
    if (netId != null) {
      _entities.remove(netId);
    }
  }

  /// Generate a new unique network ID.
  @internal
  int generateNetId() => _nextNetId++;

  /// Clear all registrations.
  @internal
  void clear() {
    _entities.clear();
    _netIds.clear();
  }

  /// Get entity by network ID.
  Entity? getEntity(int netId) => _entities[netId];

  /// Get network ID for entity.
  int? getNetId(Entity entity) => _netIds[entity];

  /// Check if entity is registered.
  bool isRegistered(Entity entity) => _netIds.containsKey(entity);

  /// All registered entities.
  Iterable<Entity> get entities => _entities.values;

  /// Number of registered entities.
  int get count => _entities.length;
}
