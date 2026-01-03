# Reflection API

Runtime type information for serialization and editor tooling.

## FieldInfo

Metadata about a component field.

```dart
class FieldInfo {
  final String name;
  final Type type;
  final bool isNullable;
  final dynamic Function()? defaultValue;

  const FieldInfo({
    required this.name,
    required this.type,
    this.isNullable = false,
    this.defaultValue,
  });
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Field name |
| `type` | `Type` | Field type |
| `isNullable` | `bool` | Whether field accepts null |
| `defaultValue` | `Function()?` | Factory for default value |

## ComponentTypeInfo<T>

Runtime type information for a component.

```dart
class ComponentTypeInfo<T> {
  final Type type;
  final String name;
  final List<FieldInfo> fields;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T instance) toJson;
  final T Function()? defaultFactory;

  const ComponentTypeInfo({
    required this.type,
    required this.name,
    required this.fields,
    required this.fromJson,
    required this.toJson,
    this.defaultFactory,
  });

  Map<String, dynamic> toJsonDynamic(dynamic instance);
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `type` | `Type` | The component type |
| `name` | `String` | Type name for serialization |
| `fields` | `List<FieldInfo>` | Field metadata |
| `fromJson` | `Function` | Deserializer |
| `toJson` | `Function` | Serializer |
| `defaultFactory` | `Function?` | Default instance factory |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `toJsonDynamic(instance)` | `Map<String, dynamic>` | Serialize with dynamic input |

## TypeRegistry

Singleton registry for component type information.

```dart
class TypeRegistry {
  static final TypeRegistry instance;

  void registerComponent<T>(ComponentTypeInfo<T> info);
  ComponentTypeInfo<T>? getByType<T>();
  ComponentTypeInfo? getByRuntimeType(Type type);
  ComponentTypeInfo? getByName(String name);
  bool isRegistered<T>();
  bool isRegisteredType(Type type);
  bool isRegisteredName(String name);
  Iterable<ComponentTypeInfo> get registeredTypes;
  Iterable<String> get registeredNames;
  int get count;
  void clear();
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `registerComponent<T>(info)` | `void` | Register component type |
| `getByType<T>()` | `ComponentTypeInfo<T>?` | Get info by static type |
| `getByRuntimeType(type)` | `ComponentTypeInfo?` | Get info by Type object |
| `getByName(name)` | `ComponentTypeInfo?` | Get info by name |
| `isRegistered<T>()` | `bool` | Check if type registered |
| `clear()` | `void` | Remove all registrations |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `registeredTypes` | `Iterable` | All registered type infos |
| `registeredNames` | `Iterable<String>` | All registered names |
| `count` | `int` | Number of registered types |

## TypeRegistryExtension

Convenience methods for registration.

```dart
extension TypeRegistryExtension on TypeRegistry {
  void registerSimple<T>({
    required String name,
    required List<FieldInfo> fields,
    required T Function(List<dynamic> args) constructor,
    required List<dynamic> Function(T instance) getFields,
  });
}
```

## EntitySerializer

Serialize entities to/from JSON.

```dart
class EntitySerializer {
  static Map<String, dynamic>? toJson(World world, Entity entity);
  static Entity fromJson(World world, Map<String, dynamic> json);
}
```

### Static Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `toJson(world, entity)` | `Map?` | Serialize entity, null if dead |
| `fromJson(world, json)` | `Entity` | Deserialize and spawn entity |

### JSON Format

```json
{
  "entity": {"id": 0, "generation": 0},
  "components": {
    "Position": {"x": 10.0, "y": 20.0},
    "Velocity": {"dx": 1.0, "dy": 2.0}
  }
}
```

## BatchEntitySerializer

Serialize multiple entities.

```dart
class BatchEntitySerializer {
  static List<Map<String, dynamic>> toJsonList(
    World world,
    Iterable<Entity> entities,
  );

  static List<Entity> fromJsonList(
    World world,
    List<Map<String, dynamic>> jsonList,
  );
}
```

## WorldSerializationExtension

Convenience methods on World.

```dart
extension WorldSerializationExtension on World {
  Map<String, dynamic>? entityToJson(Entity entity);
  Entity entityFromJson(Map<String, dynamic> json);
  void insertDynamic(Entity entity, Type type, dynamic component);
  dynamic getByComponentId(Entity entity, ComponentId componentId);
  ArchetypeId? getArchetypeId(Entity entity);
}
```

## Examples

### Manual Registration

```dart
TypeRegistry.instance.registerComponent(ComponentTypeInfo<Position>(
  type: Position,
  name: 'Position',
  fields: [
    FieldInfo(name: 'x', type: double),
    FieldInfo(name: 'y', type: double),
  ],
  fromJson: (json) => Position(
    json['x'] as double,
    json['y'] as double,
  ),
  toJson: (pos) => {'x': pos.x, 'y': pos.y},
));
```

### Simple Registration

```dart
TypeRegistry.instance.registerSimple<Position>(
  name: 'Position',
  fields: [
    FieldInfo(name: 'x', type: double),
    FieldInfo(name: 'y', type: double),
  ],
  constructor: (args) => Position(args[0], args[1]),
  getFields: (pos) => [pos.x, pos.y],
);
```

### Serialization

```dart
// Register types first
TypeRegistry.instance.registerComponent(...);

// Create entity
final entity = world.spawn()
  ..insert(Position(10, 20))
  ..insert(Velocity(1, 2));

// Serialize
final json = EntitySerializer.toJson(world, entity.entity);
// {"entity": {...}, "components": {"Position": {...}, "Velocity": {...}}}

// Deserialize
final restored = EntitySerializer.fromJson(world, json);
```

### Batch Operations

```dart
// Serialize all entities with Position
final entities = world.query1<Position>()
    .iter()
    .map((e) => e.$1)
    .toList();

final jsonList = BatchEntitySerializer.toJsonList(world, entities);

// Deserialize
final restored = BatchEntitySerializer.fromJsonList(world, jsonList);
```

### World Extension Methods

```dart
// Using extension methods
final json = world.entityToJson(entity);
final restored = world.entityFromJson(json!);
```

## @reflectable Annotation

Mark components for code generation:

```dart
@component
@reflectable
class Position {
  double x;
  double y;
  Position(this.x, this.y);
}

// Generated code registers automatically
```

## See Also

- [World API](/docs/api/world)
- [Entity API](/docs/api/entity)
- [Component API](/docs/api/component)
