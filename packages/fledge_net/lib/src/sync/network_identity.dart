import 'package:fledge_ecs/fledge_ecs.dart';

/// Component that marks an entity as networked.
///
/// Entities with this component will be synchronized across the network.
class NetworkIdentity {
  /// Unique network ID for this entity.
  final int netId;

  /// Owner peer ID (0 = host-owned, >0 = client-owned).
  int ownerId;

  /// Whether this entity is local authority.
  bool hasAuthority;

  /// Spawn type for replication.
  final String? spawnType;

  NetworkIdentity({
    required this.netId,
    this.ownerId = 0,
    this.hasAuthority = false,
    this.spawnType,
  });
}

/// Tracks which components should be synchronized.
class NetworkSyncConfig {
  /// Components that are synchronized from owner to others.
  final Set<ComponentId> syncedComponents;

  /// Components that are interpolated on non-owners.
  final Set<ComponentId> interpolatedComponents;

  /// Sync rate in Hz.
  final double syncRate;

  NetworkSyncConfig({
    Set<ComponentId>? syncedComponents,
    Set<ComponentId>? interpolatedComponents,
    this.syncRate = 20,
  })  : syncedComponents = syncedComponents ?? {},
        interpolatedComponents = interpolatedComponents ?? {};
}

/// Registry for networked entities.
class NetworkEntityRegistry {
  /// Net ID to entity mapping.
  final Map<int, Entity> _entities = {};

  /// Entity to net ID mapping.
  final Map<Entity, int> _netIds = {};

  /// Next available network ID.
  int _nextNetId = 1;

  /// Register an entity with a network ID.
  void register(Entity entity, int netId) {
    _entities[netId] = entity;
    _netIds[entity] = netId;
  }

  /// Unregister an entity.
  void unregister(Entity entity) {
    final netId = _netIds.remove(entity);
    if (netId != null) {
      _entities.remove(netId);
    }
  }

  /// Get entity by network ID.
  Entity? getEntity(int netId) => _entities[netId];

  /// Get network ID for entity.
  int? getNetId(Entity entity) => _netIds[entity];

  /// Check if entity is registered.
  bool isRegistered(Entity entity) => _netIds.containsKey(entity);

  /// Generate a new unique network ID.
  int generateNetId() => _nextNetId++;

  /// All registered entities.
  Iterable<Entity> get entities => _entities.values;

  /// Number of registered entities.
  int get count => _entities.length;

  /// Clear all registrations.
  void clear() {
    _entities.clear();
    _netIds.clear();
  }
}

/// Pending network spawn request.
class PendingSpawn {
  final int netId;
  final String spawnType;
  final int ownerId;
  final Map<String, dynamic> initialState;
  final DateTime requestTime;

  PendingSpawn({
    required this.netId,
    required this.spawnType,
    required this.ownerId,
    required this.initialState,
    DateTime? requestTime,
  }) : requestTime = requestTime ?? DateTime.now();
}

/// Pending network despawn request.
class PendingDespawn {
  final int netId;
  final DateTime requestTime;

  PendingDespawn({
    required this.netId,
    DateTime? requestTime,
  }) : requestTime = requestTime ?? DateTime.now();
}
