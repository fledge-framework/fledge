import 'dart:collection';
import 'dart:math' as math;

import 'collision_grid.dart';

/// A node in the A* pathfinding algorithm.
class _PathNode implements Comparable<_PathNode> {
  final int x;
  final int y;
  final double gCost; // Cost from start to this node
  final double hCost; // Heuristic cost to goal
  final _PathNode? parent;

  _PathNode({
    required this.x,
    required this.y,
    required this.gCost,
    required this.hCost,
    this.parent,
  });

  /// Total cost (f = g + h).
  double get fCost => gCost + hCost;

  @override
  int compareTo(_PathNode other) {
    final fCompare = fCost.compareTo(other.fCost);
    if (fCompare != 0) return fCompare;
    // Prefer lower h-cost when f-costs are equal
    return hCost.compareTo(other.hCost);
  }

  @override
  bool operator ==(Object other) =>
      other is _PathNode && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ (y.hashCode << 16);
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
/// Finds the shortest path between two points on a [CollisionGrid],
/// avoiding blocked tiles.
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
    // Priority queue for open set (nodes to explore)
    final openSet = SplayTreeSet<_PathNode>();

    // Track best g-cost to each position
    final gCosts = <(int, int), double>{};

    // Track which nodes are in open set
    final inOpenSet = <(int, int)>{};

    // Start node
    final startNode = _PathNode(
      x: startX,
      y: startY,
      gCost: 0,
      hCost: _heuristic(startX, startY, goalX, goalY),
    );
    openSet.add(startNode);
    gCosts[(startX, startY)] = 0;
    inOpenSet.add((startX, startY));

    var iterations = 0;

    while (openSet.isNotEmpty && iterations < maxIterations) {
      iterations++;

      // Get node with lowest f-cost
      final current = openSet.first;
      openSet.remove(current);
      inOpenSet.remove((current.x, current.y));

      // Check if we reached the goal
      if (current.x == goalX && current.y == goalY) {
        return PathResult.success(
          _reconstructPath(current),
          nodesExplored: iterations,
        );
      }

      // Explore neighbors
      for (final (dx, dy, cost) in _getNeighbors()) {
        final nx = current.x + dx;
        final ny = current.y + dy;

        // Skip if not walkable
        if (!grid.isWalkable(nx, ny)) continue;

        // For diagonal movement, check corner cutting
        if (!allowCornerCutting && dx != 0 && dy != 0) {
          if (!grid.isWalkable(current.x + dx, current.y) ||
              !grid.isWalkable(current.x, current.y + dy)) {
            continue; // Can't cut corners
          }
        }

        final newGCost = current.gCost + cost;
        final existingGCost = gCosts[(nx, ny)];

        // Skip if we've found a better path to this node
        if (existingGCost != null && newGCost >= existingGCost) {
          continue;
        }

        // This is a better path
        gCosts[(nx, ny)] = newGCost;

        final neighbor = _PathNode(
          x: nx,
          y: ny,
          gCost: newGCost,
          hCost: _heuristic(nx, ny, goalX, goalY),
          parent: current,
        );

        // Remove old version if in open set
        if (inOpenSet.contains((nx, ny))) {
          openSet.removeWhere((n) => n.x == nx && n.y == ny);
        }

        openSet.add(neighbor);
        inOpenSet.add((nx, ny));
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

  /// Reconstruct path from goal node back to start.
  List<(int, int)> _reconstructPath(_PathNode goalNode) {
    final path = <(int, int)>[];
    _PathNode? current = goalNode;

    while (current != null) {
      path.add((current.x, current.y));
      current = current.parent;
    }

    // Reverse to get start-to-goal order, exclude start position
    path.removeLast(); // Remove start position
    return path.reversed.toList();
  }
}
