# Run Conditions API

Conditional system execution based on world state.

## RunCondition

A function that determines if a system should run.

```dart
typedef RunCondition = bool Function(World world);
```

## RunConditions

Factory methods for common run conditions.

```dart
class RunConditions {
  static RunCondition resource<T>(bool Function(T) predicate);
  static RunCondition resourceExists<T>();
  static RunCondition and(List<RunCondition> conditions);
  static RunCondition or(List<RunCondition> conditions);
  static RunCondition not(RunCondition condition);
  static RunCondition always();
  static RunCondition never();
}
```

### Static Methods

| Method | Description |
|--------|-------------|
| `resource<T>(predicate)` | True if resource matches predicate |
| `resourceExists<T>()` | True if resource exists |
| `and(conditions)` | True if all conditions are true |
| `or(conditions)` | True if any condition is true |
| `not(condition)` | Inverts a condition |
| `always()` | Always returns true |
| `never()` | Always returns false |

## FunctionSystem with runIf

```dart
class FunctionSystem implements System {
  FunctionSystem(
    String name, {
    RunCondition? runIf,
    required void Function(World) run,
    // ... other parameters
  });
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `runIf` | `RunCondition?` | Condition to check before running |

## Examples

### Resource Predicate

```dart
// Run only when game is not paused
app.addSystem(FunctionSystem(
  'gameplay',
  runIf: RunConditions.resource<GameConfig>(
    (config) => !config.isPaused,
  ),
  run: gameplaySystem,
));
```

### Resource Exists

```dart
// Run only when Player resource exists
app.addSystem(FunctionSystem(
  'playerSystem',
  runIf: RunConditions.resourceExists<PlayerData>(),
  run: playerSystem,
));
```

### Combining Conditions

```dart
// Run when playing AND not paused
final canRun = RunConditions.and([
  RunConditions.resource<GameState>((s) => s.isPlaying),
  RunConditions.not(
    RunConditions.resource<GameState>((s) => s.isPaused),
  ),
]);

app.addSystem(FunctionSystem(
  'movement',
  runIf: canRun,
  run: movementSystem,
));
```

### Or Conditions

```dart
// Run in menu OR game over state
app.addSystem(FunctionSystem(
  'showUI',
  runIf: RunConditions.or([
    InState<GameState>(GameState.menu).condition,
    InState<GameState>(GameState.gameOver).condition,
  ]),
  run: uiSystem,
));
```

### Custom Conditions

```dart
// Custom condition based on world state
RunCondition hasEnemies() {
  return (world) {
    return world.query1<Enemy>().iter().isNotEmpty;
  };
}

app.addSystem(FunctionSystem(
  'combat',
  runIf: hasEnemies(),
  run: combatSystem,
));
```

### Inline Conditions

```dart
app.addSystem(FunctionSystem(
  'debugSystem',
  runIf: (world) {
    final debug = world.getResource<DebugConfig>();
    return debug?.enabled ?? false;
  },
  run: debugSystem,
));
```

### State Conditions

Run conditions integrate with states:

```dart
// Using state conditions
app.addSystem(FunctionSystem(
  'gameplayOnly',
  runIf: InState<GameState>(GameState.playing).condition,
  run: gameplaySystem,
));

// On state enter
app.addSystem(FunctionSystem(
  'onEnter',
  runIf: OnEnterState<GameState>(GameState.playing).condition,
  run: initSystem,
));

// On state exit
app.addSystem(FunctionSystem(
  'onExit',
  runIf: OnExitState<GameState>(GameState.playing).condition,
  run: cleanupSystem,
));
```

### System Set Conditions

Apply conditions to entire system sets:

```dart
app
  .configureSet('gameplay', (set) => set
    .runIf(InState<GameState>(GameState.playing).condition))
  .addSystemToSet(movementSystem, 'gameplay')
  .addSystemToSet(physicsSystem, 'gameplay');
```

## Condition Evaluation

Conditions are evaluated each frame before running systems:

1. If condition is null, system always runs
2. If condition returns false, system is skipped
3. Skipped systems don't consume resources

## Performance

- Conditions are evaluated once per system per frame
- Short-circuit evaluation for `and`/`or`
- Prefer simple conditions over complex queries

## See Also

- [States Guide](/docs/guides/states)
- [State API](/docs/api/state)
- [System Sets](/docs/api/system-sets)
