import 'package:fledge_physics/fledge_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cell centres of a [Pathfinder] result.
List<(double, double)> centres(List<(int, int)> cells) => [
  for (final (x, y) in cells) (x + 0.5, y + 0.5),
];

void main() {
  test('with uniform costs, keeps only the corners it needs', () {
    final grid = CollisionGrid(width: 10, height: 10);
    final path = const Pathfinder().findPath(grid, 0, 0, 9, 9).path!;
    final smooth = smoothPath(grid, (0.5, 0.5), centres(path));
    expect(smooth, [(9.5, 9.5)]); // nothing in the way: straight there
  });

  test('keeps the waypoint that turns a wall corner', () {
    final grid = CollisionGrid(width: 10, height: 10);
    for (var y = 0; y < 9; y++) {
      grid.setBlocked(5, y);
    }
    final path = const Pathfinder().findPath(grid, 0, 0, 9, 0).path!;
    final smooth = smoothPath(grid, (0.5, 0.5), centres(path));
    expect(smooth.length, greaterThan(1));
    expect(smooth.last, (9.5, 0.5));
    // Every kept leg is walkable.
    var from = (0.5, 0.5);
    for (final to in smooth) {
      for (var s = 0; s <= 40; s++) {
        final t = s / 40;
        final x = from.$1 + (to.$1 - from.$1) * t;
        final y = from.$2 + (to.$2 - from.$2) * t;
        expect(grid.isWalkable(x.floor(), y.floor()), isTrue);
      }
      from = to;
    }
  });

  test('does not shortcut off cheap ground', () {
    // An L-shaped road (left column and bottom row) through dear ground.
    final grid = CollisionGrid(width: 10, height: 10);
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 10; x++) {
        grid.setCost(x, y, x == 0 || y == 9 ? 1 : 4);
      }
    }
    final path = const Pathfinder().findPath(grid, 0, 0, 9, 9).path!;
    final smooth = smoothPath(grid, (0.5, 0.5), centres(path));
    // Down the road and along it: no leg crosses the dear ground.
    expect(smooth.last, (9.5, 9.5));
    var from = (0.5, 0.5);
    for (final to in smooth) {
      for (var s = 0; s <= 40; s++) {
        final t = s / 40;
        final x = from.$1 + (to.$1 - from.$1) * t;
        final y = from.$2 + (to.$2 - from.$2) * t;
        expect(grid.costAt(x.floor(), y.floor()), 1, reason: 'at ($x, $y)');
      }
      from = to;
    }
  });

  test('an empty path stays empty', () {
    expect(smoothPath(CollisionGrid(width: 2, height: 2), (0.5, 0.5), []), []);
  });
}
