import 'dart:ui' show Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart'
    show DrawLayer, DrawLayerExtension, Extractor, RenderWorld;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show Camera2D, GlobalTransform2D, Transform2D, ViewportSize;
import 'package:vector_math/vector_math.dart' show Vector2;

import '../components/tile_layer.dart';
import '../components/tilemap.dart';
import '../components/tilemap_animator.dart';
import '../resources/tilemap_assets.dart';
import 'extracted_tile.dart';

/// Camera-aware tilemap extractor that culls tiles at extraction time.
///
/// Unlike [TilemapExtractor] which extracts all tiles and relies on canvas
/// clipping, this extractor only extracts tiles within the camera's visible
/// bounds. This dramatically improves performance for large maps.
///
/// ## Performance Comparison
///
/// For a 100x100 tile map:
/// - [TilemapExtractor]: Extracts 10,000 tiles per frame
/// - [CulledTilemapExtractor]: Extracts ~300-400 visible tiles per frame
///
/// ## Requirements
///
/// This extractor requires:
/// - A [Camera2D] entity with [Transform2D] in the world
/// - A [ViewportSize] resource (optional, defaults to 1280x720)
///
/// ## Usage
///
/// Register in your plugin instead of [TilemapExtractor]:
///
/// ```dart
/// final extractors = app.world.getResource<Extractors>()!;
/// extractors.register(CulledTilemapExtractor());
/// ```
///
/// Update the viewport size each frame before `tick()`:
///
/// ```dart
/// void _gameLoop() {
///   world.getResource<ViewportSize>()?.updateFromSize(screenSize);
///   app.tick();
/// }
/// ```
///
/// ## When to Use
///
/// Use [CulledTilemapExtractor] when:
/// - Your maps are larger than ~20x20 tiles
/// - You have multiple tile layers
/// - Performance is a concern
///
/// Use [TilemapExtractor] when:
/// - Your maps are small (< 400 tiles total)
/// - You need maximum simplicity
/// - The camera doesn't track a specific area
class CulledTilemapExtractor extends Extractor {
  /// Whether to skip invisible layers.
  final bool respectVisibility;

  /// Extra margin around visible bounds (in pixels).
  ///
  /// Prevents tile popping at screen edges during fast camera movement.
  /// Default is 96 pixels (2 tiles at 48px).
  final double cullMargin;

  /// Creates a camera-aware tilemap extractor.
  ///
  /// [respectVisibility] - If true, skips layers marked invisible in Tiled.
  /// [cullMargin] - Extra pixels beyond visible bounds to extract.
  CulledTilemapExtractor({
    this.respectVisibility = true,
    this.cullMargin = 96.0,
  });

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final assets = mainWorld.getResource<TilemapAssets>();
    if (assets == null) return;

    // Get camera bounds for culling
    final cullBounds = _getCullBounds(mainWorld);

