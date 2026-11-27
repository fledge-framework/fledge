import 'dart:ui' show Offset, Rect;

import 'package:fledge_physics/fledge_physics.dart';

import '../components/object_layer.dart';
import '../resources/tileset_registry.dart';

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
          ),
        ];

      case ObjectShape.ellipse:
        // Local space: ellipse centered within its bounds
        // Tiled positions ellipses from top-left of bounding box
        return [EllipseShape.fromBounds(0, 0, obj.width, obj.height)];

      case ObjectShape.polygon:
        if (obj.points == null || obj.points!.isEmpty) return [];
        // Local space: points are already relative, no offset needed
        return [PolygonShape(points: obj.points!, offsetX: 0, offsetY: 0)];

      case ObjectShape.polyline:
        if (obj.points == null || obj.points!.isEmpty) return [];
        // Local space: points are already relative, no offset needed
        return [PolylineShape(points: obj.points!, offsetX: 0, offsetY: 0)];

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

  /// Tile collision [shapes] (in the tile's own space, before flips) as
  /// they lie in the map when the tile is painted in cell ([gridX],
  /// [gridY]) of a [cellWidth] x [cellHeight] grid, exactly where its art
  /// is drawn: flipped about the tile's own size ([tileRect], its image in
  /// an image collection, else the map cell when empty), with the drawn
  /// box's bottom-left on the cell's bottom-left corner, then moved by the
  /// tileset's [tileOffset]. A tile the size of the cell, with no offset,
  /// fills the cell exactly.
  static List<CollisionShape> placeTileShapes(
    List<CollisionShape> shapes, {
    required Rect tileRect,
    required int gridX,
    required int gridY,
    required double cellWidth,
    required double cellHeight,
    Offset tileOffset = Offset.zero,
    bool horizontal = false,
    bool vertical = false,
    bool diagonal = false,
  }) {
    if (shapes.isEmpty) return const [];
    final width = tileRect.width > 0 ? tileRect.width : cellWidth;
    final height = tileRect.height > 0 ? tileRect.height : cellHeight;
    // A diagonal flip swaps the drawn box's sides.
    final boxHeight = diagonal ? width : height;
    final left = gridX * cellWidth + tileOffset.dx;
    final top = (gridY + 1) * cellHeight - boxHeight + tileOffset.dy;
    return [
      for (final shape in flipShapes(
        shapes,
        tileWidth: width,
        tileHeight: height,
        horizontal: horizontal,
        vertical: vertical,
        diagonal: diagonal,
      ))
        shape.translate(left, top),
    ];
  }

  /// [shapes] (in a tile's local space, [tileWidth] x [tileHeight], the
  /// tile's own size: an image-collection tile's image, not the tileset's
  /// largest tile) as they
  /// lie on a tile placed flipped: diagonally ([diagonal], a transpose of
  /// x and y), then horizontally, then vertically, in Tiled's order.
  ///
  /// Unrotated rectangles are transformed; other shapes are returned as
  /// they are (their collision on a flipped tile isn't supported yet).
  static List<CollisionShape> flipShapes(
    List<CollisionShape> shapes, {
    required double tileWidth,
    required double tileHeight,
    bool horizontal = false,
    bool vertical = false,
    bool diagonal = false,
  }) {
    if (!horizontal && !vertical && !diagonal) return shapes;
    // After a transpose the tile's extents swap too.
    final extentX = diagonal ? tileHeight : tileWidth;
    final extentY = diagonal ? tileWidth : tileHeight;
    return [
      for (final shape in shapes)
        if (shape is RectangleShape && shape.rotation == 0)
          () {
            var (x, y, w, h) = (shape.x, shape.y, shape.width, shape.height);
            if (diagonal) (x, y, w, h) = (y, x, h, w);
            if (horizontal) x = extentX - x - w;
            if (vertical) y = extentY - y - h;
            return RectangleShape(x: x, y: y, width: w, height: h);
          }()
        else
          shape,
    ];
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

  /// Merges adjacent rectangle shapes into larger rectangles: runs along a
  /// row first, then rows of the same span stacked one under another (a
  /// wall's column of tiles becomes one rectangle).
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

    return _mergeVertically(merged, tolerance);
  }

  /// Joins rectangles of the same x and width that touch top to bottom.
  static List<RectangleShape> _mergeVertically(
    List<RectangleShape> rows,
    double tolerance,
  ) {
    final byColumn = List<RectangleShape>.from(rows)
      ..sort((a, b) {
        final x = a.x.compareTo(b.x);
        if (x != 0) return x;
        final w = a.width.compareTo(b.width);
        return w != 0 ? w : a.y.compareTo(b.y);
      });
    final out = <RectangleShape>[];
    for (final next in byColumn) {
      final last = out.isEmpty ? null : out.last;
      if (last != null &&
          last.rotation == 0 &&
          next.rotation == 0 &&
          (last.x - next.x).abs() <= tolerance &&
          (last.width - next.width).abs() <= tolerance &&
          (last.y + last.height - next.y).abs() <= tolerance) {
        out[out.length - 1] = RectangleShape(
          x: last.x,
          y: last.y,
          width: last.width,
          height: last.height + next.height,
        );
      } else {
        out.add(next);
      }
    }
    return out;
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
