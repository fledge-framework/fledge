import 'package:meta/meta.dart';

/// A unique identifier for an entity in the ECS world.
///
/// Entities are lightweight handles that identify a collection of components.
/// They use generational indices to detect use-after-despawn errors.
///
/// ## Generational Indices
///
/// When an entity is despawned, its ID can be reused. The generation counter
/// prevents stale entity references from accidentally accessing new entities
/// that reused the same ID.
///
/// ```dart
/// final entity = world.spawn();
/// world.despawn(entity);
///
/// final newEntity = world.spawn(); // May reuse entity.id
/// assert(entity != newEntity);     // Different generations
/// ```
@immutable
class Entity {
  /// The unique index of this entity.
  ///
  /// This index may be reused after the entity is despawned.
  final int id;

  /// The generation of this entity.
  ///
  /// Incremented each time an entity ID is reused, allowing detection
  /// of stale entity references.
  final int generation;

  /// Creates an entity with the given [id] and [generation].
  const Entity(this.id, this.generation);

  /// A placeholder entity that represents "no entity".
  ///
  /// Useful as a default value or sentinel when you need to store an entity
  /// reference but don't have a valid entity yet. This entity should never
  /// be used with world operations - doing so will fail gracefully.
  ///
  /// ## Example
  ///
  /// ```dart
  /// class TargetComponent {
  ///   Entity target;
  ///   TargetComponent([this.target = Entity.placeholder]);
  ///
  ///   bool get hasTarget => !target.isPlaceholder;
  /// }
  ///
  /// // Later, assign a real target
  /// targetComp.target = enemyEntity;
  /// ```
  static const Entity placeholder = Entity(-1, 0);

  /// Returns true if this is the placeholder entity.
  ///
  /// Use this to check if an entity reference is valid before using it.
  bool get isPlaceholder => id == -1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity && id == other.id && generation == other.generation;

  @override
  int get hashCode => Object.hash(id, generation);

  @override
  String toString() => 'Entity($id:$generation)';
}

/// Location of an entity within the archetype storage.
///
/// This is an internal type used to quickly locate an entity's components.
@internal
class EntityLocation {
  /// The archetype this entity belongs to.
  final int archetypeIndex;

  /// The row within the archetype's table.
  int row;

  EntityLocation(this.archetypeIndex, this.row);

  @override
  String toString() => 'EntityLocation(archetype: $archetypeIndex, row: $row)';
}

/// Metadata for a live or dead entity.
@internal
class EntityMeta {
  /// The current generation of this entity slot.
  int generation;

  /// The location of this entity, or null if despawned.
  EntityLocation? location;

  EntityMeta(this.generation, [this.location]);

  /// Returns true if this entity slot is currently alive.
  bool get isAlive => location != null;
}
