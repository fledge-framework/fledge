import 'dart:ui';

/// Grid position component - stores discrete tile coordinates.
///
/// This is the logical position in the grid (0-9 for a 10x10 grid).
/// The rendering system converts this to pixel coordinates.
class GridPosition {
  int x;
  int y;

  GridPosition(this.x, this.y);

  @override
  String toString() => 'GridPosition($x, $y)';

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Marker component for the player entity.
class Player {
  const Player();
}

/// Marker component for collectible items.
class Collectible {
  /// Points awarded when collected.
  final int points;

  const Collectible([this.points = 10]);
}

/// Marker component for background tiles.
class Tile {
  const Tile();
}

/// Visual appearance component - the color to render.
class TileColor {
  Color color;

  TileColor(this.color);
}
