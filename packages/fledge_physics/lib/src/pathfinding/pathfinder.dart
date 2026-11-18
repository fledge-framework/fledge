import 'dart:math' as math;
import 'dart:typed_data';

import 'collision_grid.dart';

/// An entry in the A* open list. Stale entries (a cheaper way to the same
/// cell was found after it was pushed) are skipped when popped.
class _OpenEntry {
  final int index;
  final double gCost;
  final double fCost;
  final double hCost;

  const _OpenEntry(this.index, this.gCost, this.fCost, this.hCost);

  /// Lower f first; on a tie, the one nearer the goal.
  bool before(_OpenEntry other) =>
      fCost < other.fCost || (fCost == other.fCost && hCost < other.hCost);
}

/// A binary min-heap of [_OpenEntry].
class _OpenHeap {
  final List<_OpenEntry> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;

  void push(_OpenEntry entry) {
    _items.add(entry);
    var i = _items.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!_items[i].before(_items[parent])) break;
      final t = _items[i];
      _items[i] = _items[parent];
      _items[parent] = t;
      i = parent;
    }
  }

  _OpenEntry pop() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var best = i;
        if (l < _items.length && _items[l].before(_items[best])) best = l;
        if (r < _items.length && _items[r].before(_items[best])) best = r;
        if (best == i) break;
        final t = _items[i];
        _items[i] = _items[best];
        _items[best] = t;
        i = best;
      }
    }
    return top;
  }
}

/// Result of a pathfinding operation.
///
/// Contains either a successful path or information about why pathfinding failed.
class PathResult {
  /// The path as a list of tile coordinates, or null if no path found.
  ///
  /// The path excludes the starting position and includes the goal.
  /// An empty list means start equals goal.
  final List<(int, int)>? path;

  /// Whether a path was found.
  final bool success;

  /// Reason for failure (if not successful).
  final String? failureReason;

  /// Number of nodes explored during pathfinding.
  final int nodesExplored;

  const PathResult.success(this.path, {this.nodesExplored = 0})
    : success = true,
      failureReason = null;

  const PathResult.failure(this.failureReason, {this.nodesExplored = 0})
    : path = null,
      success = false;

  /// The length of the path in tiles, or -1 if no path.
  int get pathLength => path?.length ?? -1;
}

/// A* pathfinding for tile-based maps.
///
/// Finds the cheapest path between two points on a [CollisionGrid],
/// avoiding blocked tiles. A step costs its length (1 straight, about 1.414
/// diagonally) times the mean [CollisionGrid.costAt] of the two cells it
/// joins, so with every cost left at 1.0 the cheapest path is the shortest,
/// and with roads cheaper than open ground paths keep to the roads.
///
/// Example:
/// ```dart
/// final grid = CollisionGrid(width: 20, height: 20);
/// grid.setBlocked(5, 5);
/// grid.setBlocked(5, 6);
///
/// final pathfinder = Pathfinder();
/// final result = pathfinder.findPath(grid, 0, 0, 10, 10);
///
/// if (result.success) {
///   for (final (x, y) in result.path!) {
///     print('Move to ($x, $y)');
///   }
/// } else {
///   print('No path: ${result.failureReason}');
/// }
/// ```
class Pathfinder {
  /// Maximum number of nodes to explore before giving up.
  ///
  /// Prevents infinite loops on very large or complex maps.
  final int maxIterations;

  /// Whether to allow diagonal movement.
  final bool allowDiagonal;

  /// Whether diagonal movement can cut corners.
  ///
  /// If false, diagonal movement requires both adjacent cardinal
  /// directions to be walkable (prevents walking through wall corners).
  final bool allowCornerCutting;

  /// Cost for moving diagonally (sqrt(2) ≈ 1.414).
  static const double diagonalCost = 1.414;

  /// Creates a new pathfinder.
  ///
  /// Parameters:
  /// - [maxIterations]: Maximum nodes to explore (default: 10000)
  /// - [allowDiagonal]: Whether diagonal movement is allowed (default: true)
  /// - [allowCornerCutting]: Whether to allow cutting corners (default: false)
  const Pathfinder({
    this.maxIterations = 10000,
    this.allowDiagonal = true,
    this.allowCornerCutting = false,
  });

  /// Find a path from start to goal on the given grid.
  ///
  /// Returns a [PathResult] containing the path as a list of tile coordinates
  /// (excluding start, including goal), or failure information.
  ///
  /// The path uses A* algorithm with Manhattan or diagonal distance heuristic.
  PathResult findPath(
    CollisionGrid grid,
    int startX,
    int startY,
    int goalX,
    int goalY,
  ) {
    // Check if start and goal are valid
    if (!grid.isWalkable(startX, startY)) {
      return const PathResult.failure('Start position is not walkable');
    }
    if (!grid.isWalkable(goalX, goalY)) {
      return const PathResult.failure('Goal position is not walkable');
    }

    // If start equals goal, return empty path
    if (startX == goalX && startY == goalY) {
      return const PathResult.success([]);
    }

    return _astar(grid, startX, startY, goalX, goalY);
  }

  /// Check if a path exists without returning the full path.
  ///
  /// More efficient than [findPath] when you only need to know if
  /// a path is possible.
  bool hasPath(
    CollisionGrid grid,
    int startX,
    int startY,
    int goalX,
    int goalY,
  ) {
    return findPath(grid, startX, startY, goalX, goalY).success;
  }

