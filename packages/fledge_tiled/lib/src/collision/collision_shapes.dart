import 'dart:ui' show Offset, Rect;

/// Base class for collision shapes from Tiled.
///
/// Shapes can be generated from Tiled objects or tile collision data.
abstract class CollisionShape {
  const CollisionShape();

  /// Returns a translated copy of this shape.
  CollisionShape translate(double dx, double dy);

  /// Returns the axis-aligned bounding box of this shape.
  Rect get bounds;
}

/// A rectangle collision shape.
class RectangleShape extends CollisionShape {
  /// X position (top-left corner).
  final double x;

  /// Y position (top-left corner).
  final double y;

  /// Width.
  final double width;

  /// Height.
  final double height;

  /// Rotation in degrees (clockwise).
  final double rotation;

  const RectangleShape({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
  });

  @override
  RectangleShape translate(double dx, double dy) => RectangleShape(
        x: x + dx,
        y: y + dy,
        width: width,
        height: height,
        rotation: rotation,
      );

  @override
  Rect get bounds {
    // For rotated rectangles, compute AABB
    if (rotation == 0) {
      return Rect.fromLTWH(x, y, width, height);
    }

    // Simple AABB for rotated rectangle (conservative)
    final diagonal = (width * width + height * height);
    final halfDiag = diagonal / 2;
    final centerX = x + width / 2;
    final centerY = y + height / 2;
    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: halfDiag * 2,
      height: halfDiag * 2,
    );
  }

  /// Center point of the rectangle.
  Offset get center => Offset(x + width / 2, y + height / 2);

  @override
  String toString() =>
      'RectangleShape(x: $x, y: $y, w: $width, h: $height, r: $rotation)';
}

/// An ellipse collision shape.
class EllipseShape extends CollisionShape {
  /// Center X coordinate.
  final double centerX;

  /// Center Y coordinate.
  final double centerY;

  /// Horizontal radius.
  final double radiusX;

  /// Vertical radius.
  final double radiusY;

  const EllipseShape({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
  });

  /// Creates an ellipse from bounding box coordinates.
  factory EllipseShape.fromBounds(double x, double y, double width, double height) {
    return EllipseShape(
      centerX: x + width / 2,
      centerY: y + height / 2,
      radiusX: width / 2,
      radiusY: height / 2,
    );
  }

  @override
  EllipseShape translate(double dx, double dy) => EllipseShape(
        centerX: centerX + dx,
        centerY: centerY + dy,
        radiusX: radiusX,
        radiusY: radiusY,
      );

  @override
  Rect get bounds => Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      );

  /// Center point of the ellipse.
  Offset get center => Offset(centerX, centerY);

  /// Returns true if this is a circle (equal radii).
  bool get isCircle => radiusX == radiusY;

  @override
  String toString() =>
      'EllipseShape(center: ($centerX, $centerY), r: ($radiusX, $radiusY))';
}

/// A polygon collision shape.
class PolygonShape extends CollisionShape {
  /// Polygon vertices (relative to offset).
  final List<Offset> points;

  /// X offset added to all points.
  final double offsetX;

  /// Y offset added to all points.
  final double offsetY;

  const PolygonShape({
    required this.points,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  @override
  PolygonShape translate(double dx, double dy) => PolygonShape(
        points: points,
        offsetX: offsetX + dx,
        offsetY: offsetY + dy,
      );

  @override
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in points) {
      final x = point.dx + offsetX;
      final y = point.dy + offsetY;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Returns the world-space vertices.
  List<Offset> get worldPoints =>
      points.map((p) => Offset(p.dx + offsetX, p.dy + offsetY)).toList();

  /// Number of vertices.
  int get vertexCount => points.length;

  @override
  String toString() =>
      'PolygonShape(${points.length} points, offset: ($offsetX, $offsetY))';
}

/// A polyline collision shape (open path).
class PolylineShape extends CollisionShape {
  /// Polyline vertices (relative to offset).
  final List<Offset> points;

  /// X offset added to all points.
  final double offsetX;

  /// Y offset added to all points.
  final double offsetY;

  const PolylineShape({
    required this.points,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  @override
  PolylineShape translate(double dx, double dy) => PolylineShape(
        points: points,
        offsetX: offsetX + dx,
        offsetY: offsetY + dy,
      );

  @override
  Rect get bounds {
    if (points.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in points) {
      final x = point.dx + offsetX;
      final y = point.dy + offsetY;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Returns the world-space vertices.
  List<Offset> get worldPoints =>
      points.map((p) => Offset(p.dx + offsetX, p.dy + offsetY)).toList();

  /// Number of vertices.
  int get vertexCount => points.length;

  /// Number of line segments.
  int get segmentCount => points.length > 1 ? points.length - 1 : 0;

  @override
  String toString() =>
      'PolylineShape(${points.length} points, offset: ($offsetX, $offsetY))';
}

/// A point collision shape.
class PointShape extends CollisionShape {
  /// X coordinate.
  final double x;

  /// Y coordinate.
  final double y;

  const PointShape({required this.x, required this.y});

  @override
  PointShape translate(double dx, double dy) => PointShape(
        x: x + dx,
        y: y + dy,
      );

  @override
  Rect get bounds => Rect.fromLTWH(x, y, 0, 0);

  /// Returns this point as an Offset.
  Offset get position => Offset(x, y);

  @override
  String toString() => 'PointShape($x, $y)';
}

/// Component containing collision shapes.
///
/// Attach to entities that need collision detection.
class Collider {
  /// Collision shapes for this entity.
  final List<CollisionShape> shapes;

  const Collider({required this.shapes});

  /// Creates a collider with a single shape.
  Collider.single(CollisionShape shape) : shapes = [shape];

  /// Returns the combined bounding box of all shapes.
  Rect get bounds {
    if (shapes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final shape in shapes) {
      final b = shape.bounds;
      if (b.left < minX) minX = b.left;
      if (b.top < minY) minY = b.top;
      if (b.right > maxX) maxX = b.right;
      if (b.bottom > maxY) maxY = b.bottom;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Number of shapes.
  int get length => shapes.length;

  /// Whether there are no shapes.
  bool get isEmpty => shapes.isEmpty;

  /// Whether there are shapes.
  bool get isNotEmpty => shapes.isNotEmpty;
}
