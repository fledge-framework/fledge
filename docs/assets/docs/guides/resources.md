# Resources Guide

Resources are global singleton data accessible by all systems. Unlike components which are attached to entities, resources are shared across the entire world.

## Defining Resources

Resources are plain Dart classes. No annotation is required:

```dart
class Time {
  double delta = 0.0;
  double elapsed = 0.0;
}

class GameConfig {
  final String difficulty;
  final int maxEnemies;

  GameConfig({
    this.difficulty = 'normal',
    this.maxEnemies = 100,
  });
}

class Score {
  int value = 0;
}
```

## Inserting Resources

Add resources using the App builder (recommended):

```dart
App()
  .addPlugin(TimePlugin())  // Adds Time resource automatically
  .insertResource(GameConfig(difficulty: 'hard'))
  .insertResource(Score())
  .run();
```

Or inside a plugin:

```dart
class GamePlugin implements Plugin {
  @override
  void build(App app) {
    app.insertResource(GameConfig());
    app.insertResource(Score());
  }

  @override
  void cleanup() {}
}
```

> **Note:** The method is `insertResource` (not just `insert`) because resources are global singletons added to the world itself. In contrast, `insert` is used for components which are added to specific entities. See [Core Concepts](/docs/getting-started/core-concepts) for a detailed comparison.

## Accessing Resources in Systems

Access resources directly from the World:

```dart-tabs
// @tab Annotations
@system
void displayScore(World world) {
  final score = world.getResource<Score>();
  if (score != null) {
    print('Current score: ${score.value}');
  }
}

@system
void updateTime(World world) {
  final time = world.getResource<Time>();
  if (time != null) {
    time.elapsed += time.delta;
  }
}

@system
void addScore(World world) {
  final score = world.getResource<Score>()!;
  for (final (entity, _) in world.query1<Collected>().iter()) {
    score.value += 10;
  }
}
// @tab Inheritance
class DisplayScoreSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'displayScore',
        resourceReads: {Score},
      );

  @override
  Future<void> run(World world) async {
    final score = world.getResource<Score>();
    if (score != null) {
      print('Current score: ${score.value}');
    }
  }
}

class UpdateTimeSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'updateTime',
        resourceWrites: {Time},
      );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>();
    if (time != null) {
      time.elapsed += time.delta;
    }
  }
}

class AddScoreSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'addScore',
        resourceWrites: {Score},
      );

  @override
  Future<void> run(World world) async {
    final score = world.getResource<Score>()!;
    for (final (entity, _) in world.query1<Collected>().iter()) {
      score.value += 10;
    }
  }
}
```

### Optional Resources

Check if a resource exists before using it:

```dart-tabs
// @tab Annotations
@system
void debugSystem(World world) {
  final debug = world.getResource<DebugConfig>();
  if (debug != null) {
    // Debug mode is enabled
    print('Debug: ${debug.showFps}');
  }
}
// @tab Inheritance
class DebugSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'debug',
        resourceReads: {DebugConfig},
      );

  @override
  Future<void> run(World world) async {
    final debug = world.getResource<DebugConfig>();
    if (debug != null) {
      // Debug mode is enabled
      print('Debug: ${debug.showFps}');
    }
  }
}
```

## Direct World Access

You can also access resources directly from the World:

```dart
// Get a resource
final time = world.getResource<Time>();
if (time != null) {
  print('Elapsed: ${time.elapsed}');
}

// Check if resource exists
if (world.hasResource<GameConfig>()) {
  // Config is available
}

// Remove a resource
final removed = world.removeResource<Score>();
```

## Resource Conflicts

Resources participate in the scheduling conflict detection. Systems accessing the same resource may need ordering:

