import 'package:fledge_physics/fledge_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Total cost of [path] from [start], as the pathfinder weighs it.
double costOf(CollisionGrid grid, (int, int) start, List<(int, int)> path) {
  var total = 0.0;
  var (x, y) = start;
  for (final (nx, ny) in path) {
    final length = (nx != x && ny != y) ? Pathfinder.diagonalCost : 1.0;
    total += length * (grid.costAt(x, y) + grid.costAt(nx, ny)) / 2;
    (x, y) = (nx, ny);
  }
  return total;
}

void main() {
  group('Pathfinder', () {
    test('finds the shortest path on an open grid', () {
      final grid = CollisionGrid(width: 10, height: 10);
      final result = const Pathfinder().findPath(grid, 0, 0, 9, 0);
      expect(result.success, isTrue);
      expect(result.path, hasLength(9));
      expect(result.path!.last, (9, 0));
    });

    test('goes around walls', () {
      final grid = CollisionGrid(width: 10, height: 10);
      for (var y = 0; y < 9; y++) {
        grid.setBlocked(5, y);
      }
      final result = const Pathfinder().findPath(grid, 0, 0, 9, 0);
      expect(result.success, isTrue);
      expect(result.path, contains((5, 9)));
      for (final (x, y) in result.path!) {
        expect(grid.isWalkable(x, y), isTrue);
      }
    });

    test('reports no path when walled off', () {
      final grid = CollisionGrid(width: 10, height: 10);
      for (var y = 0; y < 10; y++) {
        grid.setBlocked(5, y);
      }
      final result = const Pathfinder().findPath(grid, 0, 0, 9, 0);
      expect(result.success, isFalse);
      expect(result.path, isNull);
    });

    test('start equal to goal is an empty path', () {
      final grid = CollisionGrid(width: 3, height: 3);
      expect(const Pathfinder().findPath(grid, 1, 1, 1, 1).path, isEmpty);
    });

    test('keeps to cheap cells when the detour is worth it', () {
      // Open ground costs 4; a road runs along the bottom row and up the
      // right edge. Straight across is 9 steps at 4 = 36; the road is 18
      // steps at 1.
      final grid = CollisionGrid(width: 10, height: 10);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          final road = y == 9 || x == 9 || x == 0;
          grid.setCost(x, y, road ? 1 : 4);
        }
      }
      final result = const Pathfinder().findPath(grid, 0, 0, 9, 0);
      expect(result.success, isTrue);
      for (final (x, y) in result.path!) {
        expect(grid.costAt(x, y), 1, reason: 'left the road at ($x, $y)');
      }
    });

    test('cuts across when the road is too long a way round', () {
      final grid = CollisionGrid(width: 10, height: 10);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          final road = y == 9 || x == 9 || x == 0;
          grid.setCost(x, y, road ? 1 : 1.5);
        }
      }
      final result = const Pathfinder().findPath(grid, 0, 0, 9, 0);
      expect(result.path, hasLength(9)); // straight along the top
    });

    test('finds the cheapest path, not just a cheap one', () {
      // A field of varied costs: the result must cost no more than any
      // alternative, checked against a Dijkstra-style relaxation.
      final grid = CollisionGrid(width: 12, height: 12);
      for (var y = 0; y < 12; y++) {
        for (var x = 0; x < 12; x++) {
          grid.setCost(x, y, 1 + ((x * 7 + y * 13) % 5).toDouble());
        }
      }
      for (var y = 2; y < 10; y++) {
        grid.setBlocked(6, y);
      }
      const pathfinder = Pathfinder();
      final result = pathfinder.findPath(grid, 0, 0, 11, 11);
      expect(result.success, isTrue);
      final found = costOf(grid, (0, 0), result.path!);

      // Bellman-Ford over the same moves.
      final best = List.generate(12, (_) => List.filled(12, double.infinity));
      best[0][0] = 0;
      for (var round = 0; round < 144; round++) {
        var changed = false;
        for (var y = 0; y < 12; y++) {
          for (var x = 0; x < 12; x++) {
            if (best[y][x] == double.infinity) continue;
            for (var dy = -1; dy <= 1; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                final nx = x + dx, ny = y + dy;
                if (!grid.isWalkable(nx, ny)) continue;
                if (dx != 0 &&
                    dy != 0 &&
                    (!grid.isWalkable(x + dx, y) ||
                        !grid.isWalkable(x, y + dy))) {
                  continue;
                }
                final length = dx != 0 && dy != 0
                    ? Pathfinder.diagonalCost
                    : 1.0;
                final cost =
                    best[y][x] +
                    length * (grid.costAt(x, y) + grid.costAt(nx, ny)) / 2;
                if (cost < best[ny][nx] - 1e-9) {
                  best[ny][nx] = cost;
                  changed = true;
                }
              }
            }
          }
        }
        if (!changed) break;
      }
      expect(found, closeTo(best[11][11], 1e-9));
    });

    test('ties between equally good nodes do not lose any', () {
      // A symmetric maze where many open nodes share f and h; every one
      // must stay in the open list for the only gap to be found.
      final grid = CollisionGrid(width: 21, height: 21);
      for (var x = 0; x < 21; x++) {
        if (x != 0) grid.setBlocked(x, 10);
      }
      final result = const Pathfinder().findPath(grid, 10, 0, 10, 20);
      expect(result.success, isTrue);
      expect(result.path, contains((0, 10)));
    });
  });

  group('CollisionGrid costs', () {
    test('default to 1 and track the minimum', () {
      final grid = CollisionGrid(width: 4, height: 4);
      expect(grid.costAt(2, 2), 1);
      expect(grid.minCost, 1);
      grid.setCost(1, 1, 3);
      grid.setCost(2, 1, 0.5);
      expect(grid.costAt(1, 1), 3);
      expect(grid.minCost, 0.5);
      expect(grid.copy().costAt(1, 1), 3);
    });

    test('reject non-positive costs', () {
      final grid = CollisionGrid(width: 2, height: 2);
      expect(() => grid.setCost(0, 0, 0), throwsArgumentError);
      expect(() => grid.setCost(0, 0, -1), throwsArgumentError);
    });
  });
}
