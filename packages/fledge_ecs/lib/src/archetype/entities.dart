import '../entity.dart';

/// Manages entity allocation, deallocation, and location tracking.
///
/// The [Entities] manager handles:
/// - Allocating new entity IDs with generation tracking
/// - Recycling despawned entity IDs
/// - Tracking where each entity's components are stored
///
/// ## Generational Indices
///
/// When an entity is despawned, its ID is added to a free list for reuse.
/// The generation counter is incremented to distinguish new entities from
/// stale references to despawned entities.
///
/// ## Entity Locations
///
/// Each live entity has a location pointing to its archetype table and row.
/// This allows O(1) component access and efficient archetype transitions.
class Entities {
  /// Metadata for each entity slot.
  ///
  /// Index corresponds to entity ID. Contains generation and location.
  final List<EntityMeta> _meta = [];

  /// Free list of entity IDs available for reuse.
  final List<int> _freeList = [];

  /// The number of currently alive entities.
  int _aliveCount = 0;

  /// The number of currently alive entities.
  int get length => _aliveCount;

  /// Returns true if no entities are alive.
  bool get isEmpty => _aliveCount == 0;

  /// Returns true if at least one entity is alive.
  bool get isNotEmpty => _aliveCount > 0;

  /// Allocates a new entity.
  ///
  /// Reuses a despawned entity ID if available, otherwise allocates a new one.
  Entity spawn() {
    _aliveCount++;

    if (_freeList.isNotEmpty) {
      // Reuse a despawned entity ID
      final id = _freeList.removeLast();
      final meta = _meta[id];
      // Location will be set when components are added
      meta.location = EntityLocation(0, -1); // Placeholder
      return Entity(id, meta.generation);
    }

    // Allocate a new entity ID
    final id = _meta.length;
    _meta.add(EntityMeta(0, EntityLocation(0, -1)));
    return Entity(id, 0);
  }

  /// Despawns an entity, making its ID available for reuse.
  ///
  /// Returns true if the entity was alive, false if already despawned
  /// or the generation doesn't match.
  bool despawn(Entity entity) {
    if (!isAlive(entity)) return false;

    final meta = _meta[entity.id];
    meta.location = null;
    meta.generation++;
    _freeList.add(entity.id);
    _aliveCount--;

    return true;
  }

  /// Returns true if the entity is currently alive.
  ///
  /// An entity is alive if:
  /// - Its ID is valid
  /// - Its generation matches
  /// - It has a location
  bool isAlive(Entity entity) {
    if (entity.id < 0 || entity.id >= _meta.length) return false;
    final meta = _meta[entity.id];
    return meta.generation == entity.generation && meta.isAlive;
  }

  /// Gets the location of an entity.
  ///
  /// Returns null if the entity is not alive.
  EntityLocation? getLocation(Entity entity) {
    if (!isAlive(entity)) return null;
    return _meta[entity.id].location;
  }

  /// Sets the location of an entity.
  ///
  /// Throws if the entity is not alive.
  void setLocation(Entity entity, EntityLocation location) {
    if (!isAlive(entity)) {
      throw StateError('Cannot set location of dead entity: $entity');
    }
    _meta[entity.id].location = location;
  }

  /// Gets the location of an entity, assuming it is alive.
  ///
  /// This is faster than [getLocation] but unsafe. Only use when
  /// you are certain the entity is alive.
  EntityLocation getLocationUnchecked(Entity entity) {
    return _meta[entity.id].location!;
  }

  /// Reserves capacity for [count] additional entities.
  ///
  /// This can improve performance when spawning many entities at once.
  void reserve(int count) {
    // Pre-grow the list to avoid reallocations
    final targetCapacity = _meta.length + count - _freeList.length;
    if (targetCapacity > _meta.length) {
      for (int i = _meta.length; i < targetCapacity; i++) {
        _meta.add(EntityMeta(0));
      }
      for (int i = targetCapacity - 1; i >= _meta.length - count; i--) {
        _freeList.add(i);
      }
    }
  }

  /// Returns an iterable of all alive entities.
  ///
  /// Note: This iterates through all entity slots, which may be slow
  /// if many entities have been despawned. Prefer iterating through
  /// archetype tables when possible.
  Iterable<Entity> get allAlive sync* {
    for (int id = 0; id < _meta.length; id++) {
      final meta = _meta[id];
      if (meta.isAlive) {
        yield Entity(id, meta.generation);
      }
    }
  }

  /// Clears all entities.
  void clear() {
    _meta.clear();
    _freeList.clear();
    _aliveCount = 0;
  }
}
