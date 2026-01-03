# Hierarchy API

Parent-child entity relationships and traversal.

## Parent

Component marking an entity as a child of another.

```dart
class Parent {
  final Entity entity;
  const Parent(this.entity);
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `entity` | `Entity` | The parent entity |

## Children

Component storing an entity's children.

```dart
class Children {
  List<Entity> get children;
  int get length;
  bool get isEmpty;
  bool get isNotEmpty;
  bool contains(Entity entity);
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `children` | `List<Entity>` | List of child entities |
| `length` | `int` | Number of children |
| `isEmpty` | `bool` | True if no children |
| `isNotEmpty` | `bool` | True if has children |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `contains(entity)` | `bool` | Check if entity is a child |

## WorldHierarchyExtension

Extension methods on World for hierarchy operations.

```dart
extension WorldHierarchyExtension on World {
  void setParent(Entity child, Entity parent);
  void removeParent(Entity child);
  Entity? getParent(Entity entity);
  Iterable<Entity> getChildren(Entity entity);
  bool hasParent(Entity entity);
  bool hasChildren(Entity entity);
  Entity root(Entity entity);
  Iterable<Entity> ancestors(Entity entity);
  Iterable<Entity> descendants(Entity entity);
  void despawnRecursive(Entity entity);
  EntityCommands spawnChild(Entity parent);
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `setParent(child, parent)` | `void` | Set entity's parent |
| `removeParent(child)` | `void` | Remove entity's parent |
| `getParent(entity)` | `Entity?` | Get entity's parent |
| `getChildren(entity)` | `Iterable<Entity>` | Get entity's children |
| `hasParent(entity)` | `bool` | Check if entity has parent |
| `hasChildren(entity)` | `bool` | Check if entity has children |
| `root(entity)` | `Entity` | Get topmost ancestor |
| `ancestors(entity)` | `Iterable<Entity>` | Iterate ancestors bottom-up |
| `descendants(entity)` | `Iterable<Entity>` | Iterate descendants top-down |
| `despawnRecursive(entity)` | `void` | Despawn entity and all descendants |
| `spawnChild(parent)` | `EntityCommands` | Spawn entity as child |

## Commands Hierarchy Support

```dart
extension CommandsHierarchyExtension on Commands {
  SpawnChildCommand spawnChild(Entity parent);
  void despawnRecursive(Entity entity);
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `spawnChild(parent)` | `SpawnChildCommand` | Queue child spawn (use cascade to add components) |
| `despawnRecursive(entity)` | `void` | Queue recursive despawn |

## Examples

### Creating Hierarchy

```dart
// Create parent
final parent = world.spawn()
  ..insert(Position(0, 0))
  ..insert(Name('Parent'));

// Create child
final child = world.spawn()
  ..insert(Position(10, 0))
  ..insert(Name('Child'));

// Set relationship
world.setParent(child.entity, parent.entity);

// Or spawn as child directly
final child2 = world.spawnChild(parent.entity)
  ..insert(Position(20, 0))
  ..insert(Name('Child 2'));
```

### Querying Hierarchy

```dart
// Check relationships
if (world.hasParent(entity)) {
  final parent = world.getParent(entity)!;
  print('Parent: $parent');
}

if (world.hasChildren(entity)) {
  for (final child in world.getChildren(entity)) {
    print('Child: $child');
  }
}
```

### Traversal

```dart
// Walk up to root
for (final ancestor in world.ancestors(entity)) {
  print('Ancestor: $ancestor');
}
final root = world.root(entity);

// Walk down to leaves
for (final descendant in world.descendants(entity)) {
  print('Descendant: $descendant');
}
```

### Reparenting

```dart
// Move child to new parent
world.setParent(child, newParent);
// Automatically removes from old parent

// Remove parent (make root)
world.removeParent(child);
```

### Recursive Despawn

```dart
// Despawns entity AND all descendants
world.despawnRecursive(parent);
```

### Deferred Operations

```dart
void spawnerSystem(World world) {
  final commands = Commands();

  final parent = commands.spawn()..insert(ParentMarker());

  // Child spawn is deferred - use cascade syntax
  final childCmd = commands.spawnChild(parent.entity!)
    ..insert(ChildComponent());

  // Recursive despawn is deferred
  commands.despawnRecursive(oldEntity);

  // Apply all deferred operations
  commands.apply(world);

  // Access spawned child entity after apply
  final childEntity = childCmd.entity; // Entity? - null if parent was dead
}
```

### Transform Propagation

```dart
void propagateTransforms(World world) {
  for (final (entity, local, parent) in
      world.query2<LocalTransform, Parent>().iter()) {
    final parentTransform = world.get<Transform>(parent.entity);
    if (parentTransform != null) {
      world.insert(entity, Transform(
        x: parentTransform.x + local.x,
        y: parentTransform.y + local.y,
        rotation: parentTransform.rotation + local.rotation,
      ));
    }
  }
}
```

### Scene Graph

```dart
// Build scene hierarchy
final scene = world.spawn()..insert(Scene());

final background = world.spawnChild(scene.entity)
  ..insert(Layer(0));

final entities = world.spawnChild(scene.entity)
  ..insert(Layer(1));

final player = world.spawnChild(entities.entity)
  ..insert(Player());

// Clear entire scene
world.despawnRecursive(scene.entity);
```

## Notes

- Setting a parent automatically updates the parent's Children component
- Removing a parent automatically updates the old parent's Children
- despawnRecursive processes children depth-first
- Hierarchy uses standard ECS components (Parent, Children)

## See Also

- [Hierarchies Guide](/docs/guides/hierarchies)
- [Commands API](/docs/api/commands)
- [Entity API](/docs/api/entity)
