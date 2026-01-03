import 'dart:ui' show Rect;
import 'package:tiled/tiled.dart' as tiled show TiledMap, RenderOrder;

/// Root component representing a complete Tiled map.
///
/// Attached to the parent entity that owns all map layers.
/// Child entities represent individual tile layers and object layers.
///
/// Example:
/// ```dart
/// final mapEntity = world.spawn()
///   ..insert(Tilemap.fromTiledMap(loadedMap))
///   ..insert(Transform2D())
///   ..insert(GlobalTransform2D());
/// ```
class Tilemap {
  /// Reference to the loaded TiledMap data.
  final tiled.TiledMap map;

  /// Computed world-space bounds of the map.
  final Rect bounds;

  /// Tile width in pixels.
  final int tileWidth;

  /// Tile height in pixels.
  final int tileHeight;

  /// Map width in tiles.
  final int width;

  /// Map height in tiles.
  final int height;

  /// Whether this is an infinite map.
  final bool infinite;

  /// Render order for tiles.
  final RenderOrder renderOrder;

  /// Layer visibility overrides (layer name -> visible).
  ///
  /// Use this to toggle layer visibility at runtime without
  /// modifying the layer components directly.
  final Map<String, bool> layerVisibility;

  Tilemap({
    required this.map,
    required this.bounds,
    required this.tileWidth,
    required this.tileHeight,
    required this.width,
    required this.height,
    this.infinite = false,
    this.renderOrder = RenderOrder.rightDown,
    Map<String, bool>? layerVisibility,
  }) : layerVisibility = layerVisibility ?? {};

  /// Creates a Tilemap component from a parsed TiledMap.
  factory Tilemap.fromTiledMap(tiled.TiledMap tiledMap) {
    return Tilemap(
      map: tiledMap,
      bounds: Rect.fromLTWH(
        0,
        0,
        tiledMap.width * tiledMap.tileWidth.toDouble(),
        tiledMap.height * tiledMap.tileHeight.toDouble(),
      ),
      tileWidth: tiledMap.tileWidth,
      tileHeight: tiledMap.tileHeight,
      width: tiledMap.width,
      height: tiledMap.height,
      infinite: tiledMap.infinite,
      renderOrder: RenderOrder.fromTiledEnum(tiledMap.renderOrder),
    );
  }

  /// Returns true if the given layer should be visible.
  ///
  /// Checks both the visibility override and the layer's own visibility.
  bool isLayerVisible(String layerName, bool defaultVisibility) {
    return layerVisibility[layerName] ?? defaultVisibility;
  }

  /// Sets layer visibility override.
  void setLayerVisible(String layerName, bool visible) {
    layerVisibility[layerName] = visible;
  }

  /// Clears visibility override for a layer, reverting to its default.
  void clearLayerVisibility(String layerName) {
    layerVisibility.remove(layerName);
  }
}

/// Render order for tiles in the map.
enum RenderOrder {
  /// Right-down: render left-to-right, top-to-bottom (default).
  rightDown,

  /// Right-up: render left-to-right, bottom-to-top.
  rightUp,

  /// Left-down: render right-to-left, top-to-bottom.
  leftDown,

  /// Left-up: render right-to-left, bottom-to-top.
  leftUp;

  /// Parses the render order from Tiled's RenderOrder enum.
  static RenderOrder fromTiledEnum(tiled.RenderOrder? order) {
    switch (order) {
      case tiled.RenderOrder.rightUp:
        return RenderOrder.rightUp;
      case tiled.RenderOrder.leftDown:
        return RenderOrder.leftDown;
      case tiled.RenderOrder.leftUp:
        return RenderOrder.leftUp;
      case tiled.RenderOrder.rightDown:
      case null:
        return RenderOrder.rightDown;
    }
  }

  /// Parses the render order from Tiled's string representation (legacy).
  static RenderOrder fromTiled(String? order) {
    switch (order) {
      case 'right-up':
        return RenderOrder.rightUp;
      case 'left-down':
        return RenderOrder.leftDown;
      case 'left-up':
        return RenderOrder.leftUp;
      case 'right-down':
      default:
        return RenderOrder.rightDown;
    }
  }
}
