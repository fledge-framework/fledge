import 'package:fledge_ecs/fledge_ecs.dart';

import 'package:basic_ecs_example/components.dart';

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
  final schedule = Schedule()
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

            print('  $label: ${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)}');
          }
        },
      ),
      stage: CoreStage.postUpdate,
    );

  // Run a few simulation steps
  print('Running 3 simulation steps...\n');
  for (int step = 1; step <= 3; step++) {
    print('Step $step:');
    await schedule.run(world);
    print('');
  }

  // Demonstrate queries with filters
  print('=== Query Examples ===\n');

  // Query only players
  print('Players:');
  for (final (entity, pos) in world
      .query1<Position>(filter: const With<Player>())
      .iter()) {
    final p = world.get<Player>(entity)!;
    print('  ${p.name} at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)})');
  }

  // Query only enemies
  print('\nEnemies:');
  for (final (entity, pos) in world
      .query1<Position>(filter: const With<Enemy>())
      .iter()) {
    final e = world.get<Enemy>(entity)!;
    print('  Difficulty ${e.difficulty} at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)})');
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
