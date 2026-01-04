# fledge_physics

Physics and collision handling for Fledge ECS game framework.

[![pub package](https://img.shields.io/pub/v/fledge_physics.svg)](https://pub.dev/packages/fledge_physics)

## Features

- **Collision Detection**: Automatic collision event generation between overlapping entities
- **Collision Resolution**: Wall-sliding physics that prevents movement into solid colliders
- **Layer-Based Filtering**: Bitmask system to control which entities can collide
- **Sensors**: Trigger zones that generate events without blocking movement
- **Plugin Architecture**: Add physics to your game with a single line

## Installation

```yaml
dependencies:
  fledge_physics: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';

void main() async {
  final app = App()
    ..addPlugin(PhysicsPlugin());

  // Spawn a solid wall
  app.world.spawn()
    ..insert(Transform2D())
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 100, height: 20)))
    ..insert(const CollisionConfig.solid());

  // Spawn a trigger zone (sensor)
  app.world.spawn()
    ..insert(Transform2D())
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 50, height: 50)))
    ..insert(const CollisionConfig.sensor());

  await app.run();
}
```

## Collision Layers

Use `CollisionConfig` to control what entities interact:

```dart
// Define game-specific layers
abstract class GameLayers {
  static const int solid = CollisionLayers.solid;
  static const int trigger = CollisionLayers.trigger;
  static const int player = CollisionLayers.gameLayersStart << 0;
  static const int enemy = CollisionLayers.gameLayersStart << 1;
}

// Player collides with solid, trigger, and enemy layers
entity.insert(CollisionConfig(
  layer: GameLayers.player,
  mask: GameLayers.solid | GameLayers.trigger | GameLayers.enemy,
));
```

### Layer/Mask System

- **layer**: What this entity IS (its collision category)
- **mask**: What this entity INTERACTS WITH (categories it responds to)

Two entities collide when: `(A.layer & B.mask) != 0 && (B.layer & A.mask) != 0`

### Built-in Layers

| Layer | Bit | Description |
|-------|-----|-------------|
| `solid` | 0x0001 | Static geometry, walls |
| `trigger` | 0x0002 | Trigger zones, sensors |
| `gameLayersStart` | 0x0100 | Start of game-specific layers |

## Sensors vs Solid Colliders

```dart
// Solid: blocks movement AND generates events
entity.insert(const CollisionConfig.solid());

// Sensor: generates events but doesn't block movement
entity.insert(const CollisionConfig.sensor());
```

## Handling Collisions

Query for `CollisionEvent` to respond to collisions:

```dart
class MySystem implements System {
  @override
  Future<void> run(World world) async {
    for (final (entity, event, player)
        in world.query2<CollisionEvent, Player>().iter()) {
      // Player collided with event.other
      if (world.has<Enemy>(event.other)) {
        // Handle player-enemy collision
      }
    }
  }
}
```

## Velocity Component

The `Velocity` component marks entities as dynamic (can move):

```dart
// Static entity (no velocity) - acts as obstacle
world.spawn()
  ..insert(Transform2D())
  ..insert(Collider.single(RectangleShape(...)))
  ..insert(const CollisionConfig.solid());

// Dynamic entity (has velocity) - can move
world.spawn()
  ..insert(Transform2D())
  ..insert(Velocity.stationary(max: 5))
  ..insert(Collider.single(RectangleShape(...)))
  ..insert(CollisionConfig(...));
```

## Systems

The `PhysicsPlugin` adds these systems:

| System | Stage | Description |
|--------|-------|-------------|
| `CollisionResolutionSystem` | update | Adjusts velocity to prevent solid collisions |
| `CollisionDetectionSystem` | update | Generates `CollisionEvent` for overlapping entities |
| `CollisionCleanupSystem` | last | Removes `CollisionEvent` at end of frame |

## Documentation

- [Getting Started Guide](https://fledge-framework.dev/docs/getting-started)
- [API Reference](https://pub.dev/documentation/fledge_physics)
- [Examples](https://github.com/fledge-framework/fledge/tree/main/examples)

## Related Packages

| Package | Description |
|---------|-------------|
| [fledge_ecs](https://pub.dev/packages/fledge_ecs) | Core ECS framework |
| [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) | 2D sprites, cameras, animation |
| [fledge_tiled](https://pub.dev/packages/fledge_tiled) | Tiled tilemap support |
| [fledge_input](https://pub.dev/packages/fledge_input) | Action-based input handling |

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
