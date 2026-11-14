import 'package:fledge_physics/fledge_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Open dust (cost 3) with roads (cost 1) carved into it.
CollisionGrid dusty(int width, int height) {
  final grid = CollisionGrid(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      grid.setCost(x, y, 3);
    }
  }
  return grid;
}

void road(CollisionGrid grid, int x0, int y0, int x1, int y1) {
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      grid.setCost(x, y, 1);
    }
  }
}

/// Plans a way like a game would: centre-preferring A*, kept right, then
/// simplified.
List<(double, double)> walk(
  CollisionGrid grid,
  EdgeDistance edges,
  (int, int) from,
  (int, int) to,
) {
  final result = const Pathfinder().findPath(
    grid,
    from.$1,
    from.$2,
    to.$1,
    to.$2,
  );
  final cells = [from, ...result.path!];
  final centres = [for (final (x, y) in cells) (x + 0.5, y + 0.5)];
  return simplifyPath(grid, keepToSide(grid, edges, centres));
}

void main() {
  group('EdgeDistance', () {
    test('a road is deepest in its middle and stops at its edge', () {
      final grid = dusty(20, 9);
      road(grid, 0, 2, 19, 6); // five cells wide: rows 2..6
      final edges = EdgeDistance.of(grid);
      expect(edges.at(10, 2), 1);
      expect(edges.at(10, 3), 2);
      expect(edges.at(10, 4), 3);
      expect(edges.at(10, 6), 1);
      // The dust beside it is its own ground, measured to the map's edge.
      expect(edges.at(10, 0), 1);
    });

    test('or only the ground counts, measured through walls', () {
      final grid = dusty(20, 9);
      road(grid, 0, 2, 19, 6);
      grid.setBlocked(10, 4); // a lamp post in the middle of the road
      final edges = EdgeDistance.of(grid, wallsAreEdges: false);
      expect(edges.at(11, 4), 3);
      expect(edges.at(10, 4), 3);
      expect(edges.at(10, 2), 1);
    });

    test('walls are edges too, and blocked cells are 0', () {
      final grid = CollisionGrid(width: 9, height: 9)..setBlocked(4, 4);
      final edges = EdgeDistance.of(grid);
      expect(edges.at(4, 4), 0);
      expect(edges.at(5, 4), 1);
      expect(edges.at(5, 5), closeTo(1.414, 0.01));
    });
  });

  test('preferCentres makes a road dearer at its sides only', () {
    final grid = dusty(20, 9);
    road(grid, 0, 2, 19, 6);
    preferCentres(grid, EdgeDistance.of(grid));
    expect(grid.costAt(10, 4), 1);
    expect(grid.costAt(10, 2), 1.5);
    expect(grid.costAt(10, 3), closeTo(1.25, 1e-9));
    expect(grid.minCost, 1);
  });

  group('keeping to the right', () {
    late CollisionGrid grid;
    late EdgeDistance edges;

    setUp(() {
      grid = dusty(40, 11);
      road(grid, 0, 2, 39, 8); // seven wide, centre row 5
      edges = EdgeDistance.of(grid);
      preferCentres(grid, edges);
    });

    /// Where the walked line is across the road (y) at each x from 8 to 32:
    /// past the eased ends.
    List<double> lane(List<(double, double)> path) {
      final ys = <double>[];
      for (var x = 8.0; x <= 32; x += 1) {
        for (var i = 1; i < path.length; i++) {
          final a = path[i - 1], b = path[i];
          final lo = a.$1 < b.$1 ? a : b, hi = a.$1 < b.$1 ? b : a;
          if (x < lo.$1 || x > hi.$1 || hi.$1 == lo.$1) continue;
          ys.add(lo.$2 + (hi.$2 - lo.$2) * (x - lo.$1) / (hi.$1 - lo.$1));
          break;
        }
      }
      expect(ys, hasLength(25));
      return ys;
    }

    double meanY(List<(double, double)> path) {
      final ys = lane(path);
      return ys.reduce((a, b) => a + b) / ys.length;
    }

    test('walkers going opposite ways take opposite halves', () {
      final east = walk(grid, edges, (1, 5), (38, 5));
      final west = walk(grid, edges, (38, 5), (1, 5));
      // y points down: heading east, the right is south (more y).
      expect(meanY(east), greaterThan(6));
      expect(meanY(west), lessThan(5));
    });

    test('a straight road is walked straight, in its lane', () {
      final east = walk(grid, edges, (1, 5), (38, 5));
      for (final y in lane(east)) {
        expect(y, closeTo(meanY(east), 0.3));
      }
      // Simplified to a handful of points, not a step per cell.
      expect(east.length, lessThan(8));
    });

    test('the lane stays on the road', () {
      for (final path in [
        walk(grid, edges, (1, 5), (38, 5)),
        walk(grid, edges, (38, 5), (1, 5)),
      ]) {
        for (final p in path) {
          expect(grid.costAt(p.$1.floor(), p.$2.floor()), lessThan(3));
        }
      }
    });

    test('left-hand traffic is one argument away', () {
      final cells = [for (var x = 1; x < 39; x++) (x + 0.5, 5.5)];
      final left = keepToSide(grid, edges, cells, side: Side.left);
      expect(left[20].$2, lessThan(5.5));
    });
  });

  test('round a corner, the way follows the road, not a diagonal', () {
    // An L: east along the top, then south down the right.
    final grid = dusty(30, 30);
    road(grid, 0, 2, 26, 8);
    road(grid, 20, 2, 26, 29);
    final edges = EdgeDistance.of(grid);
    preferCentres(grid, edges);
    final path = walk(grid, edges, (1, 5), (23, 28));
    // Every leg stays on the road: sample along each.
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1], b = path[i];
      for (var s = 0; s <= 20; s++) {
        final t = s / 20;
        final x = a.$1 + (b.$1 - a.$1) * t, y = a.$2 + (b.$2 - a.$2) * t;
        expect(
          grid.costAt(x.floor(), y.floor()),
          lessThan(3),
          reason: 'leg $i at ($x, $y)',
        );
      }
    }
  });

  test('simplifyPath keeps bends and never cuts through a wall', () {
    final grid = CollisionGrid(width: 10, height: 10);
    for (var y = 0; y < 8; y++) {
      grid.setBlocked(5, y);
    }
    final points = [(1.5, 1.5), (1.5, 8.5), (8.5, 8.5), (8.5, 1.5)];
    final simple = simplifyPath(grid, points, tolerance: 100);
    expect(simple, points, reason: 'the straight line crosses the wall');
    final line = [for (var x = 0; x < 10; x++) (x + 0.5, 9.5)];
    expect(simplifyPath(grid, line), [line.first, line.last]);
  });

  group('fits', () {
    test('keepToSide shifts no further than a walker fits', () {
      final grid = dusty(20, 9);
      road(grid, 0, 2, 19, 6);
      final edges = EdgeDistance.of(grid, wallsAreEdges: false);
      final straight = [for (var x = 0; x < 20; x++) (x + 0.5, 4.5)];
      final free = keepToSide(grid, edges, straight);
      // Something the grid can't see narrows the road's right-hand side
      // (travelling east, right is +y): nothing below y = 4.8 fits.
      final narrowed = keepToSide(
        grid,
        edges,
        straight,
        fits: (x, y) => y <= 4.8,
      );
      expect(
        free.map((p) => p.$2).reduce((a, b) => a > b ? a : b),
        greaterThan(4.8),
      );
      for (final (_, y) in narrowed) {
        expect(y, lessThanOrEqualTo(4.8));
      }
    });

    test('simplifyPath keeps a bend where a straight run would not fit', () {
      final grid = CollisionGrid(width: 10, height: 10);
      final elbow = [
        for (var x = 0; x < 6; x++) (x + 0.5, 0.5),
        for (var y = 1; y < 6; y++) (5.5, y + 0.5),
      ];
      // On an open grid the elbow straightens into one diagonal walk...
      expect(simplifyPath(grid, elbow, tolerance: 5), hasLength(2));
      // ...unless the walker can't fit across the corner's inside.
      final kept = simplifyPath(
        grid,
        elbow,
        tolerance: 5,
        fits: (x, y) => !(x < 5 && y > 1),
      );
      expect(kept.length, greaterThan(2));
      expect(kept, contains((5.5, 0.5)));
    });
  });
}
