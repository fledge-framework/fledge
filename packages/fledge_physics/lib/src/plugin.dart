import 'package:fledge_ecs/fledge_ecs.dart';

import 'components/collision_event.dart';
import 'components/contact_yield.dart';
import 'physics_mode.dart';
import 'systems/collision_detection.dart';
import 'systems/collision_resolution.dart';
import 'systems/contact_yield_tracker.dart';
import 'systems/velocity_integration.dart';

/// Physics and collision handling plugin.
///
/// Provides:
///
/// - [CollisionResolutionSystem] - Clamps `Velocity` before movement so
///   dynamic entities can't push into solid static colliders.
/// - [VelocityIntegrationSystem] - Advances `Transform2D` by the
///   clamped `Velocity` for the current step.
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
/// ## Fixed vs variable timestep
///
/// The default [PhysicsMode.variable] scales velocity by
/// `WallTime.delta` and schedules every system in `Schedules.update`.
/// Games that need deterministic simulation (netcode prediction,
/// replays, replays) can switch to [PhysicsMode.fixed], which scales
/// by `FixedTimestep.stepSeconds` and schedules every system in
/// `Schedules.fixedUpdate`:
///
/// ```dart
/// app.addPlugin(PhysicsPlugin(
///   config: PhysicsConfig(mode: PhysicsMode.fixed),
/// ));
/// ```
///
/// Either way, `Velocity` is expressed in pixels per 60 Hz frame:
/// `Velocity(0, 4)` produces 240 px/s regardless of mode or step.
///
/// ## System ordering
///
/// Within a step, systems run in this fixed order:
///
///     collision_resolution → velocity_integration → collision_detection
///
/// Resolution clamps `Velocity`. Integration then applies the clamped
/// `Velocity` to `Transform2D`. Detection sees the post-move
/// positions and emits [CollisionEvent]s. Every ordering is declared
/// explicitly on the systems' `SystemMeta`, so the plugin does not
/// rely on registration order between its systems.
///
/// Anything that writes `Velocity` (input, AI steering, knockback)
/// must run in `Schedules.preUpdate` / `Schedules.fixedPreUpdate` or
/// declare `before: [CollisionResolutionSystem.systemName]` in its
/// `SystemMeta`.
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

    // Yield events + tracker. The resolver only touches the tracker
    // when it exists, so games that never use `yieldAfter` still get
    // the bookkeeping installed for free — the tracker's per-frame
    // work short-circuits when fewer than two eligible dynamic
    // bodies exist.
    app.addEvent<ContactYieldStarted>();
    app.addEvent<ContactYieldEnded>();
    app.insertResource(ContactYieldTracker());

    final schedule = config.mode == PhysicsMode.fixed
        ? Schedules.fixedUpdate
        : Schedules.update;

    if (config.enableResolution) {
      app.addSystem(
        config.mode == PhysicsMode.fixed
            ? const CollisionResolutionSystem.fixed()
            : const CollisionResolutionSystem(),
        schedule: schedule,
      );
    }
    if (config.enableIntegration) {
      app.addSystem(
        config.mode == PhysicsMode.fixed
            ? const VelocityIntegrationSystem.fixed()
            : const VelocityIntegrationSystem(),
        schedule: schedule,
      );
    }
    app.addSystem(
      CollisionDetectionSystem(spatialHashCellSize: config.spatialHashCellSize),
      schedule: schedule,
    );
  }

  @override
  void cleanup() {
    // No cleanup needed — the event queue is owned by the world.
  }
}

/// Configuration for the physics plugin.
class PhysicsConfig {
  /// Which clock physics systems read.
  final PhysicsMode mode;

  /// Whether to enable collision resolution (blocking movement).
  ///
  /// When false, entities can move through solid colliders.
  /// Useful for debugging or ghost-mode features.
  final bool enableResolution;

  /// Whether the plugin adds [VelocityIntegrationSystem].
  ///
  /// Turn this off when a game owns its own integration and only
  /// wants fledge_physics for resolution + detection.
  final bool enableIntegration;

  /// Cell size (world units, typically pixels) used by the broad-phase
  /// spatial hash inside `CollisionDetectionSystem`.
  ///
  /// A good rule of thumb is roughly 2x your typical collider size.
  final double spatialHashCellSize;

  /// Creates physics configuration.
  const PhysicsConfig({
    this.mode = PhysicsMode.variable,
    this.enableResolution = true,
    this.enableIntegration = true,
    this.spatialHashCellSize = 64.0,
  });
}