  /// A* algorithm implementation.
  PathResult _astar(
    CollisionGrid grid,
    int startX,
    int startY,
    int goalX,
    int goalY,
  ) {
    final width = grid.width;
    final cells = width * grid.height;
    // Best known cost to each cell, the cell it was reached from, and
    // whether it's been expanded: whole-grid arrays kept between searches
    // (a town-sized grid is 50,000 cells), valid for a cell only where its
    // stamp is this search's ([_Scratch]).
    final scratch = _Scratch.forCells(cells);
    final stamp = scratch.begin();
    final stamps = scratch.stamps;
    final gCosts = scratch.gCosts;
    final parents = scratch.parents;
    final closed = scratch.closed;
    double gCostOf(int i) => stamps[i] == stamp ? gCosts[i] : double.infinity;
    void touch(int i) {
      if (stamps[i] != stamp) {
        stamps[i] = stamp;
        gCosts[i] = double.infinity;
        parents[i] = -1;
        closed[i] = 0;
      }
    }

    // Never overestimates: every step ahead costs at least the cheapest cell.
    final hScale = grid.minCost;
    final neighbors = _getNeighbors();
    final open = _OpenHeap();

    final startIndex = startY * width + startX;
    final goalIndex = goalY * width + goalX;
    touch(startIndex);
    gCosts[startIndex] = 0;
    final startH = _heuristic(startX, startY, goalX, goalY) * hScale;
    open.push(_OpenEntry(startIndex, 0, startH, startH));

    var iterations = 0;

    while (open.isNotEmpty && iterations < maxIterations) {
      final current = open.pop();
      final index = current.index;
      if ((stamps[index] == stamp && closed[index] == 1) ||
          current.gCost > gCostOf(index)) {
        continue;
      }
      closed[index] = 1;
      iterations++;

      if (index == goalIndex) {
        return PathResult.success(
          _reconstructPath(parents, width, startIndex, goalIndex),
          nodesExplored: iterations,
        );
      }

      final cx = index % width;
      final cy = index ~/ width;
      final here = grid.costAt(cx, cy);
      for (final (dx, dy, length) in neighbors) {
        final nx = cx + dx;
        final ny = cy + dy;

        if (!grid.isWalkable(nx, ny)) continue;

        // For diagonal movement, check corner cutting
        if (!allowCornerCutting && dx != 0 && dy != 0) {
          if (!grid.isWalkable(cx + dx, cy) || !grid.isWalkable(cx, cy + dy)) {
            continue; // Can't cut corners
          }
        }

        final next = ny * width + nx;
        touch(next);
        if (closed[next] == 1) continue;
        final gCost = current.gCost + length * (here + grid.costAt(nx, ny)) / 2;
        if (gCost >= gCosts[next]) continue;
        gCosts[next] = gCost;
        parents[next] = index;
        final hCost = _heuristic(nx, ny, goalX, goalY) * hScale;
        open.push(_OpenEntry(next, gCost, gCost + hCost, hCost));
      }
    }

    // No path found
    if (iterations >= maxIterations) {
      return PathResult.failure(
        'Pathfinding exceeded maximum iterations ($maxIterations)',
        nodesExplored: iterations,
      );
    }
    return PathResult.failure('No path exists', nodesExplored: iterations);
  }

  /// Get neighbor offsets and costs.
  List<(int, int, double)> _getNeighbors() {
    final neighbors = <(int, int, double)>[
      // Cardinal directions
      (0, -1, 1.0), // Up
      (0, 1, 1.0), // Down
      (-1, 0, 1.0), // Left
      (1, 0, 1.0), // Right
    ];

    if (allowDiagonal) {
      neighbors.addAll([
        (-1, -1, diagonalCost), // Up-Left
        (1, -1, diagonalCost), // Up-Right
        (-1, 1, diagonalCost), // Down-Left
        (1, 1, diagonalCost), // Down-Right
      ]);
    }

    return neighbors;
  }

  /// Heuristic function for A*.
  ///
  /// Uses diagonal distance when diagonal movement is allowed,
  /// Manhattan distance otherwise.
  double _heuristic(int x1, int y1, int x2, int y2) {
    final dx = (x1 - x2).abs();
    final dy = (y1 - y2).abs();

    if (allowDiagonal) {
      // Diagonal distance (Chebyshev with proper diagonal cost)
      return math.max(dx, dy) + (diagonalCost - 1) * math.min(dx, dy);
    } else {
      // Manhattan distance
      return (dx + dy).toDouble();
    }
  }

  /// Reconstruct path from goal back to start (excluding start).
  List<(int, int)> _reconstructPath(
    Int32List parents,
    int width,
    int startIndex,
    int goalIndex,
  ) {
    final path = <(int, int)>[];
    var index = goalIndex;
    while (index != startIndex) {
      path.add((index % width, index ~/ width));
      index = parents[index];
    }
    return path.reversed.toList();
  }
}

/// A search's whole-grid working arrays, kept for the next search of a grid
/// that size (one isolate runs one search at a time). A cell's entries hold
/// for a search only where its stamp is that search's; others read as
/// unvisited, so nothing is cleared between searches.
class _Scratch {
  _Scratch(int cells)
    : stamps = Int32List(cells),
      gCosts = Float64List(cells),
      parents = Int32List(cells),
      closed = Uint8List(cells);

  static _Scratch? _last;

  static _Scratch forCells(int cells) {
    final last = _last;
    if (last != null && last.stamps.length >= cells) return last;
    return _last = _Scratch(cells);
  }

  final Int32List stamps;
  final Float64List gCosts;
  final Int32List parents;
  final Uint8List closed;
  int _stamp = 0;

  /// Starts a search: its stamp.
  int begin() {
    if (++_stamp == 0x7fffffff) {
      stamps.fillRange(0, stamps.length, 0);
      _stamp = 1;
    }
    return _stamp;
  }
}
