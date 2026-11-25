# Reflection & Serialization

`fledge_ecs` has a small, hand-registered type registry: you describe a
component type once (its name, its fields, and how to convert it to and from
JSON), and Fledge can then serialize whole entities without knowing their
types at compile time. It's useful for level files, editor-style tooling and
debug dumps.

Nothing here is automatic. Dart has no runtime reflection in Flutter builds,
and Fledge has no annotation that registers types for you: you call
`registerComponent` for each type you want serialized.

For save games, [`fledge_save`](/docs/gameplay/save) is usually a better fit:
it saves resources that implement `Saveable`, with slots and versioning.

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Health {
  int value;
  Health(this.value);
}

class Npc {
  final String name;
  Npc(this.name);
}
-->

## Registering a type

```dart
TypeRegistry.instance.registerComponent(
  ComponentTypeInfo<Position>(
    type: Position,
    name: 'Position',
    fields: const [
      FieldInfo(name: 'x', type: double),
      FieldInfo(name: 'y', type: double),
    ],
    fromJson: (json) => Position(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    ),
    toJson: (pos) => {'x': pos.x, 'y': pos.y},
  ),
);
```

- `name` is the key the type is saved under. Keep it stable: renaming the
  class is fine, renaming `name` breaks old files.
- `fields` is descriptive metadata (`FieldInfo` has `name`, `type`,
  `isNullable`, `defaultValue`) for tools such as an inspector. Serialization
  uses only `toJson`/`fromJson`.
- `defaultFactory` optionally creates a default instance, for tools.

When the JSON fields map straight onto constructor arguments,
`registerSimple` saves writing the two functions:

```dart
TypeRegistry.instance.registerSimple<Health>(
  name: 'Health',
  fields: const [FieldInfo(name: 'value', type: int)],
  constructor: (args) => Health(args[0] as int),
  getFields: (health) => [health.value],
);
```

Look types up with `getByType<T>()`, `getByRuntimeType(type)` or
`getByName(name)`; list them with `registeredTypes` and `registeredNames`.
`TypeRegistry.instance` is a single global registry, so register at startup
and call `clear()` between tests.

## Serializing entities

```dart
final world = World();
final guard = world.spawnWith([Position(3, 4), Health(80), Npc('guard')]);

final json = world.entityToJson(guard)!;
// {entity: {id: 0, generation: 0},
//  components: {Position: {x: 3.0, y: 4.0}, Health: {value: 80}}}

final copy = world.entityFromJson(json);
print(world.get<Position>(copy)!.x); // 3.0
print(world.has<Npc>(copy)); // false: Npc isn't registered
```

| API | Does |
|---|---|
| `world.entityToJson(e)` / `EntitySerializer.toJson(world, e)` | Every **registered** component on `e`; `null` if `e` is dead |
| `world.entityFromJson(json)` / `EntitySerializer.fromJson(world, json)` | Spawns a new entity with the registered components found in `json` |
| `BatchEntitySerializer.toJsonList(world, entities)` / `fromJsonList(world, list)` | The same for many entities |

Things to know:

- **Unregistered components are skipped** in both directions, silently.
- **`fromJson` always spawns a new entity.** The saved `entity` id is
  ignored, and any `Entity` stored inside a component (a target, a `Parent`)
  still points at the old id. Remap references yourself after loading a
  group of entities.
- **Observers don't fire** for components inserted by `entityFromJson`
  (it uses `insertDynamic`, which bypasses them). Run any setup your
  `onAdd` observers would have done yourself.
- `insertDynamic`, `getByComponentId` and `getArchetypeId` on `World` are the
  low-level, untyped building blocks the serializer uses.

## Not provided

There's no `@reflectable` annotation and no generator for type info, no
automatic field discovery, no binary format, and no whole-world snapshot
(serialize the entities you care about with `BatchEntitySerializer`, and your
resources yourself).

## See also

- [Save & Load](/docs/gameplay/save)
- [Entities & Components](/docs/ecs/entities-components)
- [fledge_ecs API reference](https://pub.dev/documentation/fledge_ecs/latest/)
