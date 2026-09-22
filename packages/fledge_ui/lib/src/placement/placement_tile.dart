/// A tile on a map, as the placement core sees it: [mapKey] is an opaque
/// map id supplied by the game, [x] / [y] the tile coordinates on that map.
///
/// Value type: two tiles are equal when their map and coordinates are.
class PlacementTile {
  final String mapKey;
  final int x;
  final int y;

  const PlacementTile(this.mapKey, this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is PlacementTile &&
      other.mapKey == mapKey &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(mapKey, x, y);

  @override
  String toString() => 'PlacementTile($mapKey, $x, $y)';
}
