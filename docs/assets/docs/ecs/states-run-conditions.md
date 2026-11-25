# States & Run Conditions

A **run condition** decides, each time a system is due, whether it runs. A
**state** is an enum-valued resource (`menu`, `playing`, `paused`) with
transition tracking, plus run conditions built on it. Together they let you
switch whole groups of systems on and off.

<!-- snippet-setup
enum GameState { loading, menu, playing, paused }

enum Weather { clear, rain }

class Player {}

class Enemy {}

class CollisionEvent {}

class Settings {
  bool debugOverlay = false;
}

class MenuSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'menu');

  @override
  void run(World world) {}
}

class MovementSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'movement');

  @override
  void run(World world) {}
}

class PhysicsStepSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'physicsStep');

  @override
  void run(World world) {}
}
-->

## Run conditions

A `RunCondition` is a function `bool Function(World)`. Pass one as `runIf:` to
`FunctionSystem`, or override `runCondition` in a class system:

```dart
final debugOverlay = FunctionSystem(
  'debugOverlay',
  runIf: (world) => world.getResource<Settings>()?.debugOverlay ?? false,
  run: (world) {
    // draw overlay
  },
);

class SpawnEnemiesSystem extends System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'spawnEnemies');

  @override
  RunCondition? get runCondition =>
      (world) => world.query1<Player>().isNotEmpty;

  @override
  void run(World world) {}
}
```

The scheduler checks the condition right before the system's turn. A skipped
system doesn't run at all that frame, and its
[change detection](/docs/ecs/change-detection) baseline stays where it was.

### Built-in conditions

| Condition | True when |
|---|---|
| `RunConditions.resource<T>((r) => ...)` | `T` exists and the predicate holds |
| `RunConditions.resourceExists<T>()` | `T` exists |
| `RunConditions.onEvent<T>()` | `T` is registered and has events to read this frame |
| `RunConditions.and([...])` / `or([...])` / `not(c)` | combinations |
| `RunConditions.always()` / `never()` | constant (`never` disables a system) |

```dart
final collisionSound = FunctionSystem(
  'collisionSound',
  eventReads: {CollisionEvent},
  runIf: RunConditions.and([
    RunConditions.onEvent<CollisionEvent>(),
    RunConditions.not(
      RunConditions.resource<Settings>((s) => s.debugOverlay),
    ),
  ]),
  run: (world) {
    // play a sound per event
  },
);
```

A [system set](/docs/scheduling/ordering-and-sets#system-sets) can carry a run
condition that applies to all its members.

## States

### Adding a state

Define an enum and add it with an initial value. `addState` stores a
`State<GameState>` resource:

```dart
final app = App()..addState<GameState>(GameState.loading);
```

### Systems that run in a state

`addSystemInState` registers a system with an `InState` condition. It takes a
`System` (a class instance, a `FunctionSystem`, or a generated `XWrapper()`),
not a function:

```dart
final app = App()
  ..addState<GameState>(GameState.menu)
  ..addSystemInState(MenuSystem(), GameState.menu)
  ..addSystemInState(MovementSystem(), GameState.playing)
  ..addSystemInState(
    PhysicsStepSystem(),
    GameState.playing,
    schedule: Schedules.fixedUpdate,
  );
```

Without `schedule:` it goes in `Schedules.update`. If the system already has a
run condition, both must hold.

### Reading and changing state

```dart
final world = App().addState<GameState>(GameState.menu).world;

world.getState<GameState>(); // GameState.menu (null if never added)
world.isInState(GameState.menu); // true
world.setState(GameState.playing); // requests a transition

final state = world.getResource<State<GameState>>()!;
state.current; // still GameState.menu
state.isPending; // true
state.cancelTransition(); // never mind
```

`setState` (or `State.set`) only *requests* a transition. Setting the current
state is ignored; setting twice in a frame keeps the last request.

### When transitions happen

`App.tick` applies pending transitions **at the very end of the tick**, after
`render`. So:

1. Frame N: a system calls `world.setState(GameState.playing)`. Every system in
   frame N, before or after it, still sees `menu`.
2. End of frame N: the state becomes `playing`.
3. Frame N + 1: `current` is `playing`; `justEntered` is true and
   `justEnteredState(GameState.playing)` is true; `justExited` is true,
   `justExitedState(GameState.menu)` is true and `previous` is `menu`.
4. Frame N + 2: the flags are false again (unless another transition
   happened), and `previous` is null.

The initial state counts as entered on the first frame, so an
`OnEnterState` for it runs once at startup.

### Enter and exit systems

`OnEnterState` and `OnExitState` are conditions that are true on the frame
after the transition (step 3 above). Both fire on that same frame:

```dart
final spawnLevel = FunctionSystem(
  'spawnLevel',
  runIf: OnEnterState(GameState.playing).condition,
  run: (world) {
    world.spawnWith([Player()]);
  },
);

final clearLevel = FunctionSystem(
  'clearLevel',
  runIf: OnExitState(GameState.playing).condition,
  run: (world) {
    final commands = Commands();
    for (final (entity, _) in world.query1<Enemy>().iter()) {
      commands.despawn(entity);
    }
    commands.apply(world);
  },
);

final app = App()
  ..addState<GameState>(GameState.menu)
  ..addSystem(spawnLevel)
  ..addSystem(clearLevel);
```

Because the flags last for a whole tick, put enter/exit systems in a
per-frame schedule (`update`, `preUpdate`, ...). In a fixed-step schedule they
would run once per fixed step that frame, which may be zero times or several.

### Other state conditions

| Condition | True when |
|---|---|
| `InState(s).condition` | current state is `s` |
| `StateConditions.inAny([a, b])` | current state is any of them |
| `StateConditions.notIn(s)` | the state exists and isn't `s` |
| `StateConditions.transitionPending<S>()` | a `setState` is waiting to apply |

```dart
final hud = FunctionSystem(
  'hud',
  runIf: StateConditions.inAny([GameState.playing, GameState.paused]),
  run: (world) {},
);
```

### Several state machines

Each enum type is its own state, applied independently:

```dart
final app = App()
  ..addState<GameState>(GameState.menu)
  ..addState<Weather>(Weather.clear);

final rainParticles = FunctionSystem(
  'rainParticles',
  runIf: RunConditions.and([
    InState(GameState.playing).condition,
    InState(Weather.rain).condition,
  ]),
  run: (world) {},
);
```

### Driving `State` yourself

Outside an `App` nothing applies transitions for you. Call `applyTransition()`
once per frame on the `State` resource; `clearFlags()` resets
`justEntered`/`justExited` without applying anything.

## Loading screens

Don't `await` asset loads inside a system to "finish loading" before
switching states: that stalls the frame. Start loading in an `OnEnterState`
system, then have a per-frame system check whether loading is done and call
`setState` when it is. See [Assets](/docs/app/assets).

## See also

- [Systems](/docs/ecs/systems)
- [Ordering & Sets](/docs/scheduling/ordering-and-sets)
- [Events](/docs/ecs/events)
