# Component API Reference

Components are data containers attached to entities. They hold the state that systems operate on.

## Import

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
// @tab Classes
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Defining Components

```dart-tabs
// @tab Annotations
// Use the @component annotation to mark a class as a component
@component
class Position {
  double x;
  double y;

  Position(this.x, this.y);
}

// Run `dart run build_runner build` to generate registration code
// @tab Classes
// Any class can be used as a component
class Position {
  double x;
  double y;

  Position(this.x, this.y);
}
```

### Component Requirements

- Must be a class (not abstract)
- Should have mutable fields for systems to modify
- When using annotations, run `build_runner` to generate registration code

## Component Types

### Data Components

Components that hold meaningful data:

```dart-tabs
// @tab Annotations
@component
class Health {
  int current;
  int max;

  Health(this.current, this.max);

  double get percentage => current / max;
  bool get isDead => current <= 0;
}

@component
class Transform {
  double x, y;
  double rotation;
  double scaleX, scaleY;

  Transform({
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });
}
// @tab Classes
class Health {
  int current;
  int max;

  Health(this.current, this.max);

  double get percentage => current / max;
  bool get isDead => current <= 0;
}

class Transform {
  double x, y;
  double rotation;
  double scaleX, scaleY;

  Transform({
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });
}
```

### Marker Components

Empty components used for tagging entities:

```dart-tabs
// @tab Annotations
@component
class Player {}

@component
class Enemy {}

@component
class Static {} // Won't be moved by physics

@component
class Dead {} // Marked for cleanup
// @tab Classes
class Player {}

class Enemy {}

class Static {} // Won't be moved by physics

class Dead {} // Marked for cleanup
```

### Relationship Components

Components that reference other entities:

```dart-tabs
// @tab Annotations
@component
class Parent {
  final Entity entity;
  Parent(this.entity);
}

@component
class Children {
  final List<Entity> entities;
  Children(this.entities);
}
// @tab Classes
class Parent {
  final Entity entity;
  Parent(this.entity);
}

class Children {
  final List<Entity> entities;
  Children(this.entities);
}
```

## ComponentId

Every component type has a unique `ComponentId` assigned at registration.

```dart
// Access the component ID for a type
final positionId = ComponentId.of<Position>();
final healthId = ComponentId.of<Health>();

print(positionId.id); // Internal integer ID
```

## Adding Components

### At Spawn Time

```dart
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(1, 0))
  ..insert(Health(100, 100));
```

### After Spawning

```dart
final entity = world.spawn();

// Add components one at a time
world.insert(entity, Position(0, 0));
world.insert(entity, Velocity(1, 0));
```

### Replacing Components

Inserting a component of a type that already exists will replace it:

```dart
world.insert(entity, Position(0, 0));
world.insert(entity, Position(100, 100)); // Replaces the old Position
```

## Accessing Components

### Direct Access

```dart
final pos = world.get<Position>(entity);
if (pos != null) {
  pos.x += 10;
}
```

### Check Existence

```dart
if (world.has<Player>(entity)) {
  // This is a player
}
```

### Through Queries

```dart
final query = world.query2<Position, Velocity>();
for (final (entity, pos, vel) in query.iter()) {
  pos.x += vel.dx;
  pos.y += vel.dy;
}
```

## Removing Components

```dart
world.remove<Velocity>(entity); // Entity stops moving
```

Removing a component changes the entity's archetype.

## Best Practices

### Keep Components Small

```dart
// Bad - one big component
@component
class Entity {
  double x, y, vx, vy;
  int health, maxHealth;
  String name;
  bool isPlayer;
}

// Good - separate concerns
@component
class Position { double x, y; }

@component
class Velocity { double dx, dy; }

@component
class Health { int current, max; }

@component
class Named { String name; }

@component
class Player {}
```

### Prefer Composition

```dart
// Entity with physics
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(0, 0))
  ..insert(Mass(1.0));

// Static entity (no physics)
world.spawn()
  ..insert(Position(0, 0))
  ..insert(Static());
```

### Use Marker Components for Filtering

```dart
@component class Friendly {}
@component class Hostile {}
@component class Neutral {}

// Query only hostile entities
final hostiles = world.query2<Position, Health>(filter: const With<Hostile>());
```

## See Also

- [Entity](/docs/api/entity) - Entities that hold components
- [Query](/docs/api/query) - Querying entities by components
- [World](/docs/api/world) - Component storage and access
