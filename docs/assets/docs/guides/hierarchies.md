# Entity Hierarchies Guide

Fledge supports parent-child relationships between entities for scene graphs, UI hierarchies, and composite objects.

## Overview

Hierarchies let you:

- Create parent-child relationships between entities
- Propagate transforms down the tree
- Despawn entire subtrees at once
- Traverse ancestors and descendants

## Creating Hierarchies

### Setting a Parent

```dart
final parent = world.spawn()..insert(Position(0, 0));
final child = world.spawn()..insert(Position(10, 10));

world.setParent(child.entity, parent.entity);
```

### Spawning Children

Spawn an entity as a child of another:

```dart
final parent = world.spawn()..insert(Position(0, 0));

// Spawn a child directly
final child = world.spawnChild(parent.entity)
  ..insert(Position(10, 0))
  ..insert(Sprite('part.png'));
```

## Hierarchy Components

The hierarchy is represented by two components:

- **Parent** - On child entities, points to the parent
- **Children** - On parent entities, lists all children

```dart
// Check if entity has a parent
if (world.hasParent(entity)) {
  final parent = world.getParent(entity);
}

// Get children
for (final child in world.getChildren(entity)) {
  print('Child: $child');
}
```

## Traversal

### Ancestors

Walk up the tree from child to root:

```dart
for (final ancestor in world.ancestors(entity)) {
  print('Ancestor: $ancestor');
}

// Get the root (topmost ancestor)
final root = world.root(entity);
```

### Descendants

Walk down the tree from parent to leaves:

```dart
for (final descendant in world.descendants(entity)) {
  print('Descendant: $descendant');
}
```

## Hierarchy Operations

### Removing Parent

Detach a child from its parent:

```dart
world.removeParent(child);
```

### Reparenting

Move a child to a new parent:

```dart
// setParent handles removing from old parent
world.setParent(child, newParent);
```

### Despawning Hierarchies

Despawn an entity and all its descendants:

```dart
// Despawns parent and ALL children recursively
world.despawnRecursive(parent);
```

## Common Patterns

### Transform Hierarchy

Propagate transforms from parent to child:

```dart-tabs
// @tab Annotations
@system
void transformPropagationSystem(World world) {
  // Process entities with parents
  for (final (entity, localPos, parent) in
      world.query2<LocalPosition, Parent>().iter()) {

    final parentPos = world.get<Position>(parent.entity);
    if (parentPos != null) {
      // Compute world position
      world.insert(entity, Position(
        parentPos.x + localPos.x,
        parentPos.y + localPos.y,
      ));
    }
  }
}
// @tab Inheritance
class TransformPropagationSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'transformPropagation',
        reads: {ComponentId.of<LocalPosition>(), ComponentId.of<Parent>()},
        writes: {ComponentId.of<Position>()},
      );

  @override
  Future<void> run(World world) async {
    // Process entities with parents
    for (final (entity, localPos, parent) in
        world.query2<LocalPosition, Parent>().iter()) {

      final parentPos = world.get<Position>(parent.entity);
      if (parentPos != null) {
        // Compute world position
        world.insert(entity, Position(
          parentPos.x + localPos.x,
          parentPos.y + localPos.y,
        ));
      }
    }
  }
}
```

### UI Layout

Build UI hierarchies:

```dart
// Create a panel with buttons
final panel = world.spawn()
  ..insert(UiRect(0, 0, 200, 300))
  ..insert(Panel());

final button1 = world.spawnChild(panel.entity)
  ..insert(UiRect(10, 10, 80, 30))
  ..insert(Button('OK'));

final button2 = world.spawnChild(panel.entity)
  ..insert(UiRect(10, 50, 80, 30))
  ..insert(Button('Cancel'));
```

### Composite Objects

Create multi-part entities:

```dart
// Spaceship with turrets
final ship = world.spawn()
  ..insert(Position(100, 100))
  ..insert(Ship());

final turret1 = world.spawnChild(ship.entity)
  ..insert(LocalPosition(-20, -10))
  ..insert(Turret());

final turret2 = world.spawnChild(ship.entity)
  ..insert(LocalPosition(20, -10))
  ..insert(Turret());

// Destroying ship destroys turrets too
world.despawnRecursive(ship.entity);
```

### Scene Graph

Organize a game scene:

```dart
final scene = world.spawn()..insert(Scene('level1'));

final background = world.spawnChild(scene.entity)
  ..insert(Layer(0))
  ..insert(Background());

final entities = world.spawnChild(scene.entity)
  ..insert(Layer(1));

final player = world.spawnChild(entities.entity)
  ..insert(Position(50, 50))
  ..insert(Player());

final enemies = world.spawnChild(entities.entity)
  ..insert(EnemyGroup());
```

## Deferred Commands

Use Commands for deferred hierarchy operations:

```dart
void spawnerSystem(World world) {
  final commands = Commands();

  // Spawn parent first to get the Entity
  final parent = world.spawnWith([ParentMarker()]);

  // Queue child spawns using the existing parent entity
  commands.spawnChild(parent, [ChildComponent()]);
  commands.spawnChild(parent, [AnotherChild()]);

  // Queue recursive despawn
  commands.despawnRecursive(oldParent);

  // Apply all commands
  commands.apply(world);
}
```

> **Note:** When using `commands.spawnChild`, the parent must already exist. Spawn the parent using `world.spawn()` or `world.spawnWith()` first, then use Commands for the children.

## Performance Tips

- Flat hierarchies are faster than deep trees
- Cache root entities for frequent lookups
- Use queries instead of manual traversal when possible

## See Also

- [Commands](/docs/api/commands) - Deferred entity operations
- [Hierarchy API](/docs/api/hierarchy) - API reference
- [Entities & Components](/docs/guides/entities-components) - Entity basics
