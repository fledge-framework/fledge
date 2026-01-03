# Advanced ECS Example

This example demonstrates advanced Fledge features including states, observers, hierarchies, and more.

## Features Covered

- Game states and state transitions
- Observers for reactive programming
- Parent-child entity hierarchies
- Change detection
- Run conditions
- System sets and ordering

## Components

```dart-tabs
// @tab Annotations
// lib/components.dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

part 'components.g.dart';

@component
class Position {
  double x, y;
  Position(this.x, this.y);
}

@component
class Spaceship {
  final String name;
  int shields;
  Spaceship(this.name, {this.shields = 100});
}

@component
class Turret {
  final String type;
  int ammo;
  Turret(this.type, {this.ammo = 50});
}

@component
class Health {
  int current;
  final int max;
  Health(this.max) : current = max;
}

// Resources are plain classes (no annotation needed)
class Score {
  int value;
  Score(this.value);
}
// @tab Inheritance
// lib/components.dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Spaceship {
  final String name;
  int shields;
  Spaceship(this.name, {this.shields = 100});
}

class Turret {
  final String type;
  int ammo;
  Turret(this.type, {this.ammo = 50});
}

class Health {
  int current;
  final int max;
  Health(this.max) : current = max;
}

// Resources are plain classes
class Score {
  int value;
  Score(this.value);
}
```

## Observers

React to component lifecycle events:

```dart
// Register before spawning entities
world.observers.register(Observer<Spaceship>.onAdd((w, entity, ship) {
  print('Spaceship "${ship.name}" spawned!');
}));

world.observers.register(Observer<Health>.onChange((w, entity, health) {
  print('Health changed to ${health.current}/${health.max}');
  if (health.current <= 0) {
    w.eventWriter<DeathEvent>().send(DeathEvent(entity));
  }
}));

world.observers.register(Observer<Turret>.onRemove((w, entity, turret) {
  print('Turret "${turret.type}" destroyed');
}));
```

## Hierarchies

Create parent-child relationships:

```dart
// Spawn a spaceship
final shipCmd = world.spawn()
  ..insert(Spaceship('Falcon'))
  ..insert(Position(0, 0))
  ..insert(Health(100));
final ship = shipCmd.entity;

// Attach turrets as children
world.spawnChild(ship)
  ..insert(Turret('Laser'))
  ..insert(Position(-10, 0));

world.spawnChild(ship)
  ..insert(Turret('Missile'))
  ..insert(Position(10, 0));

// Query hierarchy
for (final child in world.getChildren(ship)) {
  final turret = world.get<Turret>(child);
  print('Turret: ${turret?.type}');
}

// Recursive despawn - removes ship AND all turrets
world.despawnRecursive(ship);
```

## Game States

Manage game phases with automatic system activation:

```dart
enum GameState { menu, playing, paused, gameOver }

final app = App()
  .addState<GameState>(GameState.menu)
  .insertResource(Score(0));

// Systems only run in playing state
app.addSystemInState(movementSystem, GameState.playing);
app.addSystemInState(aiSystem, GameState.playing);

// State transition handlers
app.addSystem(FunctionSystem(
  'onEnterPlaying',
  runIf: OnEnterState<GameState>(GameState.playing).condition,
  run: (world) {
    print('Game started!');
    world.spawn()..insert(Player());
  },
));

app.addSystem(FunctionSystem(
  'onExitPlaying',
  runIf: OnExitState<GameState>(GameState.playing).condition,
  run: (world) {
    saveGame(world);
  },
));

// Change state
world.getResource<State<GameState>>()?.set(GameState.playing);
```

## Change Detection

Query for modified components:

```dart
// Advance tick to reset change tracking
world.advanceTick();

// Modify health
final health = world.get<Health>(entity)!;
health.current -= 25;
world.insert(entity, health);

// Query changed components
for (final (e, h) in world.query1<Health>(
  filter: Changed<Health>()
).iter()) {
  print('Entity $e health changed to ${h.current}');
}
```

## System Sets

Group and configure related systems:

```dart
app
  // Configure sets with ordering
  .configureSet('input', (s) => s)
  .configureSet('physics', (s) => s.after('input').before('render'))
  .configureSet('render', (s) => s)

  // Add systems to sets
  .addSystemToSet(keyboardSystem, 'input')
  .addSystemToSet(movementSystem, 'physics')
  .addSystemToSet(collisionSystem, 'physics')
  .addSystemToSet(spriteRenderer, 'render');
```

## Run Conditions

Execute systems conditionally:

```dart
// Only run when score is high enough
app.addSystem(FunctionSystem(
  'highScoreBonus',
  runIf: RunConditions.resource<Score>((s) => s.value > 100),
  run: (world) {
    // Award bonus
  },
));

// Combine conditions
app.addSystem(FunctionSystem(
  'gameplaySystem',
  runIf: RunConditions.and([
    InState<GameState>(GameState.playing).condition,
    RunConditions.resource<GameConfig>((c) => !c.isPaused),
  ]),
  run: gameplayLogic,
));
```

## Running the Example

```bash
cd examples/advanced_ecs
dart pub get
dart run bin/main.dart
```

## Sample Output

```
=== Fledge ECS Advanced Example ===

--- 1. Observers Demo ---

Spawning spaceship...
  [Observer] Spaceship "Falcon" spawned!

--- 2. Hierarchies Demo ---

Ship children:
  - Laser at local position Position(-10.0, 0.0)
  - Missile at local position Position(10.0, 0.0)

--- 3. Change Detection Demo ---

Damaging spaceship...
  [Observer] Health changed to 75/100

Entities with changed Health this tick:
  Entity Entity(0:0): 75/100

--- 4. States Demo ---

Current state: GameState.loading
Transitioning to PLAYING...
  [State] Entered PLAYING state - game started!

...
```

## Key Concepts

1. **Observers** - React immediately to component changes
2. **Hierarchies** - Create entity trees with automatic cleanup
3. **States** - Manage game phases declaratively
4. **Change Detection** - Efficiently track modifications
5. **System Sets** - Organize systems by feature
6. **Run Conditions** - Control when systems execute

## See Also

- [Basic ECS Example](/docs/examples/basic-ecs) - Core concepts
- [Observers Guide](/docs/guides/observers)
- [States Guide](/docs/guides/states)
- [Hierarchies Guide](/docs/guides/hierarchies)
