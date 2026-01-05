import 'package:tiled/tiled.dart' show TileLayer, TileMapParser;

import '../resources/tilemap_assets.dart';
import 'collision_grid.dart';

/// Extracts a [CollisionGrid] from a [LoadedTilemap].
///
/// This utility creates a walkability grid by examining tile layers
/// that contain collision information.
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
  final grid = CollisionGrid(
    width: tilemap.width,
    height: tilemap.height,
  );

  // Process each tile layer
  for (final layer in tilemap.map.layers) {
    if (layer is TileLayer && collisionLayers.contains(layer.name)) {
      _processCollisionLayer(grid, layer);
    }
  }

  return grid;
}

/// Process a single tile layer and mark blocked tiles.
void _processCollisionLayer(CollisionGrid grid, TileLayer layer) {
  final width = layer.width;
  final height = layer.height;
  final data = layer.data;

  if (data == null) return;

  for (var y = 0; y < height && y < grid.height; y++) {
    for (var x = 0; x < width && x < grid.width; x++) {
      final index = y * width + x;
      if (index < data.length) {
        final tileGid = data[index];
        // Non-zero GID means there's a collision tile here
        if (tileGid != 0) {
          grid.setBlocked(x, y);
        }
      }
    }
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
/// - [mapWidth]: Width of the map in tiles
/// - [mapHeight]: Height of the map in tiles
/// - [collisionLayers]: Names of layers containing collision tiles
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
  final grid = CollisionGrid(width: mapWidth, height: mapHeight);

  try {
    // Parse TMX without loading external tilesets (we only need layer data)
    final tiledMap = TileMapParser.parseTmx(tmxContent);

    // Process collision layers
    for (final layer in tiledMap.layers) {
      if (layer is TileLayer && collisionLayers.contains(layer.name)) {
        _processCollisionLayer(grid, layer);
      }
    }
  } catch (e) {
    // If parsing fails, return empty grid (all walkable)
    // This allows the game to continue with fallback behavior
  }

  return grid;
}
