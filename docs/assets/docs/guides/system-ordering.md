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

The schedule logs system execution order in debug mode:

```dart
// Enable debug logging
app.debugSystems = true;

// Output:
// [Schedule] Running: input
// [Schedule] Running: movement (after: input)
// [Schedule] Running: physics (after: movement)
```

## See Also

- [System Sets](/docs/api/system-sets) - Grouping systems
- [Schedule API](/docs/api/schedule) - Schedule reference
- [Systems](/docs/guides/systems) - System basics
