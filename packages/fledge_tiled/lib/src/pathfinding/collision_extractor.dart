import 'dart:math' as math;

import 'package:fledge_physics/fledge_physics.dart';
import 'package:tiled/tiled.dart' show TileLayer, TiledMap;

import '../resources/tilemap_assets.dart';

/// Extracts a [CollisionGrid] from a [LoadedTilemap].
///
/// This utility creates a walkability grid by examining tile layers
/// that contain collision information: every non-empty tile on one of
/// [collisionLayers] blocks its cell.
///
/// On a finite map the grid is the map's size and cell `(x, y)` is tile
/// `(x, y)`. On an infinite map the tiles live in chunks that can sit at
/// negative tile coordinates, so the grid covers the bounding box of the
/// collision layers' chunks instead, and cell `(0, 0)` is tile
/// [collisionGridOrigin]: subtract the origin from a tile coordinate to
/// get its cell (and add it back to the cells of a path).
///
/// Example:
/// ```dart
/// final tilemap = await loader.load('level.tmx', textureLoader);
/// final grid = extractCollisionGrid(
///   tilemap,
///   collisionLayers: {'Collision', 'Walls'},
/// );
///
/// // Use with pathfinder
/// final pathfinder = Pathfinder();
/// final result = pathfinder.findPath(grid, 0, 0, 10, 10);
/// ```
CollisionGrid extractCollisionGrid(
  LoadedTilemap tilemap, {
  Set<String> collisionLayers = const {'Collision', 'collision'},
}) {
  final bounds = _gridBounds(tilemap.map, collisionLayers);
  final grid = CollisionGrid(width: bounds.width, height: bounds.height);
  _processMap(grid, tilemap.map, collisionLayers, bounds.x, bounds.y);
  return grid;
}

/// The tile coordinate of cell `(0, 0)` of the grid [extractCollisionGrid]
/// builds for [tilemap] with the same [collisionLayers].
///
/// `(0, 0)` for a finite map; for an infinite map, the top-left tile of the
/// collision layers' chunks (negative when they reach left of or above the
/// map's origin).
({int x, int y}) collisionGridOrigin(
  LoadedTilemap tilemap, {
  Set<String> collisionLayers = const {'Collision', 'collision'},
}) {
  final bounds = _gridBounds(tilemap.map, collisionLayers);
  return (x: bounds.x, y: bounds.y);
}

/// The tile area the grid covers: the map for a finite map, the chunks of
/// the collision layers for an infinite one (the map's size at the origin
/// if they have none).
({int x, int y, int width, int height}) _gridBounds(
  TiledMap map,
  Set<String> collisionLayers,
) {
  final fallback = (x: 0, y: 0, width: map.width, height: map.height);
  if (!map.infinite) return fallback;
  int? minX, minY, maxX, maxY;
  for (final layer in _collisionLayers(map, collisionLayers)) {
    for (final chunk in layer.chunks ?? const []) {
      minX = math.min(minX ?? chunk.x, chunk.x);
      minY = math.min(minY ?? chunk.y, chunk.y);
      maxX = math.max(maxX ?? chunk.x + chunk.width, chunk.x + chunk.width);
      maxY = math.max(maxY ?? chunk.y + chunk.height, chunk.y + chunk.height);
    }
  }
  if (minX == null) return fallback;
  return (x: minX, y: minY!, width: maxX! - minX, height: maxY! - minY);
}

Iterable<TileLayer> _collisionLayers(
  TiledMap map,
  Set<String> collisionLayers,
) => map.layers.whereType<TileLayer>().where(
  (layer) => collisionLayers.contains(layer.name),
);

void _processMap(
  CollisionGrid grid,
  TiledMap map,
  Set<String> collisionLayers,
  int originX,
  int originY,
) {
  for (final layer in _collisionLayers(map, collisionLayers)) {
    _processCollisionLayer(grid, layer, originX, originY);
  }
}

/// Process a single tile layer and mark blocked tiles: its data on a
/// finite map, its chunks on an infinite one. Tile `(x, y)` is cell
/// `(x - originX, y - originY)`; cells outside the grid are dropped.
void _processCollisionLayer(
  CollisionGrid grid,
  TileLayer layer,
  int originX,
  int originY,
) {
  void mark(List<int> data, int width, int left, int top) {
    if (width <= 0) return;
    for (var i = 0; i < data.length; i++) {
      // Non-zero GID means there's a collision tile here
      if (data[i] == 0) continue;
      grid.setBlocked(left + i % width - originX, top + i ~/ width - originY);
    }
  }

  final data = layer.data;
  if (data != null) {
    mark(data, layer.width, 0, 0);
    return;
  }
  for (final chunk in layer.chunks ?? const []) {
    mark(chunk.data, chunk.width, chunk.x, chunk.y);
  }
}

/// Extracts collision grids from multiple tilemaps.
///
/// Useful when you need pathfinding data for multiple maps.
///
/// Example:
/// ```dart
/// final grids = extractCollisionGrids({
///   'level1': level1Tilemap,
///   'level2': level2Tilemap,
/// });
///
/// final level1Grid = grids['level1']!;
/// ```
Map<String, CollisionGrid> extractCollisionGrids(
  Map<String, LoadedTilemap> tilemaps, {
  Set<String> collisionLayers = const {'Collision', 'collision'},
}) {
  return tilemaps.map(
    (key, tilemap) => MapEntry(
      key,
      extractCollisionGrid(tilemap, collisionLayers: collisionLayers),
    ),
  );
}

/// Extracts a [CollisionGrid] directly from TMX content.
///
/// This is useful when you need collision data without loading
/// the full tilemap (textures, etc.). It parses the TMX XML and
/// extracts only the collision layer information.
///
/// Parameters:
/// - [tmxContent]: The raw TMX file content as a string
/// - [mapWidth]: Width of the grid in tiles
/// - [mapHeight]: Height of the grid in tiles
/// - [collisionLayers]: Names of layers containing collision tiles
///
/// Cell `(x, y)` is tile `(x, y)`; on an infinite map, tiles of chunks
/// outside `[0, mapWidth) x [0, mapHeight)` are dropped (load the map and
/// use [extractCollisionGrid] to cover every chunk).
///
/// Throws whatever the TMX parser throws (for example an `XmlException`
/// or a `ParsingException` from `package:tiled`) when [tmxContent] isn't a
/// valid map, rather than returning an all-walkable grid.
///
/// Example:
/// ```dart
/// final tmxContent = await rootBundle.loadString('assets/maps/level.tmx');
/// final grid = extractCollisionGridFromTmx(
///   tmxContent,
///   mapWidth: 100,
///   mapHeight: 100,
///   collisionLayers: {'Collision'},
/// );
/// ```
CollisionGrid extractCollisionGridFromTmx(
  String tmxContent, {
  required int mapWidth,
  required int mapHeight,
  Set<String> collisionLayers = const {'Collision', 'collision'},
}) {
  // Parse TMX without loading external tilesets (we only need layer data)
  final tiledMap = TiledMap.parseTmx(tmxContent);
  final grid = CollisionGrid(width: mapWidth, height: mapHeight);
  _processMap(grid, tiledMap, collisionLayers, 0, 0);
  return grid;
}
