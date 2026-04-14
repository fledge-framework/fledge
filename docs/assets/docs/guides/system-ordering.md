# System Ordering Guide

Control the execution order of your systems with explicit ordering constraints.

## Overview

By default, Fledge determines system order based on component access conflicts. However, you often need explicit ordering:

- Input must be processed before movement
- Movement must complete before collision detection
- Rendering must happen after all logic

## Basic Ordering

### After Constraint

Run a system after another:

```dart
app
  .addSystem(FunctionSystem('input', run: inputSystem))
  .addSystem(FunctionSystem('movement',
    after: ['input'],
    run: movementSystem,
  ));
```

### Before Constraint

Run a system before another:

```dart
app
  .addSystem(FunctionSystem('render', run: renderSystem))
  .addSystem(FunctionSystem('physics',
    before: ['render'],
    run: physicsSystem,
  ));
```

### Multiple Constraints

Systems can have multiple ordering constraints:

```dart
app.addSystem(FunctionSystem(
  'collision',
  after: ['movement', 'physics'],
  before: ['render', 'cleanup'],
  run: collisionSystem,
));
```

## Conflict-Based Ordering

When systems access the same components, Fledge orders them automatically:

```dart-tabs
// @tab Annotations
// These systems access Position - they'll run sequentially
@system
void moveSystem(World world) { /* writes Position */ }

@system
void renderSystem(World world) { /* reads Position */ }
// @tab Inheritance
// These systems access Position - they'll run sequentially
class MoveSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'move', writes: {ComponentId.of<Position>()});

  @override
  Future<void> run(World world) async { /* writes Position */ }
}

class RenderSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'render', reads: {ComponentId.of<Position>()});

  @override
  Future<void> run(World world) async { /* reads Position */ }
}
```

Explicit ordering constraints combine with automatic conflict detection.

### Registration order breaks ties — and it's a trap

When two systems in the same stage conflict (shared component write, or one writes what the other reads) and **neither declares `before:` / `after:`**, the scheduler still has to pick an order. It breaks the tie by the order the systems were registered with the `App`.

That's fine when the order happens to be what you want. The failure mode is when it's *not* — and the most common case is a new movement/AI/steering system that writes `Velocity` being registered *after* the physics plugin's `collision_resolution` (which also writes `Velocity`):

```
collision_resolution runs first  → clamps last frame's velocity
input/movement runs second       → overwrites with a wall-ward velocity
velocity integration             → pushes the entity through the wall
```

Everything compiles, every test passes, the player silently clips through walls.

Two fixes:

```dart
// Option A — put the movement system in an earlier stage. Stage
// boundaries always beat intra-stage ordering.
app.addSystem(MyMovementSystem(), stage: CoreStage.preUpdate);

// Option B — stay in update but say so explicitly.
class MyMovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'my_movement',
    writes: {ComponentId.of<Velocity>()},
    before: const ['collision_resolution'],
  );
  // ...
}
```

### Catching this automatically

Call `App.checkScheduleOrdering()` in a test or a debug-only boot path. It walks every stage for pairs of systems that conflict but have no explicit `before:`/`after:` between them, and returns a list describing each one with a ready-to-paste fix:

```dart
void main() {
  final app = buildApp();
  assert(() {
    final issues = app.checkScheduleOrdering();
    if (issues.isNotEmpty) {
      // ignore: avoid_print
      issues.forEach(print);
    }
    return issues.isEmpty;
  }());
  runApp(MyGame(app: app));
}
```

Each returned `OrderingAmbiguity` names both systems, the stage they're in, what they conflict on (e.g. `both write component Velocity`, `resource Time: A writes, B reads`), and the explicit constraint you'd add to fix it. A clean run returns an empty list.

## System Sets

Group related systems and configure their ordering together:

```dart
app
  // Configure the physics set
  .configureSet('physics', (set) => set
    .after('input')
    .before('render'))

  // Add systems to the set
  .addSystemToSet(gravitySystem, 'physics')
  .addSystemToSet(collisionSystem, 'physics')
  .addSystemToSet(velocitySystem, 'physics');
```

All systems in the set inherit the ordering constraints.

## Common Patterns

### Pipeline Pattern

Create a clear processing pipeline:

```dart
app
  .addSystem(FunctionSystem('input', run: inputSystem))
  .addSystem(FunctionSystem('ai', after: ['input'], run: aiSystem))
  .addSystem(FunctionSystem('movement', after: ['ai'], run: movementSystem))
  .addSystem(FunctionSystem('physics', after: ['movement'], run: physicsSystem))
  .addSystem(FunctionSystem('render', after: ['physics'], run: renderSystem));
```

### Phases with Sets

Organize systems into logical phases:

```dart
app
  // Define phase ordering
  .configureSet('input', (s) => s)
  .configureSet('simulation', (s) => s.after('input'))
  .configureSet('render', (s) => s.after('simulation'))

  // Add systems to phases
  .addSystemToSet(keyboardSystem, 'input')
  .addSystemToSet(mouseSystem, 'input')
  .addSystemToSet(movementSystem, 'simulation')
  .addSystemToSet(physicsSystem, 'simulation')
  .addSystemToSet(spriteRenderSystem, 'render')
  .addSystemToSet(uiRenderSystem, 'render');
```

### Initialization Order

Ensure setup systems run first:

```dart
app
  .addSystem(FunctionSystem('setup',
    before: ['gameplay'],
    run: setupSystem,
  ))
  .addSystem(FunctionSystem('gameplay', run: gameplaySystem));
```

## Order Independence

Systems without conflicts or explicit ordering can run in parallel:

```dart-tabs
// @tab Annotations
// These systems are independent - may run in parallel
@system
void audioSystem(World world) {
  for (final (_, audio) in world.query1<AudioSource>().iter()) { }
}

@system
void particleSystem(World world) {
  for (final (_, emitter) in world.query1<ParticleEmitter>().iter()) { }
}
// @tab Inheritance
// These systems are independent - may run in parallel
class AudioSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'audio', reads: {ComponentId.of<AudioSource>()});

  @override
  Future<void> run(World world) async {
    for (final (_, audio) in world.query1<AudioSource>().iter()) { }
  }
}

class ParticleSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(name: 'particle', reads: {ComponentId.of<ParticleEmitter>()});

  @override
  Future<void> run(World world) async {
    for (final (_, emitter) in world.query1<ParticleEmitter>().iter()) { }
  }
}
```

## Debugging Order

Use `App.checkScheduleOrdering()` to find pairs of same-stage systems whose order is determined only by registration order (i.e. neither side declares `before:` / `after:` on the other). See the "Registration order breaks ties — and it's a trap" section above for the full pattern.

```dart
for (final issue in app.checkScheduleOrdering()) {
  print(issue);
  // OrderingAmbiguity(stage=update): my_movement runs before
  //   collision_resolution by registration order only.
  //   Reasons: both write component Velocity. Add
  //   `before: ['collision_resolution']` to my_movement
  //   (or the reverse) to make the intent explicit, or
  //   move one to a different stage.
}
```

Run it in a test (`expect(app.checkScheduleOrdering(), isEmpty)`) or guard it behind `assert` in a debug boot path. The diagnostic is the same one `examples/drifter/test/schedule_ordering_test.dart` uses to pin down its own schedule.

## See Also

- [System Sets](/docs/api/system-sets) - Grouping systems
- [Schedule API](/docs/api/schedule) - Schedule reference
- [Systems](/docs/guides/systems) - System basics