```dart-tabs
// @tab Annotations
// These systems both modify Score
@system
void systemA(World world) {
  final score = world.getResource<Score>()!;
  score.value += 10;
}

@system
void systemB(World world) {
  final score = world.getResource<Score>()!;
  score.value *= 2;
}

// These can run in parallel (different resources)
@system
void systemC(World world) {
  final time = world.getResource<Time>()!;
  print(time.elapsed);
}

@system
void systemD(World world) {
  final score = world.getResource<Score>()!;
  score.value += 1;
}
// @tab Inheritance
// These systems both modify Score
class SystemA implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemA', resourceWrites: {Score});

  @override
  Future<void> run(World world) async {
    final score = world.getResource<Score>()!;
    score.value += 10;
  }
}

class SystemB implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemB', resourceWrites: {Score});

  @override
  Future<void> run(World world) async {
    final score = world.getResource<Score>()!;
    score.value *= 2;
  }
}

// These can run in parallel (different resources)
class SystemC implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemC', resourceReads: {Time});

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>()!;
    print(time.elapsed);
  }
}

class SystemD implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'systemD', resourceWrites: {Score});

  @override
  Future<void> run(World world) async {
    final score = world.getResource<Score>()!;
    score.value += 1;
  }
}
```

## Common Resource Patterns

### Time Resource

```dart-tabs
// @tab Annotations
class Time {
  double delta = 0.0;      // Seconds since last frame
  double elapsed = 0.0;    // Total seconds since start
  int frameCount = 0;

  void update(double dt) {
    delta = dt;
    elapsed += dt;
    frameCount++;
  }
}

@system
void movementSystem(World world) {
  final dt = world.getResource<Time>()!.delta;
  for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx * dt;
    pos.y += vel.dy * dt;
  }
}
// @tab Inheritance
class Time {
  double delta = 0.0;      // Seconds since last frame
  double elapsed = 0.0;    // Total seconds since start
  int frameCount = 0;

  void update(double dt) {
    delta = dt;
    elapsed += dt;
    frameCount++;
  }
}

class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
        resourceReads: {Time},
      );

  @override
  Future<void> run(World world) async {
    final dt = world.getResource<Time>()!.delta;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}
```

### Input State

```dart-tabs
// @tab Annotations
class Input {
  final Set<String> keysDown = {};
  double mouseX = 0;
  double mouseY = 0;
  bool mousePressed = false;
}

@system
void playerControl(World world) {
  final input = world.getResource<Input>()!;
  for (final (_, vel, _) in world.query2<Velocity, Player>().iter()) {
    vel.dx = 0;
    vel.dy = 0;

    if (input.keysDown.contains('ArrowLeft')) vel.dx = -1;
    if (input.keysDown.contains('ArrowRight')) vel.dx = 1;
    if (input.keysDown.contains('ArrowUp')) vel.dy = -1;
    if (input.keysDown.contains('ArrowDown')) vel.dy = 1;
  }
}
// @tab Inheritance
class Input {
  final Set<String> keysDown = {};
  double mouseX = 0;
  double mouseY = 0;
  bool mousePressed = false;
}

class PlayerControlSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'playerControl',
        writes: {ComponentId.of<Velocity>()},
        resourceReads: {Input},
      );

  @override
  Future<void> run(World world) async {
    final input = world.getResource<Input>()!;
    for (final (_, vel, _) in world.query2<Velocity, Player>().iter()) {
      vel.dx = 0;
      vel.dy = 0;

      if (input.keysDown.contains('ArrowLeft')) vel.dx = -1;
      if (input.keysDown.contains('ArrowRight')) vel.dx = 1;
      if (input.keysDown.contains('ArrowUp')) vel.dy = -1;
      if (input.keysDown.contains('ArrowDown')) vel.dy = 1;
    }
  }
}
```

### Game State

```dart-tabs
// @tab Annotations
enum GamePhase { menu, playing, paused, gameOver }

class GameState {
  GamePhase phase = GamePhase.menu;
  int level = 1;
  int lives = 3;
}

@system
void checkGameOver(World world) {
  final players = world.query1<Player>();
  if (players.isEmpty) {
    final state = world.getResource<GameState>()!;
    state.lives--;
    if (state.lives <= 0) {
      state.phase = GamePhase.gameOver;
    }
  }
}
// @tab Inheritance
enum GamePhase { menu, playing, paused, gameOver }

class GameState {
  GamePhase phase = GamePhase.menu;
  int level = 1;
  int lives = 3;
}

class CheckGameOverSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'checkGameOver',
        resourceWrites: {GameState},
      );

  @override
  Future<void> run(World world) async {
    final players = world.query1<Player>();
    if (players.isEmpty) {
      final state = world.getResource<GameState>()!;
      state.lives--;
      if (state.lives <= 0) {
        state.phase = GamePhase.gameOver;
      }
    }
  }
}
```

