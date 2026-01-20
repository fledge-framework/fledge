# Events Guide

Events allow systems to communicate without direct coupling. They're perfect for one-time notifications like collisions, damage, or game state changes.

## How Events Work

Fledge uses **double-buffering** for events:
- Events written this frame are readable **next frame**
- This prevents systems from seeing events they just wrote
- Events automatically clear after being read

```
Frame 1: System A writes CollisionEvent
Frame 2: System B reads CollisionEvent
Frame 3: Event is cleared
```

## Defining Events

Events are plain Dart classes:

```dart
class CollisionEvent {
  final Entity a;
  final Entity b;
  final double force;

  CollisionEvent(this.a, this.b, this.force);
}

class DamageEvent {
  final Entity target;
  final int amount;
  final Entity? source;

  DamageEvent(this.target, this.amount, {this.source});
}

class ScoreEvent {
  final int points;
  ScoreEvent(this.points);
}
```

## Registering Events

Events must be registered before use. Add them with the App builder (recommended):

```dart
App()
  .addEvent<CollisionEvent>()
  .addEvent<DamageEvent>()
  .addEvent<ScoreEvent>()
  .run();
```

Or inside a plugin:

```dart
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    app
      .addEvent<CollisionEvent>()
      .addEvent<DamageEvent>();
  }

  @override
  void cleanup() {}
}
```

## Writing Events

Use `world.eventWriter<T>()` to send events:

```dart-tabs
// @tab Annotations
@system
void collisionDetection(World world) {
  final collisions = world.eventWriter<CollisionEvent>();
  final entities = world.query2<Position, Collider>().iter().toList();

  for (var i = 0; i < entities.length; i++) {
    for (var j = i + 1; j < entities.length; j++) {
      final (entityA, posA, colA) = entities[i];
      final (entityB, posB, colB) = entities[j];

      if (checkCollision(posA, colA, posB, colB)) {
        collisions.send(CollisionEvent(entityA, entityB, 1.0));
      }
    }
  }
}
// @tab Inheritance
class CollisionDetectionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'collisionDetection',
        reads: {ComponentId.of<Position>(), ComponentId.of<Collider>()},
        eventWrites: {CollisionEvent},
      );

  @override
  Future<void> run(World world) async {
    final collisions = world.eventWriter<CollisionEvent>();
    final entities = world.query2<Position, Collider>().iter().toList();

    for (var i = 0; i < entities.length; i++) {
      for (var j = i + 1; j < entities.length; j++) {
        final (entityA, posA, colA) = entities[i];
        final (entityB, posB, colB) = entities[j];

        if (checkCollision(posA, colA, posB, colB)) {
          collisions.send(CollisionEvent(entityA, entityB, 1.0));
        }
      }
    }
  }
}
```

### Batch Sending

Send multiple events efficiently:

```dart-tabs
// @tab Annotations
@system
void explosionSystem(World world) {
  final damage = world.eventWriter<DamageEvent>();

  for (final (entity, pos, _) in world.query2<Position, Exploding>().iter()) {
    final nearbyEntities = findNearby(pos, radius: 50);

    damage.sendBatch([
      for (final target in nearbyEntities)
        DamageEvent(target, 25, source: entity)
    ]);
  }
}
// @tab Inheritance
class ExplosionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'explosion',
        reads: {ComponentId.of<Position>(), ComponentId.of<Exploding>()},
        eventWrites: {DamageEvent},
      );

  @override
  Future<void> run(World world) async {
    final damage = world.eventWriter<DamageEvent>();

    for (final (entity, pos, _) in world.query2<Position, Exploding>().iter()) {
      final nearbyEntities = findNearby(pos, radius: 50);

      damage.sendBatch([
        for (final target in nearbyEntities)
          DamageEvent(target, 25, source: entity)
      ]);
    }
  }
}
```

## Reading Events

Use `world.eventReader<T>()` to receive events:

```dart-tabs
// @tab Annotations
@system
void damageHandler(World world) {
  for (final event in world.eventReader<DamageEvent>().read()) {
    final health = world.get<Health>(event.target);
    if (health != null) {
      health.current -= event.amount;
    }
  }
}
// @tab Inheritance
class DamageHandlerSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'damageHandler',
        writes: {ComponentId.of<Health>()},
        eventReads: {DamageEvent},
      );

  @override
  Future<void> run(World world) async {
    for (final event in world.eventReader<DamageEvent>().read()) {
      final health = world.get<Health>(event.target);
      if (health != null) {
        health.current -= event.amount;
      }
    }
  }
}
```

### Checking for Events

```dart-tabs
// @tab Annotations
@system
void scoreHandler(World world) {
  final events = world.eventReader<ScoreEvent>();
  if (events.isEmpty) return; // Early exit if no events

  final score = world.getResource<Score>()!;
  for (final event in events.read()) {
    score.value += event.points;
  }

  print('Processed ${events.length} score events');
}
// @tab Inheritance
class ScoreHandlerSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'scoreHandler',
        resourceWrites: {Score},
        eventReads: {ScoreEvent},
      );

  @override
  Future<void> run(World world) async {
    final events = world.eventReader<ScoreEvent>();
    if (events.isEmpty) return; // Early exit if no events

    final score = world.getResource<Score>()!;
    for (final event in events.read()) {
      score.value += event.points;
    }

    print('Processed ${events.length} score events');
  }
}
```

## Read and Write

Read and write to the same event type for chain reactions:

