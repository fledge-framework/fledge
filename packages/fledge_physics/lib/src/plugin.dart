import 'package:fledge_ecs/fledge_ecs.dart';

import 'components/collision_event.dart';
import 'systems/collision_detection.dart';
import 'systems/collision_resolution.dart';

/// Physics and collision handling plugin.
///
/// Provides:
///
/// - [CollisionResolutionSystem] - Clamps `Velocity` before movement so
///   dynamic entities can't push into solid static colliders.
/// - [CollisionDetectionSystem] - Broad-phased (spatial hash) collision
///   detection that publishes [CollisionEvent]s to the ECS event queue.
///
/// The plugin also calls `App.addEvent<CollisionEvent>()`, so consumers
/// can call `world.eventReader<CollisionEvent>()` from any system without
/// registering the event type themselves.
///
/// ## Usage
///
/// ```dart
/// app.addPlugin(PhysicsPlugin());
/// ```
///
/// Configure collision behavior with [CollisionConfig]:
///
/// ```dart
/// // Solid wall
/// entity.insert(const CollisionConfig.solid());
///
/// // Trigger zone (no blocking, events only)
/// entity.insert(const CollisionConfig.sensor());
///
/// // Custom layers
/// entity.insert(CollisionConfig(
///   layer: GameLayers.player,
///   mask: GameLayers.solid | GameLayers.trigger,
/// ));
/// ```
///
/// ## Configuration
///
/// ```dart
/// app.addPlugin(PhysicsPlugin(
///   config: PhysicsConfig(
///     enableResolution: false, // Disable blocking for debug
///   ),
/// ));
/// ```
///
/// ## System ordering
///
/// `collision_resolution` runs in `Schedules.update`; anything that
/// writes `Velocity` (input, AI steering, knockback) MUST run in
/// `Schedules.preUpdate` or declare `before: ['collision_resolution']`
/// in its `SystemMeta`. Otherwise the scheduler falls back to
/// registration order, and depending on plugin insertion order the
/// player can walk straight through walls.
class PhysicsPlugin implements Plugin {
  /// Configuration for the physics plugin.
  final PhysicsConfig config;

  /// Creates a physics plugin with optional configuration.
  const PhysicsPlugin({this.config = const PhysicsConfig()});

  @override
  void build(App app) {
    // Register the CollisionEvent queue up front so consumers can read
    // it without needing to know the plugin's internals.
    app.addEvent<CollisionEvent>();

    // Resolution clamps velocity before integration. Detection sees the
    // transforms the game integrates from that clamped velocity — its
    // `after: ['collision_resolution']` constraint (declared on the
    // system's SystemMeta) pins that order explicitly, so this plugin
    // does not rely on registration order between its two systems.
    if (config.enableResolution) {
      app.addSystem(
        const CollisionResolutionSystem(),
        schedule: Schedules.update,
      );
    }
    app.addSystem(
      CollisionDetectionSystem(
        spatialHashCellSize: config.spatialHashCellSize,
      ),
      schedule: Schedules.update,
    );
  }

  @override
  void cleanup() {
    // No cleanup needed — the event queue is owned by the world.
  }
}

/// Configuration for the physics plugin.
class PhysicsConfig {
  /// Whether to enable collision resolution (blocking movement).
  ///
  /// When false, entities can move through solid colliders.
  /// Useful for debugging or ghost-mode features.
  final bool enableResolution;

  /// Cell size (world units, typically pixels) used by the broad-phase
  /// spatial hash inside `CollisionDetectionSystem`.
  ///
  /// A good rule of thumb is roughly 2x your typical collider size.
  final double spatialHashCellSize;

  /// Creates physics configuration.
  const PhysicsConfig({
    this.enableResolution = true,
    this.spatialHashCellSize = 64.0,
  });
}
