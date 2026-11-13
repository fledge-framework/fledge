import 'package:fledge_ecs/fledge_ecs.dart';

import '../traits/saveable.dart';

/// Marks an entity whose registered components are saved, under a stable
/// [id].
///
/// The id is what ties a saved entity to the world on load: an entity that
/// already carries the same id is updated in place, and a missing one is
/// spawned. It must be stable across sessions and unique among saved
/// entities (e.g. `'player:<account>'`, `'npc:ada'`, `'chest:12'`).
class SaveId {
  /// The entity's stable id.
  final String id;

  /// Creates a save id.
  const SaveId(this.id);

  @override
  bool operator ==(Object other) => other is SaveId && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SaveId($id)';
}

/// The component types saved on entities marked with [SaveId].
///
/// Register each type once, with a constructor used when a loaded entity
/// doesn't have the component yet. Components mix in [Saveable]; their
/// [Saveable.saveKey] names them in the save file.
///
/// ```dart
/// saveManager.components
///   ..register(Inventory.new)
///   ..register(Health.new);
///
/// world.spawn()
///   ..insert(const SaveId('player:1'))
///   ..insert(Inventory())
///   ..insert(Health());
/// ```
class SavedComponents {
  final Map<String, _SavedComponent<Saveable>> _byKey = {};

  /// Registers component type [T], created by [create] when loading onto
  /// an entity that lacks it.
  ///
  /// Throws [ArgumentError] if another type already uses the same
  /// [Saveable.saveKey].
  void register<T extends Saveable>(T Function() create) {
    final key = create().saveKey;
    final existing = _byKey[key];
    if (existing != null) {
      if (existing.type == T) return;
      throw ArgumentError(
        'Save key "$key" is used by both ${existing.type} and $T',
      );
    }
    _byKey[key] = _SavedComponent<T>(create);
  }

  /// Whether any component type is registered.
  bool get isEmpty => _byKey.isEmpty;

  /// The registered save keys.
  Iterable<String> get keys => _byKey.keys;

  /// Collects every [SaveId] entity's registered components, by id, then
  /// by save key. Entities with none of the registered components are left
  /// out.
  Map<String, dynamic> collect(World world) {
    final out = <String, dynamic>{};
    for (final (entity, saveId) in world.query1<SaveId>().iter()) {
      final components = <String, dynamic>{};
      for (final MapEntry(key: key, value: saved) in _byKey.entries) {
        final component = saved.read(world, entity);
        if (component != null) components[key] = component.toSaveJson();
      }
      if (components.isNotEmpty) out[saveId.id] = components;
    }
    return out;
  }

  /// Restores [data] (as produced by [collect]) into [world]: each saved id
  /// updates the entity carrying that [SaveId], or spawns one. Components
  /// the entity lacks are created; unregistered keys are ignored. Entities
  /// whose ids aren't in [data] are left alone.
  ///
  /// Returns the entities that were spawned.
  List<Entity> restore(World world, Map<String, dynamic> data) {
    final existing = <String, Entity>{
      for (final (entity, saveId) in world.query1<SaveId>().iter())
        saveId.id: entity,
    };
    final spawned = <Entity>[];
    for (final MapEntry(key: id, value: raw) in data.entries) {
      if (raw is! Map<String, dynamic>) continue;
      var entity = existing[id];
      if (entity == null) {
        entity = (world.spawn()..insert(SaveId(id))).entity;
        spawned.add(entity);
      }
      for (final MapEntry(key: key, value: json) in raw.entries) {
        final saved = _byKey[key];
        if (saved == null || json is! Map<String, dynamic>) continue;
        saved.obtain(world, entity).loadFromSaveJson(json);
      }
    }
    return spawned;
  }
}

class _SavedComponent<T extends Saveable> {
  _SavedComponent(this.create);

  final T Function() create;

  Type get type => T;

  T? read(World world, Entity entity) => world.get<T>(entity);

  T obtain(World world, Entity entity) {
    final current = world.get<T>(entity);
    if (current != null) return current;
    final created = create();
    world.insert<T>(entity, created);
    return created;
  }
}
