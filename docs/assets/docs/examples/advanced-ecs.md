# Advanced ECS

A console program that tours the rest of `fledge_ecs`: observers,
hierarchies, change detection, states, system sets and run conditions, and
recursive despawn. Each section prints what happens, so the output is the
best guide to the code.

Source: [`examples/advanced_ecs`](https://github.com/fledge-framework/fledge/tree/main/examples/advanced_ecs)
(pure Dart, Dart 3.11+, no code generation).

## Running it

From a clone of the repository, after `melos bootstrap` (or `dart pub get` at
the root):

```bash
cd examples/advanced_ecs
dart run bin/main.dart
```

The full program is at the [end of this page](#the-program). Here's what each
section does, with the output it prints.

## 1. Observers

```
--- 1. Observers Demo ---

Spawning spaceship...
  [Observer] Spaceship "Falcon" spawned!
```

Four observers are registered on a bare `World` before anything is spawned:
`Observer<Spaceship>.onAdd`, `Observer<Turret>.onAdd`,
`Observer<Health>.onRemove` and `Observer<Health>.onChange`. Spawning the ship
with `world.spawn()..insert(...)` fires the `Spaceship` observer as the
component is inserted. The other two fire later, in sections 3 and 7. See
[Observers](/docs/ecs/observers).

## 2. Hierarchies

```
--- 2. Hierarchies Demo ---

Attaching turrets to spaceship...
  [Observer] Turret "Laser" attached!
  [Observer] Turret "Missile" attached!

Ship children:
  - Laser at local position Position(-10.0, 0.0)
  - Missile at local position Position(10.0, 0.0)

Turret parent check:
  Left turret parent: Entity(0:0)
  Right turret parent: Entity(0:0)
  Ship is root: true
```

`world.spawnChild(ship.entity)` creates the two turrets as children of the
ship (each fires the `Turret` observer). `getChildren`, `getParent` and
`root` walk the tree. The turrets' `Position`s are offsets from the ship by
convention only: plain `fledge_ecs` doesn't propagate positions down a
hierarchy (`fledge_render_2d`'s transforms do). See
[Hierarchies](/docs/ecs/hierarchies).

## 3. Change detection

```
--- 3. Change Detection Demo ---

Damaging spaceship...
  [Observer] Health changed to 75/100

Entities with changed Health this tick:
  Entity Entity(0:0): 75/100
```

The program advances the change tick, damages the ship's `Health` in place,
then calls `world.insert` with the same component. In-place mutation alone
doesn't count as a change; the `insert` does, which fires the `onChange`
observer and makes a `Changed<Health>` query match. (`world.markChanged<Health>(entity)`
would mark it without re-inserting.) See
[Change Detection](/docs/ecs/change-detection).

## 4. States

```
--- 4. States Demo ---

Current state: GameState.loading

Transitioning to PLAYING...
Running 3 ticks in PLAYING state...
  [State] Entered PLAYING state - game started!
  Score: 30
  Time: 0.048s

Transitioning to PAUSED...
Running 3 ticks in PAUSED state (score should NOT change)...
  [State] Entered PAUSED state
  Score before: 40, after: 40

Transitioning back to PLAYING...
  [State] Entered PLAYING state - game started!
  [State] Exited PAUSED state - resuming!
```

This section builds an `App` with `addState<GameState>(GameState.loading)`
(the enum is `loading, playing, paused, gameOver`), two systems that only run
`InState(playing)` via `addSystemInState`, and three transition systems
gated by `OnEnterState(playing)`, `OnEnterState(paused)` and
`OnExitState(paused)` run conditions.

The output shows when transitions take effect:

- `State.set` only requests a change. It's applied at the **end** of
  `app.tick()`, and enter/exit conditions are true during the **next** tick.
  That's why "Entered PLAYING state" prints after "Running 3 ticks...": the
  tick that applied the transition still ran in `loading`.
- So the score after the four ticks is 30, not 40: the playing systems ran on
  three of them.
- While paused, `scoreSystem` doesn't run: 40 before, 40 after.
- Going back to `playing`, `OnEnterState(playing)` and `OnExitState(paused)`
  both fire in the tick after the transition. The program ticks twice for
  that reason.

See [States & Run Conditions](/docs/ecs/states-run-conditions).

## 5. System sets

```
--- 5. System Sets Demo ---

System execution order:
  1. input
  2. physics:movement
  3. physics:collision
  4. render
```

A second `App` configures three sets, with `physics` ordered
`after('input')` and `before('render')`, and adds one system to `input`, two
to `physics` and one to `render` with `addSystemToSet`. They run in set
order. Within `physics`, `movement` and `collision` declare no conflicting
access, so their relative order isn't constrained. See
[Ordering & Sets](/docs/scheduling/ordering-and-sets#system-sets).

## 6. Run conditions

```
--- 6. Run Conditions Demo ---

Running ticks with conditional system...
  Tick 1: score = 0
  Tick 2: score = 20
  Tick 3: score = 40
  [Condition] High score bonus triggered! (score > 50)
  Tick 4: score = 60
  [Condition] High score bonus triggered! (score > 50)
  Tick 5: score = 80
  [Condition] High score bonus triggered! (score > 50)
Conditional system ran 3 times
```

`highScoreBonus` has `runIf: RunConditions.resource<Score>((s) => s.value > 50)`.
`incrementScore` adds 20 per tick and is registered first. The two don't
declare their resource access, so the scheduler doesn't treat them as
conflicting: they happen to run in registration order. The bonus first runs
in the tick where `incrementScore` lifts the score from 40 to 60, before
"Tick 4" is printed, and runs three times in all.

## 7. Recursive despawn

```
--- 7. Recursive Despawn Demo ---

Entity count before despawn: 3
Despawning spaceship (and all attached turrets)...
  [Observer] Entity Entity(0:0) lost Health component (was 75/100)
Entity count after despawn: 0

=== Advanced Example Complete ===
```

`world.despawnRecursive(ship.entity)` removes the ship and both turrets.
Despawning fires `onRemove` for every component, with the entity still
readable in the callback, so the `Health` observer from section 1 reports the
ship's last health. (Plain `world.despawn` would leave the turrets alive as
new roots.)

## The program

`bin/main.dart` (its imports are `package:fledge_ecs/fledge_ecs.dart` and the
example's `components.dart`, whose classes are `Position`, `Velocity`,
`Spaceship`, `Turret`, `Health`, `Score` and `GameTime`):

<!-- snippet-setup
/// Position component - represents location in 2D space.
@component
class Position {
  double x;
  double y;

  Position(this.x, this.y);

  @override
  String toString() =>
      'Position(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Velocity component - represents movement speed and direction.
@component
class Velocity {
  double dx;
  double dy;

  Velocity(this.dx, this.dy);

  @override
  String toString() => 'Velocity($dx, $dy)';
}

/// Spaceship component - a ship that can have turrets attached.
@component
class Spaceship {
  final String name;
  int shields;

  Spaceship(this.name, {this.shields = 100});
}

/// Turret component - weapon attached to a spaceship.
@component
class Turret {
  final String type;
  int ammo;

  Turret(this.type, {this.ammo = 50});
}

/// Health component - represents entity health points.
@component
class Health {
  int current;
  final int max;

  Health(this.max) : current = max;

  bool get isDead => current <= 0;

  void damage(int amount) {
    current = (current - amount).clamp(0, max);
  }
}

/// Score resource - tracks the player's score.
class Score {
  int value;
  Score(this.value);
}

/// Game time resource.
class GameTime {
  double elapsed;
  GameTime(this.elapsed);
}
-->

```dart
/// Game states
enum GameState { loading, playing, paused, gameOver }

/// Advanced ECS example demonstrating new Fledge features.
///
/// This example shows:
/// - Game states and state transitions
/// - Observers for component lifecycle events
/// - Parent-child entity hierarchies
/// - Change detection
/// - Run conditions
/// - System sets and ordering
void main() async {
  print('=== Fledge ECS Advanced Example ===\n');

  // ============================================
  // 1. OBSERVERS - React to component changes
  // ============================================
  print('--- 1. Observers Demo ---\n');

  final world = World();

  // Register observers before spawning entities
  world.observers.register(
    Observer<Spaceship>.onAdd((w, entity, ship) {
      print('  [Observer] Spaceship "${ship.name}" spawned!');
    }),
  );

  world.observers.register(
    Observer<Turret>.onAdd((w, entity, turret) {
      print('  [Observer] Turret "${turret.type}" attached!');
    }),
  );

  world.observers.register(
    Observer<Health>.onRemove((w, entity, health) {
      print(
        '  [Observer] Entity $entity lost Health component (was ${health.current}/${health.max})',
      );
    }),
  );

  world.observers.register(
    Observer<Health>.onChange((w, entity, health) {
      print('  [Observer] Health changed to ${health.current}/${health.max}');
    }),
  );

  // Spawn a spaceship - triggers onAdd observer
  print('Spawning spaceship...');
  final ship = world.spawn()
    ..insert(Spaceship('Falcon', shields: 100))
    ..insert(Position(0, 0))
    ..insert(Velocity(1, 0))
    ..insert(Health(100));

  print('');

  // ============================================
  // 2. HIERARCHIES - Parent-child relationships
  // ============================================
  print('--- 2. Hierarchies Demo ---\n');

  // Spawn turrets as children of the spaceship
  print('Attaching turrets to spaceship...');

  final leftTurret = world.spawnChild(ship.entity)
    ..insert(Turret('Laser', ammo: 100))
    ..insert(Position(-10, 0)); // Local offset from parent

  final rightTurret = world.spawnChild(ship.entity)
    ..insert(Turret('Missile', ammo: 20))
    ..insert(Position(10, 0));

  print('');

  // Query the hierarchy
  print('Ship children:');
  for (final child in world.getChildren(ship.entity)) {
    final turret = world.get<Turret>(child);
    final pos = world.get<Position>(child);
    print('  - ${turret?.type} at local position $pos');
  }

  print('\nTurret parent check:');
  print('  Left turret parent: ${world.getParent(leftTurret.entity)}');
  print('  Right turret parent: ${world.getParent(rightTurret.entity)}');
  print('  Ship is root: ${world.root(leftTurret.entity) == ship.entity}');

  print('');

  // ============================================
  // 3. CHANGE DETECTION - Track modifications
  // ============================================
  print('--- 3. Change Detection Demo ---\n');

  // Advance tick to start fresh
  world.advanceTick();

  // Modify the ship's health - triggers onChange observer
  print('Damaging spaceship...');
  final health = world.get<Health>(ship.entity)!;
  health.damage(25);
  world.insert(ship.entity, health); // Re-insert to trigger change detection

  print('');

  // Query for changed health components
  print('Entities with changed Health this tick:');
  for (final (entity, h)
      in world.query1<Health>(filter: Changed<Health>()).iter()) {
    print('  Entity $entity: ${h.current}/${h.max}');
  }

  print('');

  // ============================================
  // 4. STATES - Game state management
  // ============================================
  print('--- 4. States Demo ---\n');

  // Create app with states
  final app = App()
      .addState<GameState>(GameState.loading)
      .insertResource(Score(0))
      .insertResource(GameTime(0.0));

  // Add state transition handlers
  app.addSystem(
    FunctionSystem(
      'onEnterPlaying',
      runIf: OnEnterState<GameState>(GameState.playing).condition,
      run: (w) {
        print('  [State] Entered PLAYING state - game started!');
        w.insertResource(GameTime(0.0));
      },
    ),
  );

  app.addSystem(
    FunctionSystem(
      'onEnterPaused',
      runIf: OnEnterState<GameState>(GameState.paused).condition,
      run: (w) {
        print('  [State] Entered PAUSED state');
      },
    ),
  );

  app.addSystem(
    FunctionSystem(
      'onExitPaused',
      runIf: OnExitState<GameState>(GameState.paused).condition,
      run: (w) {
        print('  [State] Exited PAUSED state - resuming!');
      },
    ),
  );

  // Systems that only run in playing state
  app.addSystemInState(
    FunctionSystem(
      'gameTime',
      run: (w) {
        final time = w.getResource<GameTime>()!;
        time.elapsed += 0.016; // ~60 FPS
      },
    ),
    GameState.playing,
  );

  app.addSystemInState(
    FunctionSystem(
      'scoreSystem',
      run: (w) {
        final score = w.getResource<Score>()!;
        score.value += 10;
      },
    ),
    GameState.playing,
  );

  print('Current state: ${app.world.getResource<State<GameState>>()?.current}');

  // Transition to playing
  print('\nTransitioning to PLAYING...');
  app.world.getResource<State<GameState>>()?.set(GameState.playing);
  await app.tick();

  print('Running 3 ticks in PLAYING state...');
  for (var i = 0; i < 3; i++) {
    await app.tick();
  }
  print('  Score: ${app.world.getResource<Score>()?.value}');
  print(
    '  Time: ${app.world.getResource<GameTime>()?.elapsed.toStringAsFixed(3)}s',
  );

  // Pause
  print('\nTransitioning to PAUSED...');
  app.world.getResource<State<GameState>>()?.set(GameState.paused);
  await app.tick();

  print('Running 3 ticks in PAUSED state (score should NOT change)...');
  final scoreBefore = app.world.getResource<Score>()?.value;
  for (var i = 0; i < 3; i++) {
    await app.tick();
  }
  print(
    '  Score before: $scoreBefore, after: ${app.world.getResource<Score>()?.value}',
  );

  // Resume
  print('\nTransitioning back to PLAYING...');
  app.world.getResource<State<GameState>>()?.set(GameState.playing);
  await app.tick(); // the transition is applied at the end of this tick
  await app.tick(); // OnExitState(paused) runs during the next one

  print('');

  // ============================================
  // 5. SYSTEM SETS - Group and configure systems
  // ============================================
  print('--- 5. System Sets Demo ---\n');

  final app2 = App();
  final executionOrder = <String>[];

  // Configure system sets with ordering
  app2
      .configureSet('input', (set) => set)
      .configureSet('physics', (set) => set.after('input').before('render'))
      .configureSet('render', (set) => set);

  // Add systems to sets
  app2.addSystemToSet(
    FunctionSystem(
      'inputHandler',
      run: (w) {
        executionOrder.add('input');
      },
    ),
    'input',
  );

  app2.addSystemToSet(
    FunctionSystem(
      'movement',
      run: (w) {
        executionOrder.add('physics:movement');
      },
    ),
    'physics',
  );

  app2.addSystemToSet(
    FunctionSystem(
      'collision',
      run: (w) {
        executionOrder.add('physics:collision');
      },
    ),
    'physics',
  );

  app2.addSystemToSet(
    FunctionSystem(
      'draw',
      run: (w) {
        executionOrder.add('render');
      },
    ),
    'render',
  );

  await app2.tick();

  print('System execution order:');
  for (var i = 0; i < executionOrder.length; i++) {
    print('  ${i + 1}. ${executionOrder[i]}');
  }

  print('');

  // ============================================
  // 6. RUN CONDITIONS - Conditional execution
  // ============================================
  print('--- 6. Run Conditions Demo ---\n');

  final app3 = App().insertResource(Score(0));

  var conditionalRuns = 0;

  // System that only runs when score > 50
  app3.addSystem(
    FunctionSystem(
      'incrementScore',
      run: (w) {
        final score = w.getResource<Score>()!;
        score.value += 20;
      },
    ),
  );

  app3.addSystem(
    FunctionSystem(
      'highScoreBonus',
      runIf: RunConditions.resource<Score>((s) => s.value > 50),
      run: (w) {
        conditionalRuns++;
        print('  [Condition] High score bonus triggered! (score > 50)');
      },
    ),
  );

  print('Running ticks with conditional system...');
  for (var i = 1; i <= 5; i++) {
    final score = app3.world.getResource<Score>()!.value;
    print('  Tick $i: score = $score');
    await app3.tick();
  }
  print('Conditional system ran $conditionalRuns times');

  print('');

  // ============================================
  // 7. HIERARCHY DESPAWN - Recursive cleanup
  // ============================================
  print('--- 7. Recursive Despawn Demo ---\n');

  print('Entity count before despawn: ${world.entityCount}');
  print('Despawning spaceship (and all attached turrets)...');

  world.despawnRecursive(ship.entity);

  print('Entity count after despawn: ${world.entityCount}');

  print('\n=== Advanced Example Complete ===');
}
```

## See also

- [Basic ECS](/docs/examples/basic-ecs)
- [Observers](/docs/ecs/observers)
- [States & Run Conditions](/docs/ecs/states-run-conditions)
- [Drifter](/docs/examples/drifter), a complete Flutter game
