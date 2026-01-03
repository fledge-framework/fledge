/// Reflection and serialization support for the Fledge ECS.
///
/// This module provides runtime type information and serialization
/// utilities for components marked with `@reflectable`.
///
/// ## Type Registry
///
/// The [TypeRegistry] stores metadata about components:
///
/// ```dart
/// // Register a component
/// TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
///   type: Position,
///   name: 'Position',
///   fields: [
///     FieldInfo(name: 'x', type: double),
///     FieldInfo(name: 'y', type: double),
///   ],
///   fromJson: (json) => Position(json['x'], json['y']),
///   toJson: (pos) => {'x': pos.x, 'y': pos.y},
/// ));
///
/// // Query type info
/// final info = TypeRegistry.instance.getByType<Position>();
/// ```
///
/// ## Entity Serialization
///
/// Serialize entities to and from JSON:
///
/// ```dart
/// // Serialize an entity
/// final json = EntitySerializer.toJson(world, entity);
///
/// // Deserialize an entity
/// final entity = EntitySerializer.fromJson(world, json);
/// ```

export 'type_registry.dart';
export 'serialization.dart';
