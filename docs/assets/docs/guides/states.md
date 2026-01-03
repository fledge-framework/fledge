# States Guide

Fledge provides a state machine for managing game states like menus, gameplay, and pause screens.

## Overview

States let you:

- Define distinct game phases (menu, playing, paused, game over)
- Run systems only in specific states
- Execute code on state transitions (enter/exit)
- Manage complex game flow

## Defining States

States are enums that define your game phases:

```dart
enum GameState { menu, playing, paused, gameOver }

enum LoadingState { loading, ready }
```

## Registering States

Register states with your App and set an initial value:

```dart
final app = App()
  .addState<GameState>(GameState.menu)
  .addState<LoadingState>(LoadingState.loading);
```

## State-Specific Systems

Add systems that only run in certain states:

```dart
app
  .addSystemInState(movementSystem, GameState.playing)
  .addSystemInState(aiSystem, GameState.playing)
  .addSystemInState(menuRenderSystem, GameState.menu);
```

## Checking State

Access state in systems via resources:

```dart
void mySystem(World world) {
  final state = world.getResource<State<GameState>>();
  if (state?.current == GameState.playing) {
    // Game is active
  }
}
```

## Changing State

Request a state transition:

```dart
void pauseSystem(World world) {
  if (pauseButtonPressed) {
    world.getResource<State<GameState>>()?.set(GameState.paused);
  }
}
```

State transitions are applied at the end of the frame to ensure consistency.

## Transition Events

### On Enter

Run code when entering a state:

```dart
app.addSystem(FunctionSystem(
  'onEnterPlaying',
  runIf: OnEnterState<GameState>(GameState.playing).condition,
  run: (world) {
    // Initialize gameplay
    world.spawn()..insert(Player());
    world.insertResource(GameTime(0));
  },
));
```

### On Exit

Run code when leaving a state:

```dart
app.addSystem(FunctionSystem(
  'onExitPlaying',
  runIf: OnExitState<GameState>(GameState.playing).condition,
  run: (world) {
    // Cleanup
    world.removeResource<GameTime>();
  },
));
```

## State Conditions

Use state conditions with run conditions:

```dart
// Only run when in playing state
final inPlaying = InState<GameState>(GameState.playing);

app.addSystem(FunctionSystem(
  'playingOnly',
  runIf: inPlaying.condition,
  run: (world) { /* ... */ },
));
```

### Combining Conditions

```dart
// Run when playing AND not paused
final canRun = RunConditions.and([
  InState<GameState>(GameState.playing).condition,
  RunConditions.not(InState<GameState>(GameState.paused).condition),
]);
```

## Common Patterns

### Menu to Gameplay

```dart
enum GameState { menu, playing }

void startGameSystem(World world) {
  if (startButtonPressed) {
    world.getResource<State<GameState>>()?.set(GameState.playing);
  }
}

app
  .addState<GameState>(GameState.menu)
  .addSystem(FunctionSystem('startGame', run: startGameSystem))
  .addSystemInState(gameplaySystem, GameState.playing);
```

### Pause System

```dart
enum GameState { playing, paused }

void togglePauseSystem(World world) {
  final state = world.getResource<State<GameState>>();
  if (pauseKeyPressed && state != null) {
    if (state.current == GameState.playing) {
      state.set(GameState.paused);
    } else if (state.current == GameState.paused) {
      state.set(GameState.playing);
    }
  }
}
```

### Loading Screen

```dart
enum LoadingState { loading, ready }

void loadingSystem(World world) async {
  // Load assets...
  await loadAssets();
  world.getResource<State<LoadingState>>()?.set(LoadingState.ready);
}

app
  .addState<LoadingState>(LoadingState.loading)
  .addSystemInState(loadingSystem, LoadingState.loading)
  .addSystemInState(gameSystem, LoadingState.ready);
```

## Multiple State Machines

You can have multiple independent state machines:

```dart
enum GameState { menu, playing }
enum AudioState { muted, normal, loud }

app
  .addState<GameState>(GameState.menu)
  .addState<AudioState>(AudioState.normal)
  .addSystemInState(playMusicSystem, AudioState.normal)
  .addSystemInState(playMusicLoudSystem, AudioState.loud);
```

## See Also

- [Run Conditions](/docs/api/run-conditions) - Conditional system execution
- [Scheduling](/docs/guides/scheduling) - System ordering
- [State API](/docs/api/state) - API reference
