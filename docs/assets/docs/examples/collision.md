# Collision Detection Example

Basic circle-based collision detection between entities using `Transform2D` from fledge_render_2d.

> **Note:** For production games, consider using the [fledge_physics](/docs/plugins/physics) plugin which provides complete collision detection, resolution with wall-sliding, layer-based filtering, and sensor support. This example demonstrates the underlying concepts.

## Components

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D, GlobalTransform2D;

// Generated code - run: dart run build_runner build
part 'components.g.dart';

// Use Transform2D from fledge_render_2d for position
// This ensures compatibility with Tiled and other plugins

@component
class CircleCollider {
  double radius;
  CircleCollider(this.radius);
}

@component
class CollisionEvent {
  final Entity other;
  CollisionEvent(this.other);
}
// @tab Inheritance
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D, GlobalTransform2D;

// Use Transform2D from fledge_render_2d for position
// This ensures compatibility with Tiled and other plugins

class CircleCollider {
  double radius;
  CircleCollider(this.radius);
}

class CollisionEvent {
  final Entity other;
  CollisionEvent(this.other);
}
```

## Collision System

```dart-tabs
// @tab Annotations
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;

// Generated code - run: dart run build_runner build
part 'systems.g.dart';

@system
Future<void> collisionDetectionSystem(World world) async {
  final entities = world.query2<Transform2D, CircleCollider>().iter().toList();

  // Check all pairs
  for (var i = 0; i < entities.length; i++) {
    for (var j = i + 1; j < entities.length; j++) {
      final (entityA, transformA, colA) = entities[i];
      final (entityB, transformB, colB) = entities[j];

      final dx = transformB.translation.x - transformA.translation.x;
      final dy = transformB.translation.y - transformA.translation.y;
      final distance = sqrt(dx * dx + dy * dy);
      final minDist = colA.radius + colB.radius;

      if (distance < minDist) {
        // Add collision events
        world.insert(entityA, CollisionEvent(entityB));
        world.insert(entityB, CollisionEvent(entityA));
      }
    }
  }
}

@system
Future<void> handleCollisionsSystem(World world) async {
  final toRemove = <Entity>[];

  for (final (entity, event) in world.query1<CollisionEvent>().iter()) {
    print('Entity ${entity.id} collided with ${event.other.id}');
    toRemove.add(entity);
  }

  // Remove collision events after processing
  for (final entity in toRemove) {
    world.remove<CollisionEvent>(entity);
  }
}
// @tab Inheritance
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D;

class CollisionDetectionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'collision_detection',
        reads: {ComponentId.of<Transform2D>(), ComponentId.of<CircleCollider>()},
        writes: {ComponentId.of<CollisionEvent>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final entities = world.query2<Transform2D, CircleCollider>().iter().toList();

    // Check all pairs
    for (var i = 0; i < entities.length; i++) {
      for (var j = i + 1; j < entities.length; j++) {
        final (entityA, transformA, colA) = entities[i];
        final (entityB, transformB, colB) = entities[j];

        final dx = transformB.translation.x - transformA.translation.x;
        final dy = transformB.translation.y - transformA.translation.y;
        final distance = sqrt(dx * dx + dy * dy);
        final minDist = colA.radius + colB.radius;

        if (distance < minDist) {
          // Add collision events
          world.insert(entityA, CollisionEvent(entityB));
          world.insert(entityB, CollisionEvent(entityA));
        }
      }
    }
  }
}

class HandleCollisionsSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'handle_collisions',
        reads: {ComponentId.of<CollisionEvent>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  Future<void> run(World world) async {
    final toRemove = <Entity>[];

    for (final (entity, event) in world.query1<CollisionEvent>().iter()) {
      print('Entity ${entity.id} collided with ${event.other.id}');
      toRemove.add(entity);
    }

    // Remove collision events after processing
    for (final entity in toRemove) {
      world.remove<CollisionEvent>(entity);
    }
  }
}
```

## Plugin and Usage

```dart-tabs
// @tab Annotations
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D, GlobalTransform2D;

// Import generated wrappers
import 'systems.g.dart';

class CollisionPlugin implements Plugin {
  @override
  void build(App app) {
    // Add annotation-generated systems (functions)
    app
      .addSystem(collisionDetectionSystem)
      .addSystem(handleCollisionsSystem);

    // Two overlapping entities
    app.world.spawn()
      ..insert(Transform2D.from(0, 0))
      ..insert(GlobalTransform2D())
      ..insert(CircleCollider(10));

    app.world.spawn()
      ..insert(Transform2D.from(5, 0))  // Within radius!
      ..insert(GlobalTransform2D())
      ..insert(CircleCollider(10));
  }

  @override
  void cleanup() {}
}

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(CollisionPlugin());

  await app.tick();
  // Output: Entity 0 collided with 1
  //         Entity 1 collided with 0
}
// @tab Inheritance
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show Transform2D, GlobalTransform2D;

class CollisionPlugin implements Plugin {
  @override
  void build(App app) {
    // Add class-based systems (instantiated)
    app
      .addSystem(CollisionDetectionSystem())
      .addSystem(HandleCollisionsSystem());

    // Two overlapping entities
    app.world.spawn()
      ..insert(Transform2D.from(0, 0))
      ..insert(GlobalTransform2D())
      ..insert(CircleCollider(10));

    app.world.spawn()
      ..insert(Transform2D.from(5, 0))  // Within radius!
      ..insert(GlobalTransform2D())
      ..insert(CircleCollider(10));
  }

  @override
  void cleanup() {}
}

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(CollisionPlugin());

  await app.tick();
  // Output: Entity 0 collided with 1
  //         Entity 1 collided with 0
}
```

## Integration with Tiled

The Collision Detection example uses `Transform2D` for position, making it compatible with the [Tiled plugin](/docs/plugins/tiled). When using Tiled tilemaps:

1. **Object layer entities** automatically get `Transform2D` when spawned
2. **Tile layer colliders** should be spawned with `Transform2D` (see Tiled docs)

For shape-based collision with Tiled's `Collider` component (which uses shapes instead of circles), you'll need a more sophisticated collision system that handles rectangles, polygons, and other shapes. See the [Tiled Collision documentation](/docs/plugins/tiled#tileset-tile-collisions) for details on working with shape-based colliders.
