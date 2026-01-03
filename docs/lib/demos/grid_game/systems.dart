import 'dart:math';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'resources.dart';

// Re-export Time from fledge_ecs for convenience
export 'package:fledge_ecs/fledge_ecs.dart' show Time;

/// System that moves the player based on input state.
///
/// Reads the InputState resource, updates the Player's GridPosition,
/// and clamps to grid bounds. Supports continuous movement while
/// direction keys are held.
class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<GridPosition>()},
        reads: {ComponentId.of<Player>()},
        resourceReads: {InputState, GridConfig, Time},
      );

  @override
  Future<void> run(World world) async {
    final input = world.getResource<InputState>();
    final config = world.getResource<GridConfig>();
    final time = world.getResource<Time>();
    if (input == null || config == null || time == null) return;

    // Check if movement should occur this frame
    if (!input.tick(time.delta)) return;

    // Find and move the player
    for (final (_, pos)
        in world.query1<GridPosition>(filter: const With<Player>()).iter()) {
      pos.x = (pos.x + input.dx).clamp(0, config.width - 1);
      pos.y = (pos.y + input.dy).clamp(0, config.height - 1);
    }
  }
}

/// System that spawns collectibles periodically.
///
/// Uses the SpawnTimer resource to control spawn rate.
/// Spawns items at random empty tiles.
class SpawnSystem extends System {
  final Random _random = Random();

  @override
  SystemMeta get meta => SystemMeta(
        name: 'spawn',
        reads: {
          ComponentId.of<GridPosition>(),
          ComponentId.of<Player>(),
          ComponentId.of<Collectible>(),
        },
        resourceReads: {SpawnTimer, Time, GridConfig},
      );

  @override
  Future<void> run(World world) async {
    final timer = world.getResource<SpawnTimer>();
    final time = world.getResource<Time>();
    final config = world.getResource<GridConfig>();
    if (timer == null || time == null || config == null) return;

    // Check if it's time to spawn
    if (!timer.tick(time.delta)) return;

    // Find occupied positions
    final occupied = <(int, int)>{};
    for (final (_, pos) in world.query1<GridPosition>().iter()) {
      occupied.add((pos.x, pos.y));
    }

    // Find empty positions
    final empty = <(int, int)>[];
    for (var x = 0; x < config.width; x++) {
      for (var y = 0; y < config.height; y++) {
        if (!occupied.contains((x, y))) {
          empty.add((x, y));
        }
      }
    }

    // Spawn at random empty position
    if (empty.isNotEmpty) {
      final pos = empty[_random.nextInt(empty.length)];
      world.spawn()
        ..insert(GridPosition(pos.$1, pos.$2))
        ..insert(const Collectible())
        ..insert(TileColor(const Color(0xFFFFD700))); // Gold color
    }
  }
}

/// System that detects player/item collision and handles collection.
///
/// When player position matches a collectible position:
/// - Despawns the collectible
/// - Increments the score
class CollectionSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'collection',
        reads: {
          ComponentId.of<GridPosition>(),
          ComponentId.of<Player>(),
          ComponentId.of<Collectible>(),
        },
        resourceWrites: {GameScore},
      );

  @override
  Future<void> run(World world) async {
    final score = world.getResource<GameScore>();
    if (score == null) return;

    // Find player position
    GridPosition? playerPos;
    for (final (_, pos)
        in world.query1<GridPosition>(filter: const With<Player>()).iter()) {
      playerPos = pos;
      break;
    }
    if (playerPos == null) return;

    // Check collectibles for overlap
    final toCollect = <Entity>[];
    for (final (entity, pos, collectible)
        in world.query2<GridPosition, Collectible>().iter()) {
      if (pos.x == playerPos.x && pos.y == playerPos.y) {
        toCollect.add(entity);
        score.add(collectible.points);
      }
    }

    // Despawn collected items
    for (final entity in toCollect) {
      world.despawn(entity);
    }
  }
}

/// Plugin that sets up the Grid Game.
///
/// Configures resources and systems for the game, and spawns
/// the initial player entity.
///
/// ## Usage
///
/// ```dart
/// final app = App()
///   .addPlugin(TimePlugin())
///   .addPlugin(GridGamePlugin());
///
/// // Run game loop
/// await app.tick();
/// ```
class GridGamePlugin implements Plugin {
  /// Grid configuration (optional, uses defaults if not provided).
  final GridConfig config;

  GridGamePlugin({this.config = const GridConfig()});

  @override
  void build(App app) {
    // Insert resources
    app
        .insertResource(config)
        .insertResource(GameScore())
        .insertResource(InputState())
        .insertResource(SpawnTimer(2.0));

    // Add systems in execution order
    app
        .addSystem(MovementSystem(), stage: CoreStage.update)
        .addSystem(SpawnSystem(), stage: CoreStage.update)
        .addSystem(CollectionSystem(), stage: CoreStage.update);

    // Spawn player at center
    app.world.spawn()
      ..insert(GridPosition(config.width ~/ 2, config.height ~/ 2))
      ..insert(const Player())
      ..insert(TileColor(const Color(0xFF00DD00))); // Bright green
  }

  @override
  void cleanup() {}
}
