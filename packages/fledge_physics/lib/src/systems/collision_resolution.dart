import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

import '../components/collision_config.dart';
import '../components/velocity.dart';
import '../layers/collision_layers.dart';

/// Adjusts velocity to prevent movement into solid colliders.
///
/// Implements wall-sliding: if blocked diagonally, still allows
/// movement along unblocked axes.
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
  /// Creates a collision resolution system.
  const CollisionResolutionSystem();

  @override
  SystemMeta get meta => SystemMeta(
        name: 'collision_resolution',
        reads: {
          ComponentId.of<Transform2D>(),
          ComponentId.of<Collider>(),
          ComponentId.of<CollisionConfig>(),
        },
        writes: {ComponentId.of<Velocity>()},
        resourceReads: {Time},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>();
    if (time == null || time.delta == 0) return;

    // Scale factor for velocity (matches VelocityApplySystem)
    final timeScale = time.delta / 0.01667;

    // Build list of static collider shapes with layer info
    // Static = has Collider, no Velocity, not a sensor
    final staticColliders = <(Rect bounds, int layer, int mask)>[];

    for (final (entity, transform, collider)
        in world.query2<Transform2D, Collider>().iter()) {
      // Skip entities that have velocity (dynamic, not static)
      if (world.has<Velocity>(entity)) continue;

      // Get collision config
      final config = world.get<CollisionConfig>(entity);

      // Skip sensors - they don't block movement
      if (config?.isSensor ?? false) continue;

      final layer = config?.layer ?? CollisionLayers.all;
      final mask = config?.mask ?? CollisionLayers.all;

      final tx = transform.translation.x;
      final ty = transform.translation.y;

      for (final shape in collider.shapes) {
        final bounds = shape.bounds;
        staticColliders.add((
          Rect.fromLTWH(
            bounds.left + tx,
            bounds.top + ty,
            bounds.width,
            bounds.height,
          ),
          layer,
          mask,
        ));
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

      // Filter static colliders to only those we can collide with
      final relevantColliders = <Rect>[];
      for (final (bounds, staticLayer, staticMask) in staticColliders) {
        // Check layer compatibility
        if ((myLayer & staticMask) != 0 && (staticLayer & myMask) != 0) {
          relevantColliders.add(bounds);
        }
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
      final canMoveX = moveX != 0 &&
          !_wouldCollide(
            currentX + moveX,
            currentY,
            localBounds,
            relevantColliders,
          );

      // Try Y movement only (slide along X wall)
      final canMoveY = moveY != 0 &&
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