```dart-tabs
// @tab Annotations
@system
void chainExplosions(World world) {
  final reader = world.eventReader<ExplosionEvent>();
  final writer = world.eventWriter<ExplosionEvent>();

  for (final event in reader.read()) {
    // Check if this explosion triggers others
    for (final (entity, pos, explosive) in world.query2<Position, Explosive>().iter()) {
      if (distance(event.position, pos) < explosive.chainRadius) {
        // Trigger chain reaction next frame
        writer.send(ExplosionEvent(pos, explosive.power));
      }
    }
  }
}
// @tab Inheritance
class ChainExplosionsSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'chainExplosions',
        reads: {ComponentId.of<Position>(), ComponentId.of<Explosive>()},
        eventReads: {ExplosionEvent},
        eventWrites: {ExplosionEvent},
      );

  @override
  Future<void> run(World world) async {
    final reader = world.eventReader<ExplosionEvent>();
    final writer = world.eventWriter<ExplosionEvent>();

    for (final event in reader.read()) {
      // Check if this explosion triggers others
      for (final (entity, pos, explosive) in world.query2<Position, Explosive>().iter()) {
        if (distance(event.position, pos) < explosive.chainRadius) {
          // Trigger chain reaction next frame
          writer.send(ExplosionEvent(pos, explosive.power));
        }
      }
    }
  }
}
```

## Event Timing

### Same-Frame Events Won't Be Read

```dart-tabs
// @tab Annotations
@system
void systemA(World world) {
  world.eventWriter<MyEvent>().send(MyEvent()); // Written this frame
}

@system
void systemB(World world) {
  // Won't see events from systemA this frame!
  // Will see them next frame
  for (final event in world.eventReader<MyEvent>().read()) {
    print('Got event');
  }
}
// @tab Inheritance
class SystemA implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'systemA',
        eventWrites: {MyEvent},
      );

  @override
  Future<void> run(World world) async {
    world.eventWriter<MyEvent>().send(MyEvent()); // Written this frame
  }
}

class SystemB implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'systemB',
        eventReads: {MyEvent},
      );

  @override
  Future<void> run(World world) async {
    // Won't see events from systemA this frame!
    // Will see them next frame
    for (final event in world.eventReader<MyEvent>().read()) {
      print('Got event');
    }
  }
}
```

### Multi-Frame Processing

```dart
// Frame 1: Collision detected, event written
// Frame 2: Damage handler reads collision, applies damage
// Frame 2: Death checker sees health <= 0, writes death event
// Frame 3: Cleanup system reads death event, despawns entity
```

## Common Patterns

### Request/Response

```dart
class SpawnRequest {
  final String entityType;
  final Position position;
  SpawnRequest(this.entityType, this.position);
}

void enemySpawner(World world) {
  final commands = Commands();

  for (final request in world.eventReader<SpawnRequest>().read()) {
    if (request.entityType == 'enemy') {
      commands.spawn()
        ..insert(request.position)
        ..insert(Enemy())
        ..insert(Health(100, 100));
    }
  }

  commands.apply(world);
}
```

### State Transitions

```dart-tabs
// @tab Annotations
class GameStateChange {
  final GamePhase newPhase;
  GameStateChange(this.newPhase);
}

@system
void handleStateChange(World world) {
  final state = world.getResource<GameState>()!;

  for (final event in world.eventReader<GameStateChange>().read()) {
    state.phase = event.newPhase;

    // Trigger side effects based on new state
    if (event.newPhase == GamePhase.gameOver) {
      print('Game Over!');
    }
  }
}
// @tab Inheritance
class GameStateChange {
  final GamePhase newPhase;
  GameStateChange(this.newPhase);
}

class HandleStateChangeSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'handleStateChange',
        resourceWrites: {GameState},
        eventReads: {GameStateChange},
      );

  @override
  Future<void> run(World world) async {
    final state = world.getResource<GameState>()!;

    for (final event in world.eventReader<GameStateChange>().read()) {
      state.phase = event.newPhase;

      // Trigger side effects based on new state
      if (event.newPhase == GamePhase.gameOver) {
        print('Game Over!');
      }
    }
  }
}
```

### Aggregation

```dart-tabs
// @tab Annotations
class DamageDealt {
  final int amount;
  DamageDealt(this.amount);
}

@system
void damageStats(World world) {
  final stats = world.getResource<GameStats>()!;
  var totalDamage = 0;
  for (final event in world.eventReader<DamageDealt>().read()) {
    totalDamage += event.amount;
  }
  stats.totalDamage += totalDamage;
}
// @tab Inheritance
class DamageDealt {
  final int amount;
  DamageDealt(this.amount);
}

class DamageStatsSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'damageStats',
        resourceWrites: {GameStats},
        eventReads: {DamageDealt},
      );

  @override
  Future<void> run(World world) async {
    final stats = world.getResource<GameStats>()!;
    var totalDamage = 0;
    for (final event in world.eventReader<DamageDealt>().read()) {
      totalDamage += event.amount;
    }
    stats.totalDamage += totalDamage;
  }
}
```

## Event vs Component

| Use Events When | Use Components When |
|-----------------|---------------------|
| One-time notification | Persistent state |
| Multiple receivers | Single owner |
| Loose coupling needed | Direct access needed |
| Cross-system communication | Entity-specific data |

```dart
// Event: One-time damage notification
class DamageEvent {
  final Entity target;
  final int amount;
}

// Component: Ongoing damage effect
class Burning {
  double remainingTime;
  int damagePerSecond;
}
```

## See Also

- [Resources](/docs/guides/resources) - Global singleton data
- [Systems](/docs/guides/systems) - Event handling in systems
- [Commands](/docs/api/commands) - Deferred entity mutations
