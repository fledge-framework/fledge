// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

// Game-specific collision layers
abstract class GameLayers {
  // Inherit framework layers
  static const int solid = CollisionLayers.solid;
  static const int trigger = CollisionLayers.trigger;

  // Game-specific layers (start at bit 8)
  static const int player = CollisionLayers.gameLayersStart << 0; // 0x0100
  static const int enemy = CollisionLayers.gameLayersStart << 1; // 0x0200
}

// Marker component for player
class Player {}

// Marker component for trigger zones
class TriggerZone {
  final String message;
  const TriggerZone(this.message);
}

// System that responds to collision events
class CollisionResponseSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'collision_response',
        reads: {
          ComponentId.of<Player>(),
          ComponentId.of<CollisionEvent>(),
          ComponentId.of<TriggerZone>(),
        },
      );

  @override
  Future<void> run(World world) async {
    // Check player collision events
    for (final (_, _, collision) in world.query2<Player, CollisionEvent>().iter()) {
      final other = collision.other;

      // Check if player entered a trigger zone
      final trigger = world.get<TriggerZone>(other);
      if (trigger != null) {
        print('Player entered trigger zone: ${trigger.message}');
      }
    }
  }
}

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(PhysicsPlugin());

  // Add our collision response system
  app.addSystem(CollisionResponseSystem(), stage: CoreStage.update);

  // Spawn a solid wall (blocks movement)
  app.world.spawn()
    ..insert(Transform2D.from(100, 50))
    ..insert(Collider.single(RectangleShape(
      x: 0,
      y: 0,
      width: 200,
      height: 20,
    )))
    ..insert(const CollisionConfig.solid());

  // Spawn a trigger zone (generates events but doesn't block)
  app.world.spawn()
    ..insert(Transform2D.from(150, 150))
    ..insert(Collider.single(RectangleShape(
      x: 0,
      y: 0,
      width: 50,
      height: 50,
    )))
    ..insert(CollisionConfig.sensor(
      layer: GameLayers.trigger,
      mask: GameLayers.player,
    ))
    ..insert(const TriggerZone('Secret Area!'));

  // Spawn player with velocity
  app.world.spawn()
    ..insert(Transform2D.from(50, 100))
    ..insert(Velocity(2, 0, 5)) // Moving right
    ..insert(Collider.single(RectangleShape(
      x: 0,
      y: 0,
      width: 16,
      height: 16,
    )))
    ..insert(CollisionConfig(
      layer: GameLayers.player,
      mask: GameLayers.solid | GameLayers.trigger,
    ))
    ..insert(Player());

  // Simulate a few frames
  print('Starting physics simulation...\n');

  for (var frame = 0; frame < 100; frame++) {
    await app.tick();

    // Print player position every 10 frames
    if (frame % 10 == 0) {
      for (final (_, transform, _) in app.world.query2<Transform2D, Player>().iter()) {
        final pos = transform.translation;
        print('Frame $frame: Player at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)})');
      }
    }
  }

  print('\nSimulation complete!');
}
