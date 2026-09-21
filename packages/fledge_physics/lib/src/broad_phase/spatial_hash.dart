import 'dart:ui' show Rect;

/// Uniform-grid spatial hash used by `CollisionDetectionSystem` to cut
/// broad-phase pair generation from O(n^2) down to O(n) for well-spread
/// scenes.
///
/// Entities register their world-space AABB with [insert]; queries via
/// [queryOverlapping] return every entity index that shares at least one
/// grid cell with the query AABB.
///
/// The class is generic over the entity index type (typically an `int`
/// pointing into an `entityData` list held by the caller), which keeps
/// it decoupled from the ECS and easy to test in pure Dart.
///
/// ```dart
/// final hash = SpatialHash(cellSize: 64);
/// for (var i = 0; i < entities.length; i++) {
///   hash.insert(i, entities[i].aabb);
/// }
/// for (var i = 0; i < entities.length; i++) {
///   for (final j in hash.queryOverlapping(entities[i].aabb)) {
///     if (i >= j) continue; // process each unordered pair once
///     // narrow-phase(i, j)
///   }
/// }
/// ```
class SpatialHash {
  /// Side length of one grid cell, in the same units as the AABBs
  /// passed to [insert] / [queryOverlapping] (usually pixels).
  ///
  /// A good rule of thumb is roughly 2x the average collider size:
  /// smaller means more cells per AABB (more inserts and larger candidate
  /// sets); larger means more entities per cell (bigger candidate sets).
  final double cellSize;

  /// Grid cell -> list of entity indices whose AABB overlaps that cell.
  ///
  /// Keyed by a `(cellX, cellY)` record; record equality is
  /// structural, so no manual packing/hashing is required and
  /// negative cell coordinates round-trip correctly.
  final Map<(int, int), List<int>> _cells = <(int, int), List<int>>{};

  /// Creates a spatial hash with the given [cellSize] (defaults to 64px,
  /// a reasonable game-scale). Must be > 0.
  SpatialHash({this.cellSize = 64.0})
      : assert(cellSize > 0, 'cellSize must be positive');

  /// Adds [entityIndex] to every grid cell that overlaps [aabb].
  ///
  /// Empty/zero-area AABBs are still inserted at their origin cell so
  /// they can collide with overlapping boxes.
  void insert(int entityIndex, Rect aabb) {
    final minX = (aabb.left / cellSize).floor();
    final maxX = (aabb.right / cellSize).floor();
    final minY = (aabb.top / cellSize).floor();
    final maxY = (aabb.bottom / cellSize).floor();

    for (var cy = minY; cy <= maxY; cy++) {
      for (var cx = minX; cx <= maxX; cx++) {
        (_cells[(cx, cy)] ??= <int>[]).add(entityIndex);
      }
    }
  }

  /// Returns every entity index that shares at least one cell with
  /// [aabb], deduplicated.
  ///
  /// The returned iterable is a fresh `List` — safe to consume multiple
  /// times or store. Order is unspecified.
  Iterable<int> queryOverlapping(Rect aabb) {
    final minX = (aabb.left / cellSize).floor();
    final maxX = (aabb.right / cellSize).floor();
    final minY = (aabb.top / cellSize).floor();
    final maxY = (aabb.bottom / cellSize).floor();

    final seen = <int>{};
    for (var cy = minY; cy <= maxY; cy++) {
      for (var cx = minX; cx <= maxX; cx++) {
        final bucket = _cells[(cx, cy)];
        if (bucket == null) continue;
        for (final idx in bucket) {
          seen.add(idx);
        }
      }
    }
    return seen;
  }

  /// Clears all buckets. Call between frames to reuse the same hash.
  void clear() => _cells.clear();

  /// Number of populated cells (diagnostic).
  int get cellCount => _cells.length;
}
