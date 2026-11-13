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
/// A shortcut is taken only when every sample along the straight line is on
/// a walkable cell and the line costs no more than the stretch of path it
/// replaces (each sample weighed by [CollisionGrid.costAt]), give or take
/// [slack] (in cost-weighted cells; about one cell of cheap ground covers
/// sampling error). So a path cuts the corner of a road, but not across
/// the grass beside it. With every cost at 1.0 this is plain line-of-sight
/// smoothing.
///
/// [sampleStep] is the spacing of samples along a line, in cells.
List<(double, double)> smoothPath(
  CollisionGrid grid,
  (double, double) from,
  List<(double, double)> points, {
  double slack = 1.0,
  double sampleStep = 0.25,
}) {
  if (points.isEmpty) return [];

  bool walkable((double, double) p) =>
      grid.isWalkable(p.$1.floor(), p.$2.floor());

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

  bool clear((double, double) a, (double, double) b) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final steps = math.max(
      1,
      (math.sqrt(dx * dx + dy * dy) / sampleStep).ceil(),
    );
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      if (!walkable((a.$1 + dx * t, a.$2 + dy * t))) return false;
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
