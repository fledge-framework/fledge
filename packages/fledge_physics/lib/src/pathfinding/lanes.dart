import 'dart:math' as math;

import 'collision_grid.dart';

/// How far each walkable cell of a [CollisionGrid] is from the edge of the
/// ground it's on, in cells: the distance from its centre to the nearest
/// cell that's blocked or dearer to walk ([CollisionGrid.costAt]). On a road
/// five cells wide, the middle cell is 3 from the edge and the cells along
/// its sides 1. Out of bounds counts as an edge.
///
/// Distances are 8-way chamfer distances (1 straight, √2 diagonal), close
/// to true distance and exact along straight roads. Computed once; rebuild
/// it if the grid's walls or costs change.
///
/// With `wallsAreEdges: false`, only changes of ground count: a blocked
/// cell is measured through as the ground under it (its cost), so the
/// benches and lamp posts on a square don't make paths weave between them.
/// The map's bounds are still an edge.
class EdgeDistance {
  EdgeDistance._(this.width, this.height, this._distance);

  /// Measures [grid] as it is now.
  factory EdgeDistance.of(CollisionGrid grid, {bool wallsAreEdges = true}) {
    final w = grid.width, h = grid.height;
    const far = 1e9;
    final d = List<double>.filled(w * h, far);
    bool open(int x, int y) => !wallsAreEdges || grid.isWalkable(x, y);
    bool edgeOf(int x, int y, double cost) {
      if (x < 0 || y < 0 || x >= w || y >= h) return true;
      return !open(x, y) || grid.costAt(x, y) > cost + 1e-9;
    }

    // Seeds: walkable cells beside an edge are 1 from it; edges are 0.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!open(x, y)) {
          d[y * w + x] = 0;
          continue;
        }
        final cost = grid.costAt(x, y);
        for (final (dx, dy) in _neighbours) {
          if (edgeOf(x + dx, y + dy, cost)) {
            final step = dx != 0 && dy != 0 ? math.sqrt2 : 1.0;
            d[y * w + x] = math.min(d[y * w + x], step);
          }
        }
      }
    }
    // Two chamfer passes. A cell only takes distance through neighbours of
    // the same or cheaper ground, so a road's distances stop at its edge.
    void relax(int x, int y, int nx, int ny, double step) {
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) return;
      if (!open(nx, ny)) return;
      if (grid.costAt(nx, ny) > grid.costAt(x, y) + 1e-9) return;
      final through = d[ny * w + nx] + step;
      if (through < d[y * w + x]) d[y * w + x] = through;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!open(x, y)) continue;
        relax(x, y, x - 1, y, 1);
        relax(x, y, x, y - 1, 1);
        relax(x, y, x - 1, y - 1, math.sqrt2);
        relax(x, y, x + 1, y - 1, math.sqrt2);
      }
    }
    for (var y = h - 1; y >= 0; y--) {
      for (var x = w - 1; x >= 0; x--) {
        if (!open(x, y)) continue;
        relax(x, y, x + 1, y, 1);
        relax(x, y, x, y + 1, 1);
        relax(x, y, x + 1, y + 1, math.sqrt2);
        relax(x, y, x - 1, y + 1, math.sqrt2);
      }
    }
    return EdgeDistance._(w, h, d);
  }

  static const _neighbours = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, 1),
    (-1, 1),
    (1, -1),
    (-1, -1),
  ];

  final int width;
  final int height;
  final List<double> _distance;

  /// Cells from (x, y)'s centre to the nearest edge; 0 out of bounds, and
  /// for blocked cells when walls are edges.
  double at(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    return _distance[y * width + x];
  }
}

/// Makes the middle of every stretch of ground cheaper to walk than its
/// sides, so a `Pathfinder` follows the centre of a road instead of
/// hugging the inside of every bend. A cell [edges] puts 1 from the edge
/// costs [edgeCost] more, easing to nothing at [reach] cells in; the
/// centre's cost is unchanged.
///
/// Use with [keepToSide], which then puts walkers in lanes either side of
/// that centre.
void preferCentres(
  CollisionGrid grid,
  EdgeDistance edges, {
  double edgeCost = 0.5,
  double reach = 3,
}) {
  final base = <double>[];
  for (var y = 0; y < grid.height; y++) {
    for (var x = 0; x < grid.width; x++) {
      base.add(grid.costAt(x, y));
    }
  }
  for (var y = 0; y < grid.height; y++) {
    for (var x = 0; x < grid.width; x++) {
      if (!grid.isWalkable(x, y)) continue;
      final inside = (reach - edges.at(x, y)) / (reach - 1);
      if (inside <= 0) continue;
      final cost = base[y * grid.width + x];
      grid.setCost(x, y, cost + edgeCost * inside.clamp(0.0, 1.0));
    }
  }
}

/// Whether a walker fits with their feet exactly at ([x], [y]), in grid
/// cells as continuous values (a cell's centre is (x + 0.5, y + 0.5)).
///
/// A [CollisionGrid] knows only whole cells, typically judged at their
/// centres, so a point moved off a centre (a lane, a straightened run) can
/// clip a wall in a gap barely wider than the walker. Given the game's own
/// geometry, [keepToSide] and [simplifyPath] check every such point.
typedef PathFits = bool Function(double x, double y);