## Utility Traits

Fledge provides utility mixins and interfaces for common resource patterns.

### ChangeTracking Mixin

Track whether a resource was modified during the current frame:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class Inventory with ChangeTracking {
  final List<Item> items = [];

  void addItem(Item item) {
    items.add(item);
    markChanged();  // Flag modification
  }

  void removeItem(Item item) {
    items.remove(item);
    markChanged();
  }
}
```

**Usage in systems:**

```dart
// At frame start - reset tracking
@system
void inventoryFrameReset(World world) {
  world.getResource<Inventory>()?.resetChangeTracking();
}

// In UI update - check if changed
void updateUI() {
  final inventory = world.getResource<Inventory>()!;
  if (inventory.changedThisFrame) {
    rebuildInventoryUI();
  }
}
```

**API:**
- `changedThisFrame` - Whether modified this frame
- `markChanged()` - Flag as modified
- `resetChangeTracking()` - Clear the flag (call at frame start)

### FrameAware Interface

Resources that need automatic per-frame lifecycle callbacks:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class InputState implements FrameAware {
  bool _jumpPressed = false;
  bool _jumpPressedThisFrame = false;

  @override
  void beginFrame() {
    // Reset per-frame tracking
    _jumpPressedThisFrame = false;
  }

  void onJumpPressed() {
    _jumpPressed = true;
    _jumpPressedThisFrame = true;
  }

  bool get jumpPressedThisFrame => _jumpPressedThisFrame;
}
```

**Note:** The framework does not automatically call `beginFrame()`. Create a system to call it at frame start:

```dart
@system
void frameResetSystem(World world) {
  world.getResource<InputState>()?.beginFrame();
  world.getResource<Inventory>()?.beginFrame();
}
```

### Combining Traits

Resources can use multiple patterns:

```dart
class PlayerInventory with ChangeTracking implements FrameAware {
  final List<Item> items = [];
  Item? lastAddedItem;

  @override
  void beginFrame() {
    resetChangeTracking();
    lastAddedItem = null;
  }

  void addItem(Item item) {
    items.add(item);
    lastAddedItem = item;
    markChanged();
  }
}
```

## Resources from Core Plugins

Fledge's [core plugins](/docs/plugins/overview#core-plugins) provide common resources:

### TimePlugin

```dart-tabs
// @tab Annotations
App()
  .addPlugin(TimePlugin())
  .run();

// Provides Time resource updated each frame
@system
void mySystem(World world) {
  final time = world.getResource<Time>()!;
  print('Delta: ${time.delta}');
  print('Elapsed: ${time.elapsed}');
  print('Frame: ${time.frameCount}');
}
// @tab Inheritance
App()
  .addPlugin(TimePlugin())
  .run();

// Provides Time resource updated each frame
class MySystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'mySystem',
        resourceReads: {Time},
      );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>()!;
    print('Delta: ${time.delta}');
    print('Elapsed: ${time.elapsed}');
    print('Frame: ${time.frameCount}');
  }
}
```

### FrameLimiterPlugin

```dart-tabs
// @tab Annotations
App()
  .addPlugin(FrameLimiterPlugin(targetFps: 60))
  .run();

// Provides FrameTime resource with timing info
@system
void debugFps(World world) {
  final frameTime = world.getResource<FrameTime>()!;
  print('FPS: ${frameTime.fps.toStringAsFixed(1)}');
}
// @tab Inheritance
App()
  .addPlugin(FrameLimiterPlugin(targetFps: 60))
  .run();

// Provides FrameTime resource with timing info
class DebugFpsSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'debugFps',
        resourceReads: {FrameTime},
      );

  @override
  Future<void> run(World world) async {
    final frameTime = world.getResource<FrameTime>()!;
    print('FPS: ${frameTime.fps.toStringAsFixed(1)}');
  }
}
```

## See Also

- [Events](/docs/guides/events) - Inter-system communication
- [Systems](/docs/guides/systems) - Using resources in systems
- [App & Plugins](/docs/guides/app-plugins) - Resource initialization
- [Save System](/docs/plugins/save) - Persisting resources with the Saveable mixin
