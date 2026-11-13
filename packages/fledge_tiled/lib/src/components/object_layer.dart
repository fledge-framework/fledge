import 'dart:ui' show Color, Offset;

import 'package:fledge_physics/fledge_physics.dart' show CollisionShape;
import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;

import '../properties/tiled_properties.dart';
import '../resources/tilemap_assets.dart' show TilesetLookup;

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

  /// Tile GID (if this is a tile object), including Tiled's flip flags.
  final int? gid;

  /// The tile a tile object shows: its tileset and local ID, for its image
  /// ([tileImage]), collision shapes ([tileCollision]) and the rest of the
  /// tile's data. Null for other objects or an unknown GID.
  ///
  /// A tile object's [type] and [properties] already include its tile's:
  /// the object's own class wins if set, and its own properties override
  /// the tile's.
  final TilesetLookup? tile;

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
    this.tile,
    required this.properties,
    this.visible = true,
  });

  /// Returns the center point of the object.
  Offset get center => Offset(x + width / 2, y + height / 2);

  /// Returns true if this is a tile object.
  bool get isTileObject => gid != null;

  /// A tile object's image, when its tile is from an image-collection
  /// tileset. Tiled draws it with its bottom-left corner at ([x], [y]) and
  /// at [width] × [height] (orthogonal maps, no rotation).
  TextureHandle? get tileImage => tile?.tileset.getTileImage(tile!.localId);

  /// A tile object's tile collision shapes (Tiled's tile collision editor),
  /// relative to the tile image's top-left corner at its natural size; empty
  /// if none.
  List<CollisionShape> get tileCollision =>
      tile?.tileset.getCollisionShapes(tile!.localId) ?? const [];

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