    // Query for tilemap entities
    for (final (mapEntity, tilemap, mapTransform)
        in mainWorld.query2<Tilemap, GlobalTransform2D>().iter()) {
      final animator = mainWorld.get<TilemapAnimator>(mapEntity);

      // Find the loaded tilemap data
      final loaded = _findLoadedTilemap(assets, tilemap);
      if (loaded == null) continue;

      // Extract each tile layer (child entities)
      for (final layerEntity in mainWorld.getChildren(mapEntity)) {
        final layer = mainWorld.get<TileLayer>(layerEntity);
        if (layer == null) continue;

        // Check visibility
        if (respectVisibility) {
          final visible = tilemap.isLayerVisible(layer.name, layer.visible);
          if (!visible) continue;
        }

        final layerTransform = mainWorld.get<GlobalTransform2D>(layerEntity);

        _extractLayer(
          renderWorld,
          layer,
          loaded,
          mapTransform,
          layerTransform,
          animator,
          cullBounds,
        );
      }
    }
  }

  /// Gets the culling bounds from camera and viewport.
  ///
  /// Returns a world-space rectangle representing the visible area plus margin.
  /// Falls back to a large default if camera or viewport is not available.
  Rect? _getCullBounds(World world) {
    // Get camera position
    final cameraQuery = world.query2<Camera2D, Transform2D>().iter();
    if (cameraQuery.isEmpty) return null;

    final (_, _, cameraTransform) = cameraQuery.first;
    final centerX = cameraTransform.translation.x;
    final centerY = cameraTransform.translation.y;

    // Get viewport size
    final viewport = world.getResource<ViewportSize>();
    final viewWidth = viewport?.width ?? 1280;
    final viewHeight = viewport?.height ?? 720;

    // Create bounds centered on camera with margin
    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: viewWidth + cullMargin * 2,
      height: viewHeight + cullMargin * 2,
    );
  }

  LoadedTilemap? _findLoadedTilemap(TilemapAssets assets, Tilemap tilemap) {
    // Match by map dimensions and tile size
    for (final key in assets.keys) {
      final loaded = assets.get(key);
      if (loaded != null &&
          loaded.width == tilemap.width &&
          loaded.height == tilemap.height &&
          loaded.tileWidth == tilemap.tileWidth &&
          loaded.tileHeight == tilemap.tileHeight) {
        return loaded;
      }
    }
    return null;
  }

  void _extractLayer(
    RenderWorld renderWorld,
    TileLayer layer,
    LoadedTilemap loaded,
    GlobalTransform2D mapTransform,
    GlobalTransform2D? layerTransform,
    TilemapAnimator? animator,
    Rect? cullBounds,
  ) {
    final tiles = layer.tiles;
    if (tiles == null || tiles.isEmpty) return;

    final tileWidth = loaded.tileWidth.toDouble();
    final tileHeight = loaded.tileHeight.toDouble();
    final layerColor = layer.effectiveColor;

    // Calculate tile index bounds if we have cull bounds
    int? minTileX, maxTileX, minTileY, maxTileY;
    if (cullBounds != null) {
      // Convert world bounds to tile indices
      // Account for layer offset and parallax
      final offsetX = layer.offset.dx * layer.parallax.dx;
      final offsetY = layer.offset.dy * layer.parallax.dy;

      minTileX = ((cullBounds.left - offsetX) / tileWidth).floor() - 1;
      maxTileX = ((cullBounds.right - offsetX) / tileWidth).ceil() + 1;
      minTileY = ((cullBounds.top - offsetY) / tileHeight).floor() - 1;
      maxTileY = ((cullBounds.bottom - offsetY) / tileHeight).ceil() + 1;

      // Clamp to valid range
      minTileX = minTileX.clamp(0, loaded.width - 1);
      maxTileX = maxTileX.clamp(0, loaded.width - 1);
      minTileY = minTileY.clamp(0, loaded.height - 1);
      maxTileY = maxTileY.clamp(0, loaded.height - 1);
    }

    for (final tile in tiles) {
      if (tile.gid == 0) continue; // Empty tile

      // Early culling by tile coordinates
      if (minTileX != null) {
        if (tile.x < minTileX ||
            tile.x > maxTileX! ||
            tile.y < minTileY! ||
            tile.y > maxTileY!) {
          continue;
        }
      }

      // Get tileset for this tile
      final tileset = loaded.tilesets.elementAtOrNull(tile.tilesetIndex);
      if (tileset == null) continue;

      // Get current frame if animated
      int localId = tile.localId;
      if (tile.animated && animator != null) {
        // Convert to GID for animation lookup
        final gid = tileset.localIdToGid(tile.localId);
        localId = animator.getCurrentFrame(gid);
      }

      // Get source rect from tileset atlas
      if (!tileset.containsTile(localId)) continue;
      final sourceRect = tileset.getTileRect(localId);

      // Compute world position
      final localX = tile.x * tileWidth + layer.offset.dx;
      final localY = tile.y * tileHeight + layer.offset.dy;

      // Apply transforms
      double worldX = localX;
      double worldY = localY;

      // Apply layer parallax
      worldX *= layer.parallax.dx;
      worldY *= layer.parallax.dy;

      // Apply map transform
      final mapPos = mapTransform.transformPoint(
        Vector2(worldX, worldY),
      );
      worldX = mapPos.x;
      worldY = mapPos.y;

      // Sort key based on layer class:
      // - "above" layers use DrawLayer.foreground (renders above characters)
      // - Other layers use DrawLayer.ground (renders below characters)
      final drawLayer = (layer.layerClass == 'above')
          ? DrawLayer.foreground
          : DrawLayer.ground;
      final sortKey =
          drawLayer.sortKey(subOrder: tile.y * 100 + layer.layerIndex);

      renderWorld.spawn().insert(ExtractedTile(
            texture: tileset.atlas.texture,
            sourceRect: sourceRect,
            position: Offset(worldX, worldY),
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            color: layerColor,
            sortKey: sortKey,
            flipFlags: tile.flipFlags,
          ));
    }
  }
}
