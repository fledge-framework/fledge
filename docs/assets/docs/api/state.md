# State API

Game state machine for managing application phases.

## State<S>

A state machine for enum-based game states.

```dart
class State<S extends Enum> {
  State(S initial);

  S get current;
  bool get isPending;
  bool get justEntered;
  bool get justExited;

  bool isIn(S state);
  void set(S newState);
  void applyTransition();
  void clearTransitionFlags();
}
```

### Constructor

| Parameter | Type | Description |
|-----------|------|-------------|
| `initial` | `S` | The starting state |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `current` | `S` | The active state |
| `isPending` | `bool` | True if a transition is pending |
| `justEntered` | `bool` | True on the frame after entering current state |
| `justExited` | `bool` | True on the frame of exiting previous state |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `isIn(state)` | `bool` | Check if in specific state |
| `set(newState)` | `void` | Schedule state transition |
| `applyTransition()` | `void` | Apply pending transition |
| `clearTransitionFlags()` | `void` | Clear justEntered/justExited |

## InState<S>

Run condition that checks if currently in a state.

```dart
class InState<S extends Enum> {
  final S state;
  InState(this.state);

  RunCondition get condition;
}
```

### Usage

```dart
app.addSystem(FunctionSystem(
  'gameplaySystem',
  runIf: InState<GameState>(GameState.playing).condition,
  run: gameplaySystem,
));
```

## OnEnterState<S>

Run condition that fires once when entering a state.

```dart
class OnEnterState<S extends Enum> {
  final S state;
  OnEnterState(this.state);

  RunCondition get condition;
}
```

### Usage

```dart
app.addSystem(FunctionSystem(
  'onEnterPlaying',
  runIf: OnEnterState<GameState>(GameState.playing).condition,
  run: (world) {
    // Initialize gameplay - runs once on enter
  },
));
```

## OnExitState<S>

Run condition that fires once when exiting a state.

```dart
class OnExitState<S extends Enum> {
  final S state;
  OnExitState(this.state);

  RunCondition get condition;
}
```

### Usage

```dart
app.addSystem(FunctionSystem(
  'onExitPlaying',
  runIf: OnExitState<GameState>(GameState.playing).condition,
  run: (world) {
    // Cleanup - runs once on exit
  },
));
```

## App State Methods

```dart
extension on App {
  App addState<S extends Enum>(S initial);
  App addSystemInState<S extends Enum>(System system, S state);
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `addState<S>(initial)` | `App` | Register a state machine |
| `addSystemInState(system, state)` | `App` | Add system that runs only in state |

## Example

Complete state management example:

```dart
enum GameState { menu, playing, paused, gameOver }

final app = App()
  // Register state with initial value
  .addState<GameState>(GameState.menu)

  // Menu systems
  .addSystemInState(menuRenderSystem, GameState.menu)
  .addSystemInState(menuInputSystem, GameState.menu)

  // Gameplay systems
  .addSystemInState(movementSystem, GameState.playing)
  .addSystemInState(aiSystem, GameState.playing)

  // Pause overlay
  .addSystemInState(pauseRenderSystem, GameState.paused)

  // Transition handlers
  .addSystem(FunctionSystem(
    'onEnterPlaying',
    runIf: OnEnterState<GameState>(GameState.playing).condition,
    run: (world) {
      world.spawn()..insert(Player());
    },
  ))
  .addSystem(FunctionSystem(
    'onExitPlaying',
    runIf: OnExitState<GameState>(GameState.playing).condition,
    run: (world) {
      // Save game state
    },
  ));

// In a system, change state:
void pauseSystem(World world) {
  if (pausePressed) {
    world.getResource<State<GameState>>()?.set(GameState.paused);
  }
}
```

## State Lifecycle

```
Frame N:
  1. System calls state.set(newState)
  2. isPending = true, justExited = true

Frame N+1 (after applyTransition):
  1. current = newState, isPending = false
  2. justEntered = true, justExited = false

Frame N+2 (after clearTransitionFlags):
  1. justEntered = false
```

## See Also

- [States Guide](/docs/guides/states)
- [Run Conditions](/docs/api/run-conditions)
- [Scheduling](/docs/guides/scheduling)
