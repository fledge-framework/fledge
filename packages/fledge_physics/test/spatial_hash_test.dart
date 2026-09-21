import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:fledge_physics/fledge_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-math tests for the broad-phase spatial hash. Flutter binding is
/// only pulled in for `dart:ui`'s `Rect`; the code under test itself is
/// pure Dart.
void main() {
  group('SpatialHash', () {
    test('inserts an entity into every cell its AABB overlaps', () {
      final hash = SpatialHash(cellSize: 10);
      // AABB spans cells (0,0)..(1,1) inclusive (10x10 rect at origin
      // sitting exactly on the boundary — floor(10/10) = 1).
      hash.insert(42, const Rect.fromLTWH(0, 0, 10, 10));
      // Querying inside cell (0,0) returns 42.
      expect(
        hash.queryOverlapping(const Rect.fromLTWH(1, 1, 1, 1)),
        contains(42),
      );
      // Querying at the top-right corner (in cell (1,1)) also returns
      // 42 because floor(10/10) == 1.
      expect(
        hash.queryOverlapping(const Rect.fromLTWH(9.5, 9.5, 0.5, 0.5)),
        contains(42),
      );
    });

    test('non-overlapping AABBs do not surface each other', () {
      final hash = SpatialHash(cellSize: 10);
      hash.insert(1, const Rect.fromLTWH(0, 0, 5, 5));
      hash.insert(2, const Rect.fromLTWH(100, 100, 5, 5));

      final near1 = hash.queryOverlapping(const Rect.fromLTWH(0, 0, 5, 5));
      expect(near1, contains(1));
      expect(near1, isNot(contains(2)));
    });

    test('queryOverlapping deduplicates entities that span many cells', () {
      final hash = SpatialHash(cellSize: 10);
      // Big AABB spans a 4x4 block of cells.
      hash.insert(99, const Rect.fromLTWH(0, 0, 40, 40));
      final result = hash
          .queryOverlapping(const Rect.fromLTWH(0, 0, 40, 40))
          .toList();
      expect(
        result.where((i) => i == 99).length,
        1,
        reason: 'entity should be deduplicated across cells it occupies',
      );
    });

    test('handles negative coordinates via record-keyed cells', () {
      final hash = SpatialHash(cellSize: 10);
      hash.insert(1, const Rect.fromLTWH(-25, -25, 5, 5));
      hash.insert(2, const Rect.fromLTWH(25, 25, 5, 5));
      expect(
        hash.queryOverlapping(const Rect.fromLTWH(-25, -25, 5, 5)),
        contains(1),
      );
      expect(
        hash.queryOverlapping(const Rect.fromLTWH(-25, -25, 5, 5)),
        isNot(contains(2)),
      );
    });

    test('clear empties all buckets', () {
      final hash = SpatialHash(cellSize: 10);
      hash.insert(1, const Rect.fromLTWH(0, 0, 5, 5));
      hash.clear();
      expect(hash.cellCount, 0);
      expect(hash.queryOverlapping(const Rect.fromLTWH(0, 0, 5, 5)), isEmpty);
    });
  });

  group('SpatialHash as a broad-phase', () {
    // Load-bearing perf test: given 500 entities on a wide grid, the
    // spatial-hash broad-phase should visit dramatically fewer pairs
    // than the naive O(n^2). If someone rewrites the hash later and
    // regresses to nearest-neighbour-only or accidentally puts everyone
    // into one cell, this catches it.
    test('500 entities on a scattered grid produce <10% of naive O(n^2) '
        'candidate pairs', () {
      const gridSide = 25; // 25x25 = 625 slots, 500 populated
      const spacing = 50.0; // entities well-separated
      const colliderSize = 16.0;
      const cellSize = 32.0;

      final entities = <Rect>[];
      for (var i = 0; i < 500; i++) {
        final gx = i % gridSide;
        final gy = i ~/ gridSide;
        entities.add(
          Rect.fromLTWH(gx * spacing, gy * spacing, colliderSize, colliderSize),
        );
      }

      final hash = SpatialHash(cellSize: cellSize);
      for (var i = 0; i < entities.length; i++) {
        hash.insert(i, entities[i]);
      }

      var candidatePairs = 0;
      for (var i = 0; i < entities.length; i++) {
        for (final j in hash.queryOverlapping(entities[i])) {
          if (i >= j) continue;
          candidatePairs++;
        }
      }

      final naivePairs = entities.length * (entities.length - 1) ~/ 2;
      // Guardrail: broad-phase should cut pair count to well under
      // 10% of naive.
      expect(
        candidatePairs,
        lessThan(naivePairs ~/ 10),
        reason:
            'spatial hash should slash candidate pairs vs naive '
            'O(n^2) — naive=$naivePairs, hash=$candidatePairs',
      );
      // Sanity: for well-separated entities there are essentially no
      // real overlapping pairs.
      expect(
        candidatePairs,
        lessThan(entities.length),
        reason: 'well-separated grid should surface very few pairs',
      );
    });

    test('overlapping AABBs are surfaced as candidate pairs', () {
      // Sanity: if two entities really do overlap, the hash must include
      // them in each other's query.
      final hash = SpatialHash(cellSize: 32);
      final a = const Rect.fromLTWH(0, 0, 10, 10);
      final b = const Rect.fromLTWH(5, 5, 10, 10);
      hash.insert(0, a);
      hash.insert(1, b);

      final aCandidates = hash.queryOverlapping(a).toSet();
      expect(aCandidates, containsAll(<int>[0, 1]));
    });

    test('asserts on non-positive cellSize', () {
      expect(() => SpatialHash(cellSize: 0), throwsA(isA<AssertionError>()));
      expect(() => SpatialHash(cellSize: -1), throwsA(isA<AssertionError>()));
    });
  });

  // Regression coverage for a subtle interaction: without the hash, a
  // very wide AABB inserted at (huge X, huge Y) shouldn't blow up cell
  // count or time — but we cap the test to a reasonable range.
  test('inserting a modestly-large AABB is bounded in cells', () {
    final hash = SpatialHash(cellSize: 10);
    // ~100 x 100 = 10_000 cells worst case. Fine.
    hash.insert(1, const Rect.fromLTWH(0, 0, 1000, 1000));
    // We just want this to complete without OOM; assert cellCount is
    // in the expected order.
    expect(hash.cellCount, greaterThan(0));
    expect(hash.cellCount, lessThan(200 * 200));
  });

  // Ensures the `dart:math` import is exercised so the file is
  // straightforwardly analysable; also documents "wider" collider sizes.
  test('sanity: colliders larger than cellSize span multiple cells', () {
    final hash = SpatialHash(cellSize: 16);
    hash.insert(1, const Rect.fromLTWH(0, 0, 64, 64));
    // 64 / 16 = 4 → cells (0..4) × (0..4) = 25 cells max, but the last
    // row/col boundary may or may not tick over depending on floor.
    expect(hash.cellCount, greaterThanOrEqualTo(16));
    expect(hash.cellCount, lessThanOrEqualTo(25));
    // Silence unused import lint.
    expect(math.max(1, 2), 2);
  });
}
