# Basic ECS

A console program covering the core of `fledge_ecs`: spawning entities with
components, running systems, filtering queries, and deferring changes with
`Commands`. It uses a bare `World` and `Scheduler`, without an `App`, to show
the pieces underneath.

Source: [`examples/basic_ecs`](https://github.com/fledge-framework/fledge/tree/main/examples/basic_ecs)
(pure Dart, Dart 3.11+).

## Running it

From a clone of the repository, after `melos bootstrap` (or `dart pub get` at
the root):

```bash
cd examples/basic_ecs
dart run build_runner build
dart run bin/main.dart
```

The `build_runner` step is required: `lib/components.dart` has a
`part 'components.g.dart';` directive, and the program won't compile until
that file is generated. (CI builds this example the same way.)

## Output

```
=== Fledge ECS Basic Example ===

Spawned player: Entity(0:0)
Spawned 3 enemies
Total entities: 4

Running 3 simulation steps...

Step 1:
--- Entity Positions ---
  Player(Hero): 1.0, 0.5
  Enemy(diff=1): 9.5, 10.0
  Enemy(diff=2): 14.5, 10.0
  Enemy(diff=3): 19.5, 10.0

Step 2:
--- Entity Positions ---
  Player(Hero): 2.0, 1.0
  Enemy(diff=1): 9.0, 10.0
  Enemy(diff=2): 14.0, 10.0
  Enemy(diff=3): 19.0, 10.0

Step 3:
--- Entity Positions ---
  Player(Hero): 3.0, 1.5
  Enemy(diff=1): 8.5, 10.0
  Enemy(diff=2): 13.5, 10.0
  Enemy(diff=3): 18.5, 10.0

=== Query Examples ===

Players:
  Hero at (3.0, 1.5)

Enemies:
  Difficulty 1 at (8.5, 10.0)
  Difficulty 2 at (13.5, 10.0)
  Difficulty 3 at (18.5, 10.0)

=== Commands Example ===

Commands queued: 2
Applying commands...
New entity spawned: Entity(4:0)
Total entities after commands: 4

=== Example Complete ===
```

## What it does

**Components** live in `lib/components.dart`: `Position`, `Velocity`, `Health`,
and two markers with data, `Player(name)` and `Enemy(difficulty:)`. They carry
`@component`, which makes the generator emit a `ComponentId` extension for
each; the program doesn't use those, and the classes would work the same
without the annotation.

**Spawning.** `world.spawnWith([...])` creates the player and three enemies,
each with a `Position`, `Velocity` and `Health`.

**Systems.** Two `FunctionSystem`s go into a `Scheduler`: `movement` in the
default `update` schedule (adds velocity to position, once per step, no
delta time) and `printPositions` in `postUpdate`, which runs after it. Each
declares its reads and writes. `printPositions` labels each entity by asking
`world.get<Player>(entity)` and `world.get<Enemy>(entity)`.

`scheduler.run(world)` runs the per-frame schedules once. It's a convenience
for a bare `Scheduler`: it skips `startup` and the fixed-timestep chain and
doesn't swap event buffers or apply state transitions. A game uses an `App`
and `app.tick()` instead (see [App & Plugins](/docs/app/app-and-plugins)).

**Filtered queries.** `query1<Position>(filter: const With<Player>())` visits
only the player; `With<Enemy>` only the enemies.

**Commands.** A `Commands` buffer queues a spawn and the despawn of the first
enemy; nothing changes until `commands.apply(world)`. The entity count stays
at 4 (one in, one out), and the new entity is `Entity(4:0)` because the
spawn is applied before the despawn frees index 1.

## The program

`bin/main.dart` (its imports are `package:fledge_ecs/fledge_ecs.dart` and the
example's `components.dart`):

<!-- snippet-setup
/// Position component - represents location in 2D space.
@component
class Position {
  double x;
  double y;

  Position(this.x, this.y);

  @override
  String toString() => 'Position($x, $y)';
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

/// Player marker component - tags an entity as the player.
@component
class Player {
  final String name;

  Player(this.name);
}

/// Enemy marker component - tags an entity as an enemy.
@component
class Enemy {
  final int difficulty;

  Enemy({this.difficulty = 1});
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

  void heal(int amount) {
    current = (current + amount).clamp(0, max);
  }
}
-->

```dart
/// Basic ECS example demonstrating the Fledge framework.
///
/// This example shows:
/// - Spawning entities with components
/// - Querying entities
/// - Running systems
/// - Using deferred commands
void main() async {
  print('=== Fledge ECS Basic Example ===\n');

  // Create the world
  final world = World();

  // Spawn the player
  final player = world.spawnWith([
    Position(0, 0),
    Velocity(1, 0.5),
    Player('Hero'),
    Health(100),
  ]);
  print('Spawned player: $player');

  // Spawn some enemies
  for (int i = 0; i < 3; i++) {
    world.spawnWith([
      Position(10.0 + i * 5, 10.0),
      Velocity(-0.5, 0),
      Enemy(difficulty: i + 1),
      Health(50),
    ]);
  }
  print('Spawned 3 enemies');
  print('Total entities: ${world.entityCount}\n');

  // Create a schedule
  final scheduler = Scheduler()
    ..addSystem(
      FunctionSystem(
        'movement',
        writes: {ComponentId.of<Position>()},
        reads: {ComponentId.of<Velocity>()},
        run: (world) {
          for (final (_, pos, vel)
              in world.query2<Position, Velocity>().iter()) {
            pos.x += vel.dx;
            pos.y += vel.dy;
          }
        },
      ),
    )
    ..addSystem(
      FunctionSystem(
        'printPositions',
        reads: {ComponentId.of<Position>()},
        run: (world) {
          print('--- Entity Positions ---');
          for (final (entity, pos) in world.query1<Position>().iter()) {
            final player = world.get<Player>(entity);
            final enemy = world.get<Enemy>(entity);

            String label;
            if (player != null) {
              label = 'Player(${player.name})';
            } else if (enemy != null) {
              label = 'Enemy(diff=${enemy.difficulty})';
            } else {
              label = 'Entity';
            }

            print(
              '  $label: ${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)}',
            );
          }
        },
      ),
      schedule: Schedules.postUpdate,
    );

  // Run a few simulation steps
  print('Running 3 simulation steps...\n');
  for (int step = 1; step <= 3; step++) {
    print('Step $step:');
    await scheduler.run(world);
    print('');
  }

  // Demonstrate queries with filters
  print('=== Query Examples ===\n');

  // Query only players
  print('Players:');
  for (final (entity, pos)
      in world.query1<Position>(filter: const With<Player>()).iter()) {
    final p = world.get<Player>(entity)!;
    print(
      '  ${p.name} at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)})',
    );
  }

  // Query only enemies
  print('\nEnemies:');
  for (final (entity, pos)
      in world.query1<Position>(filter: const With<Enemy>()).iter()) {
    final e = world.get<Enemy>(entity)!;
    print(
      '  Difficulty ${e.difficulty} at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)})',
    );
  }

  // Demonstrate commands
  print('\n=== Commands Example ===\n');

  final commands = Commands();

  // Queue spawning a new entity
  final spawnCmd = commands.spawn()
    ..insert(Position(100, 100))
    ..insert(Velocity(0, -1));

  // Queue despawning an enemy
  final firstEnemy = world
      .query1<Position>(filter: const With<Enemy>())
      .iter()
      .first
      .$1;
  commands.despawn(firstEnemy);

  print('Commands queued: ${commands.length}');
  print('Applying commands...');
  commands.apply(world);

  print('New entity spawned: ${spawnCmd.entity}');
  print('Total entities after commands: ${world.entityCount}');

  print('\n=== Example Complete ===');
}
```

## The code-generation files

The `lib/` folder also holds two annotated files that `bin/main.dart` doesn't
use:

- **`lib/systems.dart`** has `@system` versions of the two systems. They take
  a `World` parameter, so `build_runner` warns that their generated
  `SystemMeta` declares no access (and they'd never be ordered against
  conflicting systems). Typed parameters such as `QueryMut2<Position, Velocity>`
  are the better form; see [Code Generation](/docs/app/codegen).
- **`lib/query_marker_fixtures.dart`** is a set of `@system` functions, one
  per parameter kind, whose generated output the generator's own tests
  compare against. It's a good place to see what each parameter turns into.
  For example, reading one component and writing another:

```dart fragment
@system
void readPositionsWriteVelocities(Query1<Position> r, QueryMut1<Velocity> w) {
  for (final _ in r.iter()) {}
  for (final _ in w.iter()) {}
}
```

generates:

```dart fragment
/// Generated system wrapper for [readPositionsWriteVelocities].
class ReadPositionsWriteVelocitiesWrapper implements System {
  /// Name used in [SystemMeta] and for `before:`/`after:`.
  static const String systemName = 'readPositionsWriteVelocities';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Velocity>()},
    reads: {ComponentId.of<Position>()},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => runCondition?.call(world) ?? true;

  @override
  void run(World world) {
    final r = world.query1<Position>();
    final w = world.queryMut1<Velocity>();
    readPositionsWriteVelocities(r, w);
  }
}
```

## See also

- [Entities & Components](/docs/ecs/entities-components)
- [Queries](/docs/ecs/queries)
- [Commands](/docs/ecs/commands)
- [Advanced ECS](/docs/examples/advanced-ecs)
