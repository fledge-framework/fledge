# Physics & Collision

The `fledge_physics` plugin provides collision detection, resolution, and layer-based filtering for 2D games. It integrates seamlessly with `fledge_tiled` for tilemap collision and supports both solid obstacles and trigger zones.

## Installation

Add `fledge_physics` to your `pubspec.yaml`:

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
    ..addPlugin(TimePlugin())
    ..addPlugin(PhysicsPlugin());

  // Spawn a solid wall (blocks movement)
  app.world.spawn()
    ..insert(Transform2D.from(100, 50))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 100, height: 20)))
    ..insert(const CollisionConfig.solid());

  // Spawn a trigger zone (generates events, doesn't block)
  app.world.spawn()
    ..insert(Transform2D.from(200, 100))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 50, height: 50)))
    ..insert(const CollisionConfig.sensor());

  await app.run();
}
```

## Core Concepts

### Collision Detection vs Resolution

fledge_physics provides two complementary systems:

1. **Collision Resolution** - Adjusts velocity to prevent entities from moving into solid colliders. Runs *before* position is updated.

2. **Collision Detection** - Generates `CollisionEvent` components on entities that overlap. Runs *after* position is updated.

This two-phase approach ensures:
- Entities can't walk through walls (resolution)
- You still receive events for touching walls (detection)
- Trigger zones generate events without blocking (sensors)

### Static vs Dynamic Entities

Entities are classified by whether they have a `Velocity` component:

| Type | Components | Description |
|------|------------|-------------|
| **Static** | `Transform2D` + `Collider` | Obstacles that don't move (walls, platforms) |
| **Dynamic** | `Transform2D` + `Collider` + `Velocity` | Entities that can move (player, enemies) |

Only dynamic entities have their collisions resolved against static ones.

### Sensors

Sensors are colliders that generate `CollisionEvent` but don't block movement:

```dart
// Solid: blocks movement AND generates events
entity.insert(const CollisionConfig.solid());

// Sensor: generates events but doesn't block movement
entity.insert(const CollisionConfig.sensor());
```

Use sensors for:
- Trigger zones (doors, level transitions)
- Pickup items
- Damage zones
- Detection areas

## Collision Layers

The layer/mask system provides fine-grained control over which entities interact.

### How Layers Work

Each entity has:
- **layer**: What this entity IS (its collision category)
- **mask**: What this entity INTERACTS WITH (categories it responds to)

Two entities collide when both conditions are met:
```
(A.layer & B.mask) != 0  AND  (B.layer & A.mask) != 0
```

### Built-in Layers

| Layer | Bit Value | Description |
|-------|-----------|-------------|
| `solid` | 0x0001 | Static geometry, walls |
| `trigger` | 0x0002 | Trigger zones, sensors |
| `gameLayersStart` | 0x0100 | First available game-specific layer |

### Defining Game Layers

Extend the framework layers for your game:

```dart
abstract class GameLayers {
  // Inherit framework layers
  static const int solid = CollisionLayers.solid;
  static const int trigger = CollisionLayers.trigger;

  // Game-specific layers (start at bit 8)
  static const int player = CollisionLayers.gameLayersStart << 0;     // 0x0100
  static const int enemy = CollisionLayers.gameLayersStart << 1;      // 0x0200
  static const int projectile = CollisionLayers.gameLayersStart << 2; // 0x0400
  static const int item = CollisionLayers.gameLayersStart << 3;       // 0x0800
}
```

### Configuring Entities

```dart
// Player: collides with solid, trigger, and enemy
playerEntity.insert(CollisionConfig(
  layer: GameLayers.player,
  mask: GameLayers.solid | GameLayers.trigger | GameLayers.enemy,
));

// Enemy: collides with solid and player
enemyEntity.insert(CollisionConfig(
  layer: GameLayers.enemy,
  mask: GameLayers.solid | GameLayers.player,
));

// Projectile: only hits enemies (not walls, not player)
projectileEntity.insert(CollisionConfig(
  layer: GameLayers.projectile,
  mask: GameLayers.enemy,
  isSensor: true,  // Don't stop on hit, just trigger event
));

// Trigger zone: only interacts with player
triggerEntity.insert(CollisionConfig.sensor(
  layer: GameLayers.trigger,
  mask: GameLayers.player,
));
```

## Handling Collisions

Query for `CollisionEvent` to respond to collisions:

```dart
class DamageSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'damage',
    reads: {
      ComponentId.of<Player>(),
      ComponentId.of<CollisionEvent>(),
      ComponentId.of<Enemy>(),
    },
  );

  @override
  Future<void> run(World world) async {
    for (final (entity, _, collision)
        in world.query2<Player, CollisionEvent>().iter()) {
      final other = collision.other;

      // Check what we collided with
      if (world.has<Enemy>(other)) {
        // Player hit an enemy
        final player = world.get<Player>(entity)!;
        player.health -= 10;
      }
    }
  }
}
```

### Collision Event Lifecycle

`CollisionEvent` is added each frame that entities overlap and removed automatically at the end of the frame by `CollisionCleanupSystem`.

```
Frame 1: Entities start overlapping
  → CollisionEvent added to both
  → Your systems process the event
  → CollisionCleanupSystem removes events

