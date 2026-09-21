import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

import '../broad_phase/spatial_hash.dart';
import '../collision/collision_shapes.dart';
import '../components/collision_config.dart';
import '../components/collision_event.dart';
import '../layers/collision_layers.dart';

/// Detects collisions between entities and writes [CollisionEvent]s to
/// the ECS event queue.
///
/// Uses a two-phase approach:
///
/// 1. **Broad-phase**: A uniform-grid [SpatialHash] narrows the O(n^2)
///    pair space to only entities sharing a grid cell.
/// 2. **Narrow-phase**: The per-shape AABB overlap test runs on the
///    surviving pairs.
///
/// ## Layer filtering
///
/// Only entities with compatible layer/mask pairs generate events.
/// Entities without [CollisionConfig] default to
/// `layer = mask = CollisionLayers.all`.
///
/// Collision occurs when:
/// ```
/// (A.layer & B.mask) != 0 && (B.layer & A.mask) != 0
/// ```
///
/// ## Events
///
/// One [CollisionEvent] is emitted per unordered pair per frame — it
/// carries both entities, so consumers should not expect two events for
/// a given collision.
///
/// The events queue is auto double-buffered by `world.updateEvents()`
/// (driven from `App.tick`), so no per-frame cleanup system is needed.
class CollisionDetectionSystem implements System {
  /// Cell size used by the internal [SpatialHash]. Roughly 2x the
  /// typical collider dimension gives the best balance between insert
  /// cost and candidate-pair count for common games.
  final double spatialHashCellSize;

  /// Creates a collision detection system.
  const CollisionDetectionSystem({this.spatialHashCellSize = 64.0});

  @override
  SystemMeta get meta => SystemMeta(
    name: 'collision_detection',
    reads: {
      ComponentId.of<Transform2D>(),
      ComponentId.of<Collider>(),
      ComponentId.of<CollisionConfig>(),
    },
    // Detection writes only the event queue — no more component
    // churn from per-frame CollisionEvent insert/remove. We still
    // declare an explicit ordering vs resolution because both
    // systems live in Schedules.update and resolution clamps
    // velocities before integration.
    eventWrites: {CollisionEvent},
    after: const ['collision_resolution'],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    // The plugin registers the event queue at build time; if a caller
    // has ripped the plugin apart and forgotten to register, bail out
    // rather than throwing — this system is otherwise side-effect free.
    if (!world.events.isRegistered<CollisionEvent>()) return;

    final writer = world.eventWriter<CollisionEvent>();

    // Snapshot the per-entity collision data in one pass over the query.
    // Kept as parallel lists for cache-friendly iteration in the pair
    // loop — the previous `Map<Entity, tuple>` was fine, but the
    // spatial-hash broad-phase indexes by list position anyway.
    final entities = <Entity>[];
    final shapes = <List<Rect>>[];
    final broadBounds = <Rect>[];
    final layers = <int>[];
    final masks = <int>[];

    for (final (entity, transform, collider)
        in world.query2<Transform2D, Collider>().iter()) {
      if (collider.isEmpty) continue;

      final config = world.get<CollisionConfig>(entity);
      final layer = config?.layer ?? CollisionLayers.all;
      final mask = config?.mask ?? CollisionLayers.all;

      final tx = transform.translation.x;
      final ty = transform.translation.y;

      final entityShapes = <Rect>[];
      for (final shape in collider.shapes) {
        final b = shape.bounds;
        entityShapes.add(
          Rect.fromLTWH(b.left + tx, b.top + ty, b.width, b.height),
        );
      }

      final combined = collider.bounds;
      final broad = Rect.fromLTWH(
        combined.left + tx,
        combined.top + ty,
        combined.width,
        combined.height,
      );

      entities.add(entity);
      shapes.add(entityShapes);
      broadBounds.add(broad);
      layers.add(layer);
      masks.add(mask);
    }

    if (entities.length < 2) return;

    // Broad-phase: bin entities into the spatial hash.
    final hash = SpatialHash(cellSize: spatialHashCellSize);
    for (var i = 0; i < entities.length; i++) {
      hash.insert(i, broadBounds[i]);
    }

    // Pair generation via spatial hash. `i < j` guarantees we visit each
    // unordered pair at most once.
    for (var i = 0; i < entities.length; i++) {
      for (final j in hash.queryOverlapping(broadBounds[i])) {
        if (i >= j) continue;

        // Layer filtering: both sides must agree to collide.
        if ((layers[i] & masks[j]) == 0 || (layers[j] & masks[i]) == 0) {
          continue;
        }

        // Cells were binned by broad AABB, so pairs sharing a cell may
        // not actually overlap — re-check the broad AABBs first, then
        // fall through to the narrow-phase.
        if (!_intersects(broadBounds[i], broadBounds[j])) continue;

        if (_shapesIntersect(shapes[i], shapes[j])) {
          writer.send(
            CollisionEvent(entityA: entities[i], entityB: entities[j]),
          );
        }
      }
    }
  }

  /// Returns true if any shape from A intersects any shape from B.
  bool _shapesIntersect(List<Rect> shapesA, List<Rect> shapesB) {
    for (final a in shapesA) {
      for (final b in shapesB) {
        if (_intersects(a, b)) return true;
      }
    }
    return false;
  }

  /// Returns true if two rectangles intersect (open on all sides — edges
  /// touching does not count as an intersection).
  bool _intersects(Rect a, Rect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
  }
}