/// Which side of a path walkers keep to.
enum Side { left, right }

/// Moves a path's waypoints to one [side] of the way, like traffic: each is
/// shifted at right angles to the direction of travel by [share] of the
/// distance to the ground's edge there ([edges]), at most [maxOffset]
/// cells. So two walkers going opposite ways along a road keep to opposite
/// halves of it, on a wide road by a lot and on a narrow footpath by a
/// little.
///
/// [points] are in grid cells as continuous values (a cell's centre is
/// (x + 0.5, y + 0.5)), as for `smoothPath`, typically a `Pathfinder` path
/// over a grid shaped by [preferCentres]. The direction of travel is taken
/// over [window] points either side, so a staircase of diagonal steps
/// reads as one direction. The shift eases in over the first [taper]
/// points and out over the last, so the path still starts and ends where
/// it did. A shifted point that would leave walkable ground, or land on
/// dearer ground, or where the walker wouldn't [fits], is shifted less.
List<(double, double)> keepToSide(
  CollisionGrid grid,
  EdgeDistance edges,
  List<(double, double)> points, {
  Side side = Side.right,
  double share = 0.5,
  double maxOffset = 1.5,
  int window = 2,
  int taper = 2,
  PathFits? fits,
}) {
  final n = points.length;
  if (n < 2) return [...points];
  final sign = side == Side.right ? 1.0 : -1.0;
  final result = <(double, double)>[];
  for (var i = 0; i < n; i++) {
    final a = points[math.max(0, i - window)];
    final b = points[math.min(n - 1, i + window)];
    var dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final length = math.sqrt(dx * dx + dy * dy);
    final p = points[i];
    if (length == 0) {
      result.add(p);
      continue;
    }
    dx /= length;
    dy /= length;
    // With y pointing down, (-dy, dx) is to the right of travel.
    final nx = -dy * sign, ny = dx * sign;
    final cx = p.$1.floor(), cy = p.$2.floor();
    final half = math.max(0.0, edges.at(cx, cy) - 0.5);
    final ease = math.min(1.0, math.min(i, n - 1 - i) / math.max(1, taper));
    var offset = math.min(maxOffset, half * share) * ease;
    final cost = grid.costAt(cx, cy);
    while (offset > 0.05) {
      final q = (p.$1 + nx * offset, p.$2 + ny * offset);
      final qx = q.$1.floor(), qy = q.$2.floor();
      if (grid.isWalkable(qx, qy) &&
          grid.costAt(qx, qy) <= cost + 0.75 &&
          (fits == null || fits(q.$1, q.$2))) {
        break;
      }
      offset /= 2;
    }
    result.add(offset > 0.05 ? (p.$1 + nx * offset, p.$2 + ny * offset) : p);
  }
  return result;
}

/// Drops the waypoints of a path that lie close to the straight line
/// between their neighbours (Ramer-Douglas-Peucker), so a run of grid
/// steps becomes one straight walk while every bend stays where it is: a
/// simplified path is never more than [tolerance] cells from the original.
/// Unlike `smoothPath`, it never cuts a corner. A straight line that would
/// cross unwalkable ground, or pass anywhere the walker wouldn't [fits]
/// (checked every [sampleStep] cells), is split at its furthest point
/// regardless.
///
/// Coordinates as for `smoothPath`; the first and last points are kept.
List<(double, double)> simplifyPath(
  CollisionGrid grid,
  List<(double, double)> points, {
  double tolerance = 0.5,
  double sampleStep = 0.25,
  PathFits? fits,
}) {
  if (points.length < 3) return [...points];
  bool clear((double, double) a, (double, double) b) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final steps = math.max(
      1,
      (math.sqrt(dx * dx + dy * dy) / sampleStep).ceil(),
    );
    for (var s = 0; s <= steps; s++) {
      final t = s / steps;
      final x = a.$1 + dx * t, y = a.$2 + dy * t;
      if (!grid.isWalkable(x.floor(), y.floor())) return false;
      if (fits != null && !fits(x, y)) return false;
    }
    return true;
  }

  double offLine((double, double) p, (double, double) a, (double, double) b) {
    final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) {
      return math.sqrt(math.pow(p.$1 - a.$1, 2) + math.pow(p.$2 - a.$2, 2));
    }
    return ((p.$1 - a.$1) * dy - (p.$2 - a.$2) * dx).abs() / length;
  }

  final keep = List<bool>.filled(points.length, false)
    ..[0] = true
    ..[points.length - 1] = true;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (first, last) = stack.removeLast();
    if (last - first < 2) continue;
    var furthest = first + 1;
    var distance = -1.0;
    for (var k = first + 1; k < last; k++) {
      final d = offLine(points[k], points[first], points[last]);
      if (d > distance) {
        distance = d;
        furthest = k;
      }
    }
    if (distance > tolerance || !clear(points[first], points[last])) {
      keep[furthest] = true;
      stack
        ..add((first, furthest))
        ..add((furthest, last));
    }
  }
  return [
    for (var k = 0; k < points.length; k++)
      if (keep[k]) points[k],
  ];
}
