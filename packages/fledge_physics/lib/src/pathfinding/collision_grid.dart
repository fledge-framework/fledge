/// A 2D grid representing walkability for pathfinding.
///
/// Each cell is either walkable (true) or blocked (false).
/// Used by [Pathfinder] for A* pathfinding on tile-based maps.
///
/// Example:
/// ```dart
/// final grid = CollisionGrid(width: 10, height: 10);
///
/// // Block some tiles
/// grid.setBlocked(5, 5);
/// grid.setBlocked(5, 6);
///
/// // Check walkability
/// if (grid.isWalkable(3, 3)) {
///   print('Tile is walkable');
/// }
/// ```
class CollisionGrid {
  /// Width of the grid in tiles.
  final int width;

  /// Height of the grid in tiles.
  final int height;

  /// Internal grid storage. True = walkable, False = blocked.
  final List<List<bool>> _grid;

  /// Creates a new collision grid with all tiles initially walkable.
  CollisionGrid({
    required this.width,
    required this.height,
  }) : _grid = List.generate(
          height,
          (_) => List.filled(width, true),
        );

  /// Creates a collision grid from existing data.
  ///
  /// The [data] should be a 2D list where `data[y][x]` is true if walkable.
  CollisionGrid.fromData(List<List<bool>> data)
      : width = data.isNotEmpty ? data[0].length : 0,
        height = data.length,
        _grid = data;

  /// Check if a tile is walkable.
  ///
  /// Returns false for out-of-bounds coordinates.
  bool isWalkable(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return false;
    }
    return _grid[y][x];
  }

  /// Check if a tile is blocked (not walkable).
  ///
  /// Returns true for out-of-bounds coordinates.
  bool isBlocked(int x, int y) => !isWalkable(x, y);

  /// Mark a tile as blocked (not walkable).
  void setBlocked(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _grid[y][x] = false;
    }
  }

  /// Mark a tile as walkable.
  void setWalkable(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _grid[y][x] = true;
    }
  }

  /// Set the walkability of a tile directly.
  void set(int x, int y, bool walkable) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _grid[y][x] = walkable;
    }
  }

  /// Mark a rectangular region as blocked.
  void setRegionBlocked(int x, int y, int regionWidth, int regionHeight) {
    for (var dy = 0; dy < regionHeight; dy++) {
      for (var dx = 0; dx < regionWidth; dx++) {
        setBlocked(x + dx, y + dy);
      }
    }
  }

  /// Mark a rectangular region as walkable.
  void setRegionWalkable(int x, int y, int regionWidth, int regionHeight) {
    for (var dy = 0; dy < regionHeight; dy++) {
      for (var dx = 0; dx < regionWidth; dx++) {
        setWalkable(x + dx, y + dy);
      }
    }
  }

  /// Clear the grid, making all tiles walkable.
  void clear() {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        _grid[y][x] = true;
      }
    }
  }

  /// Fill the grid, making all tiles blocked.
  void fill() {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        _grid[y][x] = false;
      }
    }
  }

  /// Count the number of walkable tiles.
  int get walkableCount {
    var count = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_grid[y][x]) count++;
      }
    }
    return count;
  }

  /// Count the number of blocked tiles.
  int get blockedCount => width * height - walkableCount;

  /// Create a copy of this grid.
  CollisionGrid copy() {
    final newGrid = List.generate(
      height,
      (y) => List<bool>.from(_grid[y]),
    );
    return CollisionGrid.fromData(newGrid);
  }
}
