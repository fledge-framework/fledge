import 'dart:math' as math;

import 'collision_grid.dart';

/// Straightens a path by dropping the waypoints a walker could skip by
/// heading straight on, without leaving cheap ground for dear.
///
/// Coordinates are in grid cells as continuous values: cell (x, y) covers
/// `x <= px < x + 1`, so a cell's centre is (x + 0.5, y + 0.5). [points] are
/// the waypoints after [from] (as `Pathfinder` returns them, converted to
/// centres, plus any exact end point); the result is the subset kept, ending
/// with the last point.
///
/// A shortcut is taken only when every cell the straight line touches is
/// walkable (a line through a cell corner also needs both cells beside the
/// corner, unless [allowCornerCutting], as `Pathfinder` rules diagonal
/// steps) and the line costs no more than the stretch of path it
/// replaces (each sample weighed by [CollisionGrid.costAt]), give or take
/// [slack] (in cost-weighted cells; about one cell of cheap ground covers
/// sampling error). So a path cuts the corner of a road, but not across
/// the grass beside it. With every cost at 1.0 this is plain line-of-sight
/// smoothing.
///
/// [sampleStep] is the spacing of the cost samples along a line, in cells.
List<(double, double)> smoothPath(
  CollisionGrid grid,
  (double, double) from,
  List<(double, double)> points, {
  double slack = 1.0,
  double sampleStep = 0.25,
  bool allowCornerCutting = false,
}) {
  if (points.isEmpty) return [];

  // The cost of walking straight from a to b; stops once past [budget].
  double lineCost(
    (double, double) a,
    (double, double) b, {
    double budget = double.infinity,
  }) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final length = math.sqrt(dx * dx + dy * dy);
    final steps = math.max(1, (length / sampleStep).ceil());
    final per = length / steps;
    var total = 0.0;
    for (var s = 1; s <= steps; s++) {
      final t = s / steps;
      total +=
          per * grid.costAt((a.$1 + dx * t).floor(), (a.$2 + dy * t).floor());
      if (total > budget) return total;
    }
    return total;
  }

  // Every cell the segment from a to b touches, walked in order (a
  // supercover traversal), must be walkable. Where the segment passes
  // exactly through a cell corner it touches all four cells there, so
  // unless [allowCornerCutting] both side cells must be walkable too, as
  // `Pathfinder` asks of a diagonal step: no squeezing through a
  // zero-width diagonal gap, no clipping a wall's corner.
  bool clear((double, double) a, (double, double) b) {
    var x = a.$1.floor(), y = a.$2.floor();
    if (!grid.isWalkable(x, y)) return false;
    final endX = b.$1.floor(), endY = b.$2.floor();
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final stepX = dx > 0 ? 1 : (dx < 0 ? -1 : 0);
    final stepY = dy > 0 ? 1 : (dy < 0 ? -1 : 0);
    // How far along the segment (0..1) each next grid line is crossed.
    final deltaX = stepX == 0 ? double.infinity : 1 / dx.abs();
    final deltaY = stepY == 0 ? double.infinity : 1 / dy.abs();
    var nextX = stepX > 0
        ? (x + 1 - a.$1) / dx
        : stepX < 0
        ? (a.$1 - x) / -dx
        : double.infinity;
    var nextY = stepY > 0
        ? (y + 1 - a.$2) / dy
        : stepY < 0
        ? (a.$2 - y) / -dy
        : double.infinity;
    const epsilon = 1e-9;
    // At most one step per grid line crossed (bounds float drift).
    var steps = (endX - x).abs() + (endY - y).abs();
    while ((x != endX || y != endY) && steps-- > 0) {
      if ((nextX - nextY).abs() < epsilon) {
        if (!allowCornerCutting &&
            (!grid.isWalkable(x + stepX, y) ||
                !grid.isWalkable(x, y + stepY))) {
          return false;
        }
        x += stepX;
        y += stepY;
        nextX += deltaX;
        nextY += deltaY;
        steps--;
      } else if (nextX < nextY) {
        x += stepX;
        nextX += deltaX;
      } else {
        y += stepY;
        nextY += deltaY;
      }
      if (!grid.isWalkable(x, y)) return false;
    }
    return true;
  }

  // The cost of walking the path as far as each point.
  final upTo = List<double>.filled(points.length, 0);
  var walked = 0.0;
  var previous = from;
  for (var k = 0; k < points.length; k++) {
    walked += lineCost(previous, points[k]);
    upTo[k] = walked;
    previous = points[k];
  }

  final kept = <(double, double)>[];
  var anchor = from;
  var spent = 0.0;
  var i = 0;
  while (i < points.length) {
    var j = points.length - 1;
    while (j > i) {
      final budget = upTo[j] - spent + slack;
      if (lineCost(anchor, points[j], budget: budget) <= budget &&
          clear(anchor, points[j])) {
        break;
      }
      j--;
    }
    kept.add(points[j]);
    anchor = points[j];
    spent = upTo[j];
    i = j + 1;
  }
  return kept;
}