Frame 2: Still overlapping
  → CollisionEvent added again
  → ...

Frame N: Entities separate
  → No CollisionEvent (they're not overlapping)
```

For one-shot triggers, track state yourself:

```dart
class TriggerZone {
  bool hasTriggered = false;
}

class TriggerSystem implements System {
  @override
  Future<void> run(World world) async {
    for (final (_, _, collision, trigger)
        in world.query3<Player, CollisionEvent, TriggerZone>().iter()) {
      if (!trigger.hasTriggered) {
        trigger.hasTriggered = true;
        // Do one-time action
      }
    }
  }
}
```

## Velocity Component

The `Velocity` component marks entities as dynamic and stores their movement:

```dart
// Create with initial values
entity.insert(Velocity(2, 0, 5));  // x, y, maxSpeed

// Create stationary with max speed
entity.insert(Velocity.stationary(max: 5));

// In systems, modify velocity
final velocity = world.get<Velocity>(entity)!;
velocity.x = inputX * velocity.max;
velocity.y = inputY * velocity.max;

// Check if moving
if (velocity.isMoving) { ... }

// Stop movement
velocity.reset();
```

## Integration with Tiled

fledge_physics works seamlessly with fledge_tiled collision shapes:

```dart
// When spawning tilemaps, enable collision generation
app.world.eventWriter<SpawnTilemapEvent>().send(
  SpawnTilemapEvent(
    assetKey: 'level',
    config: TilemapSpawnConfig(
      tileConfig: TileLayerConfig(
        generateColliders: true,
        colliderLayers: {'collision'},  // Only these layers
        onColliderSpawn: (entity, layerName, collider) {
          // Add CollisionConfig to generated colliders
          entity.insert(const CollisionConfig.solid());
        },
      ),
      objectTypes: {
        'trigger': ObjectTypeConfig(
          createCollider: true,
          onSpawn: (entity, obj) {
            entity.insert(CollisionConfig.sensor(
              layer: GameLayers.trigger,
              mask: GameLayers.player,
            ));
            entity.insert(TriggerZone(
              targetScene: obj.properties.getString('target'),
            ));
          },
        ),
      },
    ),
  ),
);
```

## Plugin Configuration

The `PhysicsPlugin` registers all necessary systems:

```dart
App()
  .addPlugin(PhysicsPlugin());
```

### Custom System Registration

For more control, add systems manually:

```dart
App()
  .addSystem(CollisionResolutionSystem(), stage: CoreStage.update)
  .addSystem(CollisionDetectionSystem(), stage: CoreStage.update)
  .addSystem(CollisionCleanupSystem(), stage: CoreStage.last);
```

## Components Reference

### CollisionConfig

Controls collision behavior:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `layer` | `int` | `CollisionLayers.all` | What this entity IS |
| `mask` | `int` | `CollisionLayers.all` | What this entity INTERACTS WITH |
| `isSensor` | `bool` | `false` | If true, generates events but doesn't block |

Convenience constructors:
- `CollisionConfig.solid()` - Solid obstacle (layer: solid, isSensor: false)
- `CollisionConfig.sensor()` - Trigger zone (layer: trigger, isSensor: true)

### CollisionEvent

Generated when entities overlap:

| Property | Type | Description |
|----------|------|-------------|
| `other` | `Entity` | The entity we collided with |

### Velocity

Movement data for dynamic entities:

| Property | Type | Description |
|----------|------|-------------|
| `x` | `double` | Horizontal velocity |
| `y` | `double` | Vertical velocity |
| `max` | `double` | Maximum speed |
| `isMoving` | `bool` | True if x or y is non-zero |

## Systems Reference

| System | Stage | Description |
|--------|-------|-------------|
| `CollisionResolutionSystem` | update | Adjusts velocity to prevent solid collisions |
| `CollisionDetectionSystem` | update | Generates CollisionEvent for overlapping entities |
| `CollisionCleanupSystem` | last | Removes CollisionEvent at end of frame |

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [Tiled Tilemaps](/docs/plugins/tiled) - Tilemap collision shapes
- [Collision Detection Example](/docs/examples/collision) - Basic circle collision example
