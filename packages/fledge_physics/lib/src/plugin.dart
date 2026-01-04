import 'package:fledge_ecs/fledge_ecs.dart';

import 'systems/collision_cleanup.dart';
import 'systems/collision_detection.dart';
import 'systems/collision_resolution.dart';

/// Physics and collision handling plugin.
///
/// Provides:
/// - [CollisionResolutionSystem] - Prevents movement into solid colliders
/// - [CollisionDetectionSystem] - Detects overlaps and generates events
/// - [CollisionCleanupSystem] - Removes collision events at end of frame
///
/// ## Usage
///
/// Add the plugin to your app:
/// ```dart
/// app.addPlugin(PhysicsPlugin());
/// ```
///
/// Configure collision behavior with [CollisionConfig] component:
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
/// Use [PhysicsConfig] to customize behavior:
/// ```dart
/// app.addPlugin(PhysicsPlugin(
///   config: PhysicsConfig(
///     enableResolution: false, // Disable blocking for debug
///   ),
/// ));
/// ```
class PhysicsPlugin implements Plugin {
  /// Configuration for the physics plugin.
  final PhysicsConfig config;

  /// Creates a physics plugin with optional configuration.
  PhysicsPlugin({this.config = const PhysicsConfig()});

  @override
  void build(App app) {
    // Add collision resolution before velocity is applied
    if (config.enableResolution) {
      app.addSystem(CollisionResolutionSystem(), stage: CoreStage.update);
    }

    // Add collision detection after velocity is applied
    app.addSystem(CollisionDetectionSystem(), stage: CoreStage.update);

    // Clean up collision events at end of frame
    app.addSystem(CollisionCleanupSystem(), stage: CoreStage.last);
  }

  @override
  void cleanup() {
    // No cleanup needed
  }
}

/// Configuration for the physics plugin.
class PhysicsConfig {
  /// Whether to enable collision resolution (blocking movement).
  ///
  /// When false, entities can move through solid colliders.
  /// Useful for debugging or ghost-mode features.
  final bool enableResolution;

  /// Creates physics configuration.
  const PhysicsConfig({
    this.enableResolution = true,
  });
}
