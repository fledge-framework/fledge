import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

import '../collision/collision_shapes.dart';
import '../components/collision_config.dart';
import '../components/velocity.dart';
import '../layers/collision_layers.dart';
import '../physics_mode.dart';

/// Adjusts velocity to prevent movement into solid colliders.
///
/// Implements wall-sliding: if blocked diagonally, still allows
/// movement along unblocked axes.
///
/// ## Timing
///
/// The dt source depends on [PhysicsMode]:
///
/// - [PhysicsMode.variable] (default) reads `WallTime.delta`.
///   Schedule in `Schedules.update`.
/// - [PhysicsMode.fixed] reads `FixedTimestep.stepSeconds`. Schedule
///   in `Schedules.fixedUpdate` alongside [VelocityIntegrationSystem].
///
/// Velocity is interpreted as pixels per 60 Hz frame in either mode
/// so game code and existing tests survive the mode switch.
///
/// ## Layer Filtering
///
/// Only resolves against entities with compatible layers.
/// Entities without [CollisionConfig] default to colliding with all layers.
///
/// ## Sensors
///
/// Entities with [CollisionConfig.isSensor] = true are skipped.
/// Sensors generate collision events but don't block movement.
///
/// ## Static vs Dynamic
///
/// - Static colliders: Have [Collider] but no [Velocity]
/// - Dynamic colliders: Have [Collider] and [Velocity]
///
/// Only dynamic entities have their movement resolved against static ones.
class CollisionResolutionSystem implements System {
  /// Which clock this system reads.
  final PhysicsMode mode;

  /// Creates a variable-timestep resolution system.
  const CollisionResolutionSystem() : mode = PhysicsMode.variable;

  /// Creates a fixed-timestep resolution system.
  const CollisionResolutionSystem.fixed() : mode = PhysicsMode.fixed;

  @override
  SystemMeta get meta => SystemMeta(
    name: 'collision_resolution',
    reads: {
      ComponentId.of<Transform2D>(),
      ComponentId.of<Collider>(),
      ComponentId.of<CollisionConfig>(),
    },
    writes: {ComponentId.of<Velocity>()},
    resourceReads: mode == PhysicsMode.fixed ? {FixedTimestep} : {WallTime},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final double dt;
    if (mode == PhysicsMode.fixed) {
      final ft = world.getResource<FixedTimestep>();
      if (ft == null) return;
      dt = ft.stepSeconds;
    } else {
      final wt = world.getResource<WallTime>();
      if (wt == null || wt.delta == 0) return;
      dt = wt.delta;
    }
    if (dt <= 0) return;

    // Scale factor for velocity — pixels-per-60Hz-frame → pixels-per-step.
    final timeScale = dt / physicsReferenceFrameSeconds;

    // Build the pool of potential blockers. A record per shape carries
    // its world-space bounds, layer + mask for layer filtering, the
    // owning entity, and a flag saying whether the blocker is dynamic
    // (i.e. an eligible participant in dynamic-vs-dynamic blocking).
    final blockers = <_Blocker>[];

    for (final (entity, transform, collider)
        in world.query2<Transform2D, Collider>().iter()) {
      final config = world.get<CollisionConfig>(entity);

      // Sensors never block movement — they only generate events.
      if (config?.isSensor ?? false) continue;

      final isDynamic = world.has<Velocity>(entity);
      // Dynamic bodies only enter the blocker pool if they opted in
      // via `CollisionConfig.blocksDynamic`. Static bodies (no
      // Velocity) always enter.
      if (isDynamic && !(config?.blocksDynamic ?? false)) continue;

      final layer = config?.layer ?? CollisionLayers.all;
      final mask = config?.mask ?? CollisionLayers.all;

      final tx = transform.translation.x;
      final ty = transform.translation.y;

      for (final shape in collider.shapes) {
        final bounds = shape.bounds;
        blockers.add(
          _Blocker(
            bounds: Rect.fromLTWH(
              bounds.left + tx,
              bounds.top + ty,
              bounds.width,
              bounds.height,
            ),
            entity: entity,
            layer: layer,
            mask: mask,
            isDynamic: isDynamic,
          ),
        );
      }
    }

    // Resolve collisions for all moving entities
    for (final (entity, transform, collider, velocity)
        in world.query3<Transform2D, Collider, Velocity>().iter()) {
      if (!velocity.isMoving) continue;

      // Get this entity's collision config
      final config = world.get<CollisionConfig>(entity);
      final myLayer = config?.layer ?? CollisionLayers.all;
      final myMask = config?.mask ?? CollisionLayers.all;
      final myBlocksDynamic = config?.blocksDynamic ?? false;

      // Filter blockers to only those we can collide with:
      //  - self is never a blocker;
      //  - layer/mask must agree in both directions;
      //  - dynamic blockers only apply when we ALSO opted into
      //    dynamic-vs-dynamic blocking.
      final relevantColliders = <Rect>[];
      for (final b in blockers) {
        if (b.entity == entity) continue;
        if (b.isDynamic && !myBlocksDynamic) continue;
        if ((myLayer & b.mask) == 0 || (b.layer & myMask) == 0) continue;
        relevantColliders.add(b.bounds);
      }

      if (relevantColliders.isEmpty) continue;

      final currentX = transform.translation.x;
      final currentY = transform.translation.y;
      final localBounds = collider.bounds;

      // Scale velocity by time (same as VelocityApplySystem will do)
      final moveX = velocity.x * timeScale;
      final moveY = velocity.y * timeScale;

      // Check if full movement is valid
      if (!_wouldCollide(
        currentX + moveX,
        currentY + moveY,
        localBounds,
        relevantColliders,
      )) {
        // Full movement OK, no adjustment needed
        continue;
      }

      // Try X movement only (slide along Y wall)
      final canMoveX =
          moveX != 0 &&
          !_wouldCollide(
            currentX + moveX,
            currentY,
            localBounds,
            relevantColliders,
          );

      // Try Y movement only (slide along X wall)
      final canMoveY =
          moveY != 0 &&
          !_wouldCollide(
            currentX,
            currentY + moveY,
            localBounds,
            relevantColliders,
          );

      // Adjust velocity based on what's allowed
      if (canMoveX && !canMoveY) {
        velocity.y = 0; // Block Y, allow X
      } else if (canMoveY && !canMoveX) {
        velocity.x = 0; // Block X, allow Y
      } else if (!canMoveX && !canMoveY) {
        velocity.reset(); // Blocked completely
      }
      // If both can move independently, keep original velocity
      // (diagonal movement into corner - let full movement happen)
    }
  }

  /// Check if placing entity at (x, y) would collide with any static collider.
  bool _wouldCollide(
    double x,
    double y,
    Rect localBounds,
    List<Rect> colliders,
  ) {
    final entityBounds = Rect.fromLTWH(
      localBounds.left + x,
      localBounds.top + y,
      localBounds.width,
      localBounds.height,
    );

    for (final collider in colliders) {
      if (_intersects(entityBounds, collider)) {
        return true;
      }
    }
    return false;
  }

  bool _intersects(Rect a, Rect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
  }
}

/// One entry in the resolution system's per-frame blocker pool.
class _Blocker {
  final Rect bounds;
  final Entity entity;
  final int layer;
  final int mask;
  final bool isDynamic;

  _Blocker({
    required this.bounds,
    required this.entity,
    required this.layer,
    required this.mask,
    required this.isDynamic,
  });
}
