# Change Detection Guide

Fledge automatically tracks when components are added or modified, allowing systems to efficiently react to changes.

## Overview

Change detection lets you filter queries to only include entities whose components have changed since your system last ran. This is essential for:

- Reactive systems that respond to component modifications
- Optimization by skipping unchanged entities
- Implementing dirty flags without manual bookkeeping

## Basic Usage

### Detecting Changed Components

Use `Changed<T>` to filter for entities where a component was modified:

```dart
// Only process entities where Position changed this frame
for (final (entity, pos) in world.query1<Position>(filter: Changed<Position>()).iter()) {
  print('Entity $entity moved to (${pos.x}, ${pos.y})');
}
```

### Detecting Added Components

Use `Added<T>` to filter for entities that just received a component:

```dart
// Only process newly spawned enemies
for (final (entity, enemy) in world.query1<Enemy>(filter: Added<Enemy>()).iter()) {
  print('New enemy spawned: $entity');
}
```

## How It Works

Fledge maintains a tick counter that advances each frame. Every component tracks:

- **Added tick**: When the component was first added
- **Changed tick**: When the component was last modified

When you iterate a query with a change filter:
- `Added<T>` returns entities where `addedTick > lastSystemRunTick`
- `Changed<T>` returns entities where `changedTick > lastSystemRunTick`

## Automatic Tracking

Changes are tracked automatically when you:

1. **Insert a component** - Sets both added and changed ticks
2. **Modify via query** - Component references from queries track mutations
3. **Replace a component** - Updates the changed tick

```dart
// All of these trigger change detection:
world.insert(entity, Position(10, 20));  // Added + Changed
pos.x = 50;  // Changed (if accessed via query)
world.insert(entity, Position(30, 40));  // Changed (replacement)
```

## Combining Filters

You can combine change filters with other query filters:

```dart
// Entities with changed Position AND have Enemy marker
for (final (entity, pos) in world.query1<Position>(
  filter: And([Changed<Position>(), With<Enemy>()]),
).iter()) {
  // Only changed enemy positions
}
```

## Common Patterns

### Dirty Flag Pattern

React to changes without checking every entity:

```dart
void renderSystem(World world) {
  // Only update sprites for entities that moved
  for (final (entity, pos, sprite) in world.query2<Position, Sprite>(
    filter: Changed<Position>(),
  ).iter()) {
    sprite.screenX = worldToScreen(pos.x);
    sprite.screenY = worldToScreen(pos.y);
  }
}
```

### Initialization Pattern

Run setup code when components are added:

```dart
void setupSystem(World world) {
  for (final (entity, physics) in world.query1<PhysicsBody>(
    filter: Added<PhysicsBody>(),
  ).iter()) {
    // Initialize physics body
    physicsWorld.addBody(entity, physics);
  }
}
```

### Validation Pattern

Validate data when it changes:

```dart
void validateHealthSystem(World world) {
  for (final (entity, health) in world.query1<Health>(
    filter: Changed<Health>(),
  ).iter()) {
    health.current = health.current.clamp(0, health.max);
    if (health.current == 0) {
      world.insert(entity, Dead());
    }
  }
}
```

## Performance Notes

- Change detection has minimal overhead when not used
- Filters are evaluated lazily during iteration
- Tick tracking uses simple integer comparisons

## See Also

- [Observers](/docs/guides/observers) - Event-based reactions
- [Queries](/docs/guides/queries) - Query patterns
- [Change Detection API](/docs/api/change-detection) - API reference
