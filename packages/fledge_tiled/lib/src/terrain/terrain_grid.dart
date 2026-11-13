import 'package:fledge_physics/fledge_physics.dart' show CollisionGrid;
import 'package:tiled/tiled.dart';

/// The terrain painted on a tile layer with Tiled's terrain brush, at the
/// resolution of its corners: each tile is split into four quarter cells
/// (top-left, top-right, bottom-left, bottom-right), and each quarter holds
/// the name of its corner's Wang colour (`'road'`, `'grass'`, ...), or null
/// where no corner terrain is set.
///
/// Built from a map loaded by [AssetTilemapLoader], which repairs the Wang
/// tiles `package:tiled` drops. Corner and mixed Wang sets are read; edge
/// sets have no corners and give null.
///
/// ```dart
/// final terrain = TerrainGrid.fromTilemap(tilemap.map, layer: 'ground');
/// terrain.terrainAt(100, 40); // 'road'
/// ```
class TerrainGrid {
  TerrainGrid._(
    this.width,
    this.height,
    this.cellWidth,
    this.cellHeight,
    this._cells,
  );

  /// The corner terrain of [map]'s tile [layer].
  ///
  /// Assumes the layer's tiles aren't flipped or rotated, which the terrain
  /// brush never does.
  factory TerrainGrid.fromTilemap(TiledMap map, {required String layer}) {
    final width = map.width * 2;
    final height = map.height * 2;
    final cells = List<String?>.filled(width * height, null);
    final data = map.layers
        .whereType<TileLayer>()
        .where((l) => l.name == layer)
        .firstOrNull
        ?.tileData;
    if (data != null) {
      final byGid = _cornersByGid(map);
      for (var y = 0; y < data.length && y < map.height; y++) {
        final row = data[y];
        for (var x = 0; x < row.length && x < map.width; x++) {
          final corners = byGid[row[x].tile];
          if (corners == null) continue;
          cells[(2 * y) * width + 2 * x] = corners[0];
          cells[(2 * y) * width + 2 * x + 1] = corners[1];
          cells[(2 * y + 1) * width + 2 * x] = corners[2];
          cells[(2 * y + 1) * width + 2 * x + 1] = corners[3];
        }
      }
    }
    return TerrainGrid._(
      width,
      height,
      map.tileWidth / 2,
      map.tileHeight / 2,
      cells,
    );
  }

  /// Each gid's corner terrains: top-left, top-right, bottom-left,
  /// bottom-right.
  static Map<int, List<String?>> _cornersByGid(TiledMap map) {
    final byGid = <int, List<String?>>{};
    for (final tileset in map.tilesets) {
      final first = tileset.firstGid ?? 1;
      for (final set in tileset.wangSets) {
        // package:tiled files a mixed set's colours under edgeColors.
        final colours = set.cornerColors.isNotEmpty
            ? set.cornerColors
            : set.edgeColors;
        String? name(int colour) => colour > 0 && colour <= colours.length
            ? colours[colour - 1].name
            : null;
        for (final tile in set.wangTiles) {
          // Clockwise from the top edge: corners at 7 (top left), 1 (top
          // right), 5 (bottom left) and 3 (bottom right).
          final id = tile.wangId;
          if (id.length < 8) continue;
          byGid[first + tile.tileId] = [
            name(id[7]),
            name(id[1]),
            name(id[5]),
            name(id[3]),
          ];
        }
      }
    }
    return byGid;
  }

  /// Cells across: twice the map's width in tiles.
  final int width;

  /// Cells down: twice the map's height in tiles.
  final int height;

  /// The width of a cell in map pixels: half a tile.
  final double cellWidth;

  /// The height of a cell in map pixels: half a tile.
  final double cellHeight;

  final List<String?> _cells;

  /// The terrain of cell ([x], [y]), or null outside the grid or where none
  /// is painted.
  String? cornerAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return null;
    return _cells[y * width + x];
  }

  /// The terrain at ([x], [y]) in map pixels, relative to the map's
  /// top-left corner.
  String? terrainAt(double x, double y) =>
      cornerAt((x / cellWidth).floor(), (y / cellHeight).floor());
}

/// Sets the cost of every cell of [grid] from [terrain], so that
/// `Pathfinder` prefers cheap ground (roads, paths) over dear (mud, sand):
/// a cell costs `costs[name]`, or [defaultCost] for terrain not in [costs]
/// or none.
///
/// [grid] must cover the same map at either the terrain's resolution (half
/// a tile per cell) or a tile per cell, as `extractCollisionGrid` makes it;
/// a tile then costs the mean of its four corners.
///
/// ```dart
/// final grid = extractCollisionGrid(tilemap);
/// applyTerrainCosts(
///   grid,
///   TerrainGrid.fromTilemap(tilemap.map, layer: 'ground'),
///   {'road': 1, 'path': 1},
///   defaultCost: 3, // cut across open ground only to save a 3× detour
/// );
/// ```
void applyTerrainCosts(
  CollisionGrid grid,
  TerrainGrid terrain,
  Map<String, double> costs, {
  double defaultCost = 1.0,
}) {
  double cost(int x, int y) => costs[terrain.cornerAt(x, y)] ?? defaultCost;
  if (grid.width == terrain.width && grid.height == terrain.height) {
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        grid.setCost(x, y, cost(x, y));
      }
    }
  } else if (grid.width * 2 == terrain.width &&
      grid.height * 2 == terrain.height) {
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        final sum =
            cost(2 * x, 2 * y) +
            cost(2 * x + 1, 2 * y) +
            cost(2 * x, 2 * y + 1) +
            cost(2 * x + 1, 2 * y + 1);
        grid.setCost(x, y, sum / 4);
      }
    }
  } else {
    throw ArgumentError(
      'grid is ${grid.width}x${grid.height}; expected '
      '${terrain.width}x${terrain.height} (corners) or '
      '${terrain.width ~/ 2}x${terrain.height ~/ 2} (tiles)',
    );
  }
}
