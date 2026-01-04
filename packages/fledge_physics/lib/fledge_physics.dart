/// Physics and collision handling for Fledge ECS game framework.
///
/// This library provides collision detection, resolution, and layer-based
/// filtering for 2D games.
///
/// ## Quick Start
///
/// Add the physics plugin to your app:
///
/// ```dart
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_physics/fledge_physics.dart';
///
/// void main() async {
///   final app = App()
///     .addPlugin(PhysicsPlugin());
///
///   // Spawn a solid wall
///   app.world.spawn()
///     ..insert(Transform2D())
///     ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 100, height: 20)))
///     ..insert(const CollisionConfig.solid());
///
///   // Spawn a trigger zone
///   app.world.spawn()
///     ..insert(Transform2D())
///     ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 50, height: 50)))
///     ..insert(const CollisionConfig.sensor());
///
///   await app.run();
/// }
/// ```
///
/// ## Collision Layers
///
/// Use [CollisionConfig] to control what entities interact:
///
/// ```dart
/// // Define game-specific layers
/// abstract class GameLayers {
///   static const int solid = CollisionLayers.solid;
///   static const int trigger = CollisionLayers.trigger;
///   static const int player = CollisionLayers.gameLayersStart << 0;
///   static const int enemy = CollisionLayers.gameLayersStart << 1;
/// }
///
/// // Player collides with solid, trigger, and enemy layers
/// entity.insert(CollisionConfig(
///   layer: GameLayers.player,
///   mask: GameLayers.solid | GameLayers.trigger | GameLayers.enemy,
/// ));
/// ```
///
/// ## Handling Collisions
///
/// Query for [CollisionEvent] to respond to collisions:
///
/// ```dart
/// class MySystem implements System {
///   @override
///   Future<void> run(World world) async {
///     for (final (entity, event, player)
///         in world.query2<CollisionEvent, Player>().iter()) {
///       // Player collided with event.other
///       if (world.has<Enemy>(event.other)) {
///         // Handle player-enemy collision
///       }
///     }
///   }
/// }
/// ```
library fledge_physics;

// Plugin
export 'src/plugin.dart';

// Components
export 'src/components/collision_config.dart';
export 'src/components/collision_event.dart';
export 'src/components/velocity.dart';

// Layers
export 'src/layers/collision_layers.dart';

// Systems
export 'src/systems/collision_cleanup.dart';
export 'src/systems/collision_detection.dart';
export 'src/systems/collision_resolution.dart';
