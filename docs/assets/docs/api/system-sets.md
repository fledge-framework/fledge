# System Sets API

Group systems for bulk configuration.

> **Behaviour change in 0.4.0:** set ordering now resolves to the set's *members*. In earlier versions a set's `before` / `after` only matched **system** names, so `configureSet('physics', (s) => s.after('input'))` silently did nothing unless a system was literally named `'input'`. If you relied on that (accidental) no-op, check for new ordering cycles when upgrading.

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
| `after(name)` | `SystemSet` | Every member runs after the system **or set** called `name` |
| `before(name)` | `SystemSet` | Every member runs before the system **or set** called `name` |
| `runIf(condition)` | `SystemSet` | Set run condition for all systems |

## SystemSetRegistry

Registry for system sets. The `Scheduler` owns one (`app.scheduler.sets`), shared by every schedule.

```dart
class SystemSetRegistry {
  void configure(String name, void Function(SystemSet) config);
  SystemSet getOrCreate(String name);
  SystemSet? get(String name);
  bool contains(String name);
  Iterable<SystemSet> get all;
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `configure(name, config)` | `void` | Configure a set (created if missing) |
| `getOrCreate(name)` | `SystemSet` | Get a set, creating it if needed |
| `get(name)` | `SystemSet?` | Get set by name |
| `contains(name)` | `bool` | Check if set exists |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `all` | `Iterable<SystemSet>` | Every configured set, in creation order |

> Configure sets through `App.configureSet` / `Scheduler.configureSet`, not the registry directly — those rebuild every schedule's dependency graph so the change applies to systems already registered. Mutating the registry directly only takes effect on the next `addSystem`.

## SetConfiguredSystem

Wrapper used by `App.addSystemToSet` to record set membership on a system.

```dart
class SetConfiguredSystem implements System {
  SetConfiguredSystem(System inner, SystemSet set);

  SystemMeta get meta;            // inner meta, with set.name prepended to `sets`
  RunCondition? get runCondition; // set condition AND inner condition
}
```

- The set's name is added to the wrapped meta's `sets`
- Run conditions are AND-ed together
- Ordering comes from the set registry at graph-build time, so constraints configured *after* the system was added still apply

## Declaring Membership in `SystemMeta`

Instead of `addSystemToSet`, a system can declare the sets it belongs to with `SystemMeta.sets` (or the `sets:` parameter on `FunctionSystem` / `AsyncFunctionSystem`). A system may belong to several sets.

```dart
app.addSystem(FunctionSystem(
  'gravity',
  sets: ['physics'],
  writes: {ComponentId.of<Velocity>()},
  run: gravity,
));

class CollisionSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
    name: 'collision',
    sets: ['physics'],
    writes: {ComponentId.of<Velocity>()},
  );
  // ...
}
```

Membership via `sets:` does not apply a set's `runIf` condition — only `addSystemToSet` wraps the system for that.

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
| `configureSet(name, config)` | `App` | Configure a system set. Delegates to `Scheduler.configureSet`. Throws `StateError` (and changes nothing) if the new constraints form a cycle |
| `addSystemToSet(system, setName)` | `App` | Add system to a set (wraps it in `SetConfiguredSystem`) |

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

The scheduler rebuilds each schedule's dependency graph whenever a system is added or a set is configured:

1. A name in any `before:` / `after:` — on a `SystemMeta` or on a `SystemSet` — resolves to every system with that `name` **plus** every system whose `sets` contains it.
2. Set-to-set edges close transitively, so an empty set still bridges a chain: `A before B` and `B before C` orders A's members before C's even if B has no members in that schedule.
3. Set constraints apply within each schedule to whichever members that schedule contains; they never order systems across schedules.
4. Remaining conflicting pairs that no explicit chain orders fall back to registration order (see [System Ordering](/docs/guides/system-ordering)).

If an `addSystem` or `configureSet` call would create a cycle it throws a `StateError` and the schedule is left unchanged. The message lists the systems on the cycle in execution order, each followed by its sets, e.g. `physics_step [physics] -> read_input [input] -> physics_step [physics]`.

## Notes

- Sets can be configured before or after their members are added
- A system can belong to several sets (via `sets:`)
- Set ordering affects all systems in the set
- Individual system ordering is combined with set ordering
- `checkScheduleOrdering()` treats set-derived and transitive edges as explicit ordering
- The default `Scheduler()` pre-configures the [standard phases of `first`](/docs/guides/scheduling#standard-phases-of-first) (`FirstSets`)

## See Also

- [System Ordering Guide](/docs/guides/system-ordering)
- [Run Conditions API](/docs/api/run-conditions)
- [Schedule API](/docs/api/schedule)
