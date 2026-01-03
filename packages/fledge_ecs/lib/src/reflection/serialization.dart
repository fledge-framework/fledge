import '../archetype/archetype_id.dart';
import '../component.dart';
import '../entity.dart';
import '../world.dart';
import 'type_registry.dart';

/// Serialization utilities for ECS data.
///
/// Provides methods to serialize and deserialize entities, components,
/// and world state using the [TypeRegistry].
///
/// ```dart
/// // Serialize an entity
/// final json = EntitySerializer.toJson(world, entity);
///
/// // Deserialize an entity
/// final entity = EntitySerializer.fromJson(world, json);
/// ```
class EntitySerializer {
  EntitySerializer._();

  /// Serializes an entity and its components to JSON.
  ///
  /// Only components registered in [TypeRegistry] will be serialized.
  /// Returns null if the entity is dead.
  static Map<String, dynamic>? toJson(World world, Entity entity) {
    if (!world.isAlive(entity)) return null;

    final components = <String, dynamic>{};
    final archetypeId = world.getArchetypeId(entity);

    if (archetypeId != null) {
      for (final componentId in archetypeId.components) {
        final component = world.getByComponentId(entity, componentId);
        if (component == null) continue;

        final info =
            TypeRegistry.instance.getByRuntimeType(component.runtimeType);
        if (info != null) {
          components[info.name] = info.toJsonDynamic(component);
        }
      }
    }

    return {
      'entity': {'id': entity.id, 'generation': entity.generation},
      'components': components,
    };
  }

  /// Deserializes an entity from JSON.
  ///
  /// Creates a new entity and populates it with the serialized components.
  /// Only components registered in [TypeRegistry] will be deserialized.
  static Entity fromJson(World world, Map<String, dynamic> json) {
    final entity = world.spawn().entity;

    final components = json['components'] as Map<String, dynamic>?;
    if (components != null) {
      for (final entry in components.entries) {
        final info = TypeRegistry.instance.getByName(entry.key);
        if (info != null) {
          final component = info.fromJson(entry.value as Map<String, dynamic>);
          world.insertDynamic(entity, info.type, component);
        }
      }
    }

    return entity;
  }
}

/// Serializes multiple entities.
class BatchEntitySerializer {
  BatchEntitySerializer._();

  /// Serializes multiple entities to a JSON list.
  static List<Map<String, dynamic>> toJsonList(
      World world, Iterable<Entity> entities) {
    return entities
        .map((e) => EntitySerializer.toJson(world, e))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Deserializes multiple entities from a JSON list.
  static List<Entity> fromJsonList(
      World world, List<Map<String, dynamic>> jsonList) {
    return jsonList.map((json) => EntitySerializer.fromJson(world, json)).toList();
  }
}

/// Extension on World for serialization support.
extension WorldSerializationExtension on World {
  /// Serializes an entity to JSON.
  ///
  /// Returns null if the entity is dead.
  Map<String, dynamic>? entityToJson(Entity entity) {
    return EntitySerializer.toJson(this, entity);
  }

  /// Deserializes an entity from JSON.
  Entity entityFromJson(Map<String, dynamic> json) {
    return EntitySerializer.fromJson(this, json);
  }

  /// Inserts a component using its runtime type.
  ///
  /// This is used internally for deserialization when the static type
  /// is not known at compile time.
  void insertDynamic(Entity entity, Type type, dynamic component) {
    final componentId = ComponentId.ofType(type);
    final location = entities.getLocation(entity);
    if (location == null) {
      throw StateError('Cannot insert component into dead entity: $entity');
    }

    final currentTable = archetypes.tableAt(location.archetypeIndex);

    // Check if component already exists in this archetype
    if (currentTable.archetypeId.contains(componentId)) {
      // Just update the existing component
      currentTable.setComponent(location.row, componentId, component,
          currentTick: currentTick);
      return;
    }

    // Need to move to a new archetype
    final targetIndex =
        archetypes.getAddTarget(location.archetypeIndex, componentId);
    final targetTable = archetypes.tableAt(targetIndex);

    // Extract all existing components and their ticks
    final components = currentTable.extractRow(location.row);
    final existingTicks = currentTable.extractTicks(location.row);
    components[componentId] = component;

    // Remove from current table
    final movedEntity = currentTable.swapRemove(location.row);
    if (movedEntity != null) {
      entities.setLocation(movedEntity, location);
    }

    // Add to new table
    final newRow = targetTable.add(
      entity,
      components,
      currentTick: currentTick,
      existingTicks: existingTicks,
    );
    entities.setLocation(entity, EntityLocation(targetIndex, newRow));
  }

  /// Gets a component by its ComponentId.
  ///
  /// This is used internally when the static type is not known.
  dynamic getByComponentId(Entity entity, ComponentId componentId) {
    final location = entities.getLocation(entity);
    if (location == null) return null;

    final table = archetypes.tableAt(location.archetypeIndex);
    if (!table.archetypeId.contains(componentId)) return null;

    return table.getComponent<dynamic>(location.row, componentId);
  }

  /// Gets the archetype ID for an entity.
  ArchetypeId? getArchetypeId(Entity entity) {
    final location = entities.getLocation(entity);
    if (location == null) return null;
    return archetypes.tableAt(location.archetypeIndex).archetypeId;
  }
}
