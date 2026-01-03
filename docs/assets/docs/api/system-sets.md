# System Sets API

Group systems for bulk configuration.

## SystemSet

A named group of systems with shared configuration.

```dart
class SystemSet {
  final String name;

  SystemSet after(String name);
  SystemSet before(String name);
  SystemSet runIf(RunCondition condition);
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | The set identifier |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `after(name)` | `SystemSet` | Add after ordering constraint |
| `before(name)` | `SystemSet` | Add before ordering constraint |
| `runIf(condition)` | `SystemSet` | Set run condition for all systems |

## SystemSetRegistry

Registry for system sets.

```dart
class SystemSetRegistry {
  void configure(String name, void Function(SystemSet) config);
  SystemSet? get(String name);
  bool contains(String name);
  Set<String> get setNames;
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `configure(name, config)` | `void` | Configure a set |
| `get(name)` | `SystemSet?` | Get set by name |
| `contains(name)` | `bool` | Check if set exists |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `setNames` | `Set<String>` | All configured set names |

## SetConfiguredSystem

Wrapper that applies set configuration to a system.

```dart
class SetConfiguredSystem implements System {
  final System inner;
  final SystemSet set;

  SystemMeta get meta;
  RunCondition? get runCondition;
}
```

Set configuration is merged with system configuration:
- Ordering constraints are combined
- Run conditions are AND-ed together

## App Methods

```dart
extension on App {
  App configureSet(String name, void Function(SystemSet) config);
  App addSystemToSet(System system, String setName);
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `configureSet(name, config)` | `App` | Configure a system set |
| `addSystemToSet(system, setName)` | `App` | Add system to a set |

## Examples

### Basic Set Configuration

```dart
app
  // Configure the set
  .configureSet('physics', (set) => set
    .after('input')
    .before('render'))

  // Add systems to the set
  .addSystemToSet(gravitySystem, 'physics')
  .addSystemToSet(collisionSystem, 'physics')
  .addSystemToSet(velocitySystem, 'physics');
```

### Set with Run Condition

```dart
app
  .configureSet('gameplay', (set) => set
    .runIf(InState<GameState>(GameState.playing).condition))

  .addSystemToSet(movementSystem, 'gameplay')
  .addSystemToSet(aiSystem, 'gameplay')
  .addSystemToSet(combatSystem, 'gameplay');
```

### Multiple Ordering Constraints

```dart
app
  .configureSet('simulation', (set) => set
    .after('input')
    .after('ai')
    .before('render')
    .before('cleanup'));
```

### Ordering Between Sets

```dart
app
  .configureSet('input', (set) => set)
  .configureSet('simulation', (set) => set.after('input'))
  .configureSet('render', (set) => set.after('simulation'))

  .addSystemToSet(keyboardSystem, 'input')
  .addSystemToSet(physicsSystem, 'simulation')
  .addSystemToSet(spriteSystem, 'render');
```

### Combined Set and System Config

```dart
// System has its own ordering
final movementSystem = FunctionSystem(
  'movement',
  after: ['velocity'],  // System-level constraint
  run: movement,
);

// Set adds more constraints
app
  .configureSet('physics', (set) => set.before('render'))
  .addSystemToSet(movementSystem, 'physics');

// Result: movement runs after 'velocity' AND before 'render'
```

### Conditional Sets

```dart
app
  .configureSet('debug', (set) => set
    .runIf(RunConditions.resource<DebugConfig>((c) => c.enabled)))

  .addSystemToSet(debugRenderSystem, 'debug')
  .addSystemToSet(statsSystem, 'debug');
```

### State-Based Sets

```dart
app
  .addState<GameState>(GameState.menu)

  .configureSet('menuSystems', (set) => set
    .runIf(InState<GameState>(GameState.menu).condition))

  .configureSet('playingSystems', (set) => set
    .runIf(InState<GameState>(GameState.playing).condition))

  .addSystemToSet(menuRenderSystem, 'menuSystems')
  .addSystemToSet(movementSystem, 'playingSystems');
```

## Set Resolution

When a system is added to a set:

1. Set configuration is looked up by name
2. System is wrapped in `SetConfiguredSystem`
3. Ordering constraints from set are added to system's constraints
4. Run conditions are combined with AND

## Notes

- Sets must be configured before adding systems to them
- Systems can only belong to one set
- Set ordering affects all systems in the set
- Individual system ordering is combined with set ordering

## See Also

- [System Ordering Guide](/docs/guides/system-ordering)
- [Run Conditions API](/docs/api/run-conditions)
- [Schedule API](/docs/api/schedule)
