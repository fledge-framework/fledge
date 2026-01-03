# Advanced ECS Example

This example demonstrates the advanced features of the Fledge ECS framework:

## Features Demonstrated

### 1. Observers
React to component lifecycle events (add, remove, change) without polling.

```dart
world.observers.register(Observer<Spaceship>.onAdd((w, entity, ship) {
  print('Spaceship "${ship.name}" spawned!');
}));
```

### 2. Hierarchies
Create parent-child relationships between entities.

```dart
final ship = world.spawn()..insert(Spaceship('Falcon'));
final turret = world.spawnChild(ship.entity)..insert(Turret('Laser'));
```

### 3. Change Detection
Query for components that changed this frame.

```dart
for (final (entity, h) in world.query1<Health>(filter: Changed<Health>()).iter()) {
  print('Health changed: ${h.current}');
}
```

### 4. States
Manage game states with automatic system activation.

```dart
app
  .addState<GameState>(GameState.menu)
  .addSystemInState(gameplaySystem, GameState.playing);
```

### 5. System Sets
Group systems with shared configuration.

```dart
app
  .configureSet('physics', (s) => s.after('input').before('render'))
  .addSystemToSet(movementSystem, 'physics');
```

### 6. Run Conditions
Conditionally execute systems based on world state.

```dart
app.addSystem(FunctionSystem(
  'bonusSystem',
  runIf: RunConditions.resource<Score>((s) => s.value > 50),
  run: bonusLogic,
));
```

### 7. Recursive Despawn
Despawn entities and all their children at once.

```dart
world.despawnRecursive(ship.entity); // Removes ship and all turrets
```

## Running

```bash
dart run bin/main.dart
```
