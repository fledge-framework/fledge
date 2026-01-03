import '../components/object_layer.dart';
import '../resources/tileset_registry.dart';
import 'collision_shapes.dart';

/// Utility for generating collision shapes from Tiled data.
class TileCollider {
  /// Converts a Tiled object to collision shapes in LOCAL space.
  ///
  /// Shapes are relative to the entity origin (0, 0). The entity's
  /// Transform2D should hold the world position (obj.x, obj.y).
  ///
  /// Returns an empty list for unsupported shapes (text, tile).
  static List<CollisionShape> fromObject(TiledObjectData obj) {
    switch (obj.shape) {
      case ObjectShape.rectangle:
        // Local space: shape starts at entity origin
        return [
          RectangleShape(
            x: 0,
            y: 0,
            width: obj.width,
            height: obj.height,
            rotation: obj.rotation,
          )
        ];

      case ObjectShape.ellipse:
        // Local space: ellipse centered within its bounds
        // Tiled positions ellipses from top-left of bounding box
        return [
          EllipseShape.fromBounds(
            0,
            0,
            obj.width,
            obj.height,
          )
        ];

      case ObjectShape.polygon:
        if (obj.points == null || obj.points!.isEmpty) return [];
        // Local space: points are already relative, no offset needed
        return [
          PolygonShape(
            points: obj.points!,
            offsetX: 0,
            offsetY: 0,
          )
        ];

      case ObjectShape.polyline:
        if (obj.points == null || obj.points!.isEmpty) return [];
        // Local space: points are already relative, no offset needed
        return [
          PolylineShape(
            points: obj.points!,
            offsetX: 0,
            offsetY: 0,
          )
        ];

      case ObjectShape.point:
        // Local space: point at entity origin
        return [PointShape(x: 0, y: 0)];

      case ObjectShape.tile:
      case ObjectShape.text:
        // Tile objects could have collision from their tileset
        // Text objects don't have collision
        return [];
    }
  }

  /// Generates collision shapes from tile collision data.
  ///
  /// Offsets the shapes to the world position of the tile.
  static List<CollisionShape> fromTileCollision(
    LoadedTileset tileset,
    int localId,
    double worldX,
    double worldY,
  ) {
    final tileShapes = tileset.getCollisionShapes(localId);
    if (tileShapes.isEmpty) return [];

    return tileShapes.map((shape) => shape.translate(worldX, worldY)).toList();
  }

  /// Generates collision shapes for all tiles with collision in a layer.
  ///
  /// This is useful for generating static collision for an entire tile layer.
  static List<CollisionShape> fromTileLayer({
    required Iterable<TileCollisionData> tiles,
    required double tileWidth,
    required double tileHeight,
  }) {
    final shapes = <CollisionShape>[];

    for (final tile in tiles) {
      final worldX = tile.gridX * tileWidth;
      final worldY = tile.gridY * tileHeight;

      for (final shape in tile.shapes) {
        shapes.add(shape.translate(worldX, worldY));
      }
    }

    return shapes;
  }

  /// Merges adjacent rectangle shapes into larger rectangles.
  ///
  /// Useful for optimizing tile-based collision where many tiles
  /// form continuous walls or platforms.
  static List<RectangleShape> mergeRectangles(
    List<RectangleShape> rectangles, {
    double tolerance = 0.001,
  }) {
    if (rectangles.isEmpty) return [];
    if (rectangles.length == 1) return rectangles;

    // Simple greedy horizontal merge
    final sorted = List<RectangleShape>.from(rectangles)
      ..sort((a, b) {
        final yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) return yCompare;
        return a.x.compareTo(b.x);
      });

    final merged = <RectangleShape>[];
    RectangleShape? current = sorted[0];

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];

      // Check if can merge horizontally
      if (_canMergeHorizontally(current!, next, tolerance)) {
        current = RectangleShape(
          x: current.x,
          y: current.y,
          width: current.width + next.width,
          height: current.height,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    if (current != null) {
      merged.add(current);
    }

    return merged;
  }

  static bool _canMergeHorizontally(
    RectangleShape a,
    RectangleShape b,
    double tolerance,
  ) {
    // Same row and height
    if ((a.y - b.y).abs() > tolerance) return false;
    if ((a.height - b.height).abs() > tolerance) return false;

    // Adjacent horizontally
    if ((a.x + a.width - b.x).abs() > tolerance) return false;

    // No rotation
    if (a.rotation != 0 || b.rotation != 0) return false;

    return true;
  }
}

/// Data for a tile with collision.
class TileCollisionData {
  /// Grid X position.
  final int gridX;

  /// Grid Y position.
  final int gridY;

  /// Collision shapes for this tile.
  final List<CollisionShape> shapes;

  const TileCollisionData({
    required this.gridX,
    required this.gridY,
    required this.shapes,
  });
}
