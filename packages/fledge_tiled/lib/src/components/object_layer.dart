import 'dart:ui' show Color, Offset;

import '../properties/tiled_properties.dart';

/// Component for object layers from Tiled.
///
/// Object layers contain points, rectangles, polygons, and other
/// shapes that can be used for spawning entities, defining collision
/// zones, or placing triggers.
///
/// Example:
/// ```dart
/// for (final (entity, layer) in world.query1<ObjectLayer>().iter()) {
///   for (final obj in layer.objects) {
///     if (obj.type == 'spawn_point') {
///       spawnEnemy(obj.x, obj.y);
///     }
///   }
/// }
/// ```
class ObjectLayer {
  /// Layer name from Tiled.
  final String name;

  /// Layer index for sorting.
  final int layerIndex;

  /// Parsed objects in this layer.
  final List<TiledObjectData> objects;

  /// Draw order for tile objects.
  final DrawOrder drawOrder;

  /// Layer color (from Tiled editor, useful for debugging).
  final Color? color;

  /// Opacity (0.0 - 1.0).
  double opacity;

  /// Visibility flag.
  bool visible;

  /// Offset from map origin in pixels.
  final Offset offset;

  ObjectLayer({
    required this.name,
    required this.layerIndex,
    required this.objects,
    this.drawOrder = DrawOrder.topDown,
    this.color,
    this.opacity = 1.0,
    this.visible = true,
    this.offset = Offset.zero,
  });

  /// Finds objects by type.
  Iterable<TiledObjectData> findByType(String type) =>
      objects.where((obj) => obj.type == type);

  /// Finds objects by name.
  Iterable<TiledObjectData> findByName(String name) =>
      objects.where((obj) => obj.name == name);

  /// Finds an object by ID.
  TiledObjectData? findById(int id) {
    for (final obj in objects) {
      if (obj.id == id) return obj;
    }
    return null;
  }
}

/// Draw order for objects in an object layer.
enum DrawOrder {
  /// Objects are drawn in Y order (top to bottom).
  topDown,

  /// Objects are drawn in their layer order (as defined in Tiled).
  indexOrder,
}

/// Normalized object data from Tiled.
///
/// Contains all information about a single object, including its
/// shape, position, and custom properties.
class TiledObjectData {
  /// Unique object ID (unique within the map).
  final int id;

  /// Object name (optional, for identification).
  final String? name;

  /// Object type/class (optional, for categorization).
  final String? type;

  /// X position in pixels (relative to layer).
  final double x;

  /// Y position in pixels (relative to layer).
  final double y;

  /// Width in pixels (for rectangles, ellipses, images).
  final double width;

  /// Height in pixels (for rectangles, ellipses, images).
  final double height;

  /// Rotation in degrees (clockwise).
  final double rotation;

  /// Template reference (if this object is from a template).
  final String? template;

  /// Shape type of this object.
  final ObjectShape shape;

  /// Polygon/polyline points (if applicable).
  ///
  /// Points are relative to (x, y).
  final List<Offset>? points;

  /// Tile GID (if this is a tile object).
  final int? gid;

  /// Custom properties defined in Tiled.
  final TiledProperties properties;

  /// Whether this object is visible.
  final bool visible;

  const TiledObjectData({
    required this.id,
    this.name,
    this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.template,
    required this.shape,
    this.points,
    this.gid,
    required this.properties,
    this.visible = true,
  });

  /// Returns the center point of the object.
  Offset get center => Offset(x + width / 2, y + height / 2);

  /// Returns true if this is a tile object.
  bool get isTileObject => gid != null;

  /// Returns true if this is a point object.
  bool get isPoint => shape == ObjectShape.point;

  /// Returns true if this object has custom properties.
  bool get hasProperties => properties.isNotEmpty;
}

/// Shape types for Tiled objects.
enum ObjectShape {
  /// A rectangle (default shape).
  rectangle,

  /// An ellipse.
  ellipse,

  /// A polygon (closed shape with multiple vertices).
  polygon,

  /// A polyline (open shape with multiple vertices).
  polyline,

  /// A single point.
  point,

  /// A tile object (sprite placed as an object).
  tile,

  /// A text object.
  text,
}

/// Component attached to entities spawned from Tiled objects.
///
/// Provides access to the object's ID, name, type, and custom properties.
class TiledObject {
  /// Unique object ID from Tiled.
  final int id;

  /// Object name (optional).
  final String? name;

  /// Object type/class (optional).
  final String? type;

  /// Custom properties from Tiled.
  final TiledProperties properties;

  const TiledObject({
    required this.id,
    this.name,
    this.type,
    required this.properties,
  });

  /// Creates a TiledObject component from TiledObjectData.
  factory TiledObject.fromData(TiledObjectData data) {
    return TiledObject(
      id: data.id,
      name: data.name,
      type: data.type,
      properties: data.properties,
    );
  }
}
