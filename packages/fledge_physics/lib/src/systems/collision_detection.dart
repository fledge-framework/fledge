import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

import '../components/collision_config.dart';
import '../components/collision_event.dart';
import '../layers/collision_layers.dart';

/// Detects collisions between entities and generates [CollisionEvent]s.
///
/// Uses a broad-phase/narrow-phase approach:
/// 1. Broad-phase: Check combined bounding boxes to filter pairs
/// 2. Narrow-phase: Check individual collision shapes
///
/// ## Layer Filtering
///
/// Only entities with compatible layers generate collision events.
/// Entities without [CollisionConfig] default to colliding with all layers.
///
/// Collision occurs when:
/// ```
/// (A.layer & B.mask) != 0 && (B.layer & A.mask) != 0
/// ```
///
/// ## Events
///
/// Collision events are bidirectional - both entities receive an event.
/// Events are removed by [CollisionCleanupSystem] at end of frame.
class CollisionDetectionSystem implements System {
  /// Creates a collision detection system.
  const CollisionDetectionSystem();

  @override
  SystemMeta get meta => SystemMeta(
        name: 'collision_detection',
        reads: {
          ComponentId.of<Transform2D>(),
          ComponentId.of<Collider>(),
          ComponentId.of<CollisionConfig>(),
        },
        writes: {ComponentId.of<CollisionEvent>()},
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final entities = world.query2<Transform2D, Collider>().iter().toList();

    // Build collision data for each entity
    final entityData =
        <Entity, (List<Rect> shapes, Rect broadBounds, int layer, int mask)>{};

    for (final (entity, transform, collider) in entities) {
      if (collider.isEmpty) continue;

      // Get collision config (defaults if not present)
      final config = world.get<CollisionConfig>(entity);
      final layer = config?.layer ?? CollisionLayers.all;
      final mask = config?.mask ?? CollisionLayers.all;

      final tx = transform.translation.x;
      final ty = transform.translation.y;

      // Compute world-space bounds for each shape
      final shapes = <Rect>[];
      for (final shape in collider.shapes) {
        final localBounds = shape.bounds;
        shapes.add(
          Rect.fromLTWH(
            localBounds.left + tx,
            localBounds.top + ty,
            localBounds.width,
            localBounds.height,
          ),
        );
      }

      // Compute combined bounds for broad-phase
      final combinedBounds = collider.bounds;
      final broadBounds = Rect.fromLTWH(
        combinedBounds.left + tx,
        combinedBounds.top + ty,
        combinedBounds.width,
        combinedBounds.height,
      );

      entityData[entity] = (shapes, broadBounds, layer, mask);
    }

    // Check all pairs for collision
    final entityList = entityData.keys.toList();
    for (var i = 0; i < entityList.length; i++) {
      for (var j = i + 1; j < entityList.length; j++) {
        final entityA = entityList[i];
        final entityB = entityList[j];
        final dataA = entityData[entityA]!;
        final dataB = entityData[entityB]!;

        // Layer filtering: both must agree to collide
        final layerA = dataA.$3;
        final maskA = dataA.$4;
        final layerB = dataB.$3;
        final maskB = dataB.$4;

        if ((layerA & maskB) == 0 || (layerB & maskA) == 0) {
          continue; // Layers don't interact
        }

        // Broad-phase: skip if combined bounds don't overlap
        if (!_intersects(dataA.$2, dataB.$2)) {
          continue;
        }

        // Narrow-phase: check individual shapes
        if (_shapesIntersect(dataA.$1, dataB.$1)) {
          world.insert(entityA, CollisionEvent(entityB));
          world.insert(entityB, CollisionEvent(entityA));
        }
      }
    }
  }

  /// Returns true if any shape from A intersects any shape from B.
  bool _shapesIntersect(List<Rect> shapesA, List<Rect> shapesB) {
    for (final a in shapesA) {
      for (final b in shapesB) {
        if (_intersects(a, b)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Returns true if two rectangles intersect.
  bool _intersects(Rect a, Rect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
  }
}
