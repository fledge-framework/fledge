# App API Reference

The `App` class provides a fluent builder for configuring and running ECS games.

## Import

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
```

## Constructor

```dart
App()
```

Creates a new App instance with an empty World and Schedule.

## Properties

### world

```dart
World get world
```

The ECS world containing all entities, components, resources, and events.

### schedule

```dart
Schedule get schedule
```

The schedule managing system execution.

### isRunning

```dart
bool get isRunning
```

Returns `true` if the app is currently running.

## Configuration Methods

### addPlugin(plugin)

```dart
App addPlugin(Plugin plugin)
```

Adds a plugin to the app. Calls the plugin's `build` method immediately.

```dart
app.addPlugin(TimePlugin());
```

### addPlugins(plugins)

```dart
App addPlugins(List<Plugin> plugins)
```

Adds multiple plugins in order.

```dart
app.addPlugins([TimePlugin(), RenderPlugin()]);
```

### insertResource<T>(resource)

```dart
App insertResource<T>(T resource)
```

Inserts a resource into the world.

```dart
app.insertResource(GameConfig(difficulty: 'hard'));
```

### addEvent<T>()

```dart
App addEvent<T>()
```

Registers an event type.

```dart
app.addEvent<CollisionEvent>();
```

### addSystem(system, {stage})

```dart
App addSystem(System system, {CoreStage stage = CoreStage.update})
```

Adds a system to the schedule.

```dart
app.addSystem(MovementSystemWrapper());
app.addSystem(RenderSystemWrapper(), stage: CoreStage.last);
```

### addSystems(systems, {stage})

```dart
App addSystems(List<System> systems, {CoreStage stage = CoreStage.update})
```

Adds multiple systems to the same stage.

```dart
app.addSystems([
  AISystemWrapper(),
  MovementSystemWrapper(),
], stage: CoreStage.update);
```

## Lifecycle Methods

### run()

```dart
Future<void> run()
```

Runs the game loop until `stop()` is called.

```dart
await app.run();
```

### tick()

```dart
Future<void> tick()
```

Executes a single frame. Updates events and runs all systems.

```dart
await app.tick();
```

### update()

```dart
Future<void> update()
```

Alias for `tick()`.

### stop()

```dart
void stop()
```

Stops the running game loop after the current frame completes.

```dart
app.onTick((app) {
  if (gameOver) app.stop();
});
```

## Callbacks

### onStart(callback)

```dart
App onStart(void Function(App app) callback)
```

Sets a callback called when `run()` starts.

```dart
app.onStart((app) => print('Game started!'));
```

### onTick(callback)

```dart
App onTick(void Function(App app) callback)
```

Sets a callback called each frame after systems run.

```dart
app.onTick((app) {
  if (shouldQuit) app.stop();
});
```

### onStop(callback)

```dart
App onStop(void Function(App app) callback)
```

Sets a callback called when the game loop ends.

```dart
app.onStop((app) => print('Game stopped!'));
```

## Example

```dart
void main() async {
  await App()
    .addPlugin(TimePlugin())
    .addPlugin(FrameLimiterPlugin(targetFps: 60))
    .insertResource(Score())
    .addEvent<CollisionEvent>()
    .addSystem(MovementSystemWrapper())
    .addSystem(CollisionSystemWrapper(), stage: CoreStage.postUpdate)
    .addSystem(RenderSystemWrapper(), stage: CoreStage.last)
    .onStart((app) => print('Starting...'))
    .onTick((app) {
      final score = app.world.getResource<Score>()!;
      if (score.value >= 100) app.stop();
    })
    .onStop((app) => print('Game over!'))
    .run();
}
```

## AppRunner

Helper class for running apps with frame timing.

### Constructor

```dart
AppRunner(App app, {Duration targetFrameTime = const Duration(milliseconds: 16)})
```

### run()

Runs the app with frame limiting.

```dart
final runner = AppRunner(app, targetFrameTime: Duration(milliseconds: 16));
await runner.run();
```

### runFrames(count)

Runs exactly `count` frames.

```dart
await runner.runFrames(100);
```

## See Also

- [Plugin](/docs/api/plugin) - Plugin interface
- [World](/docs/api/world) - World container
- [Schedule](/docs/api/schedule) - System scheduling
