import 'dart:ui' show Offset;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart'
    show DrawLayerExtension, Extractor, RenderWorld;
import 'package:fledge_render_2d/fledge_render_2d.dart' show GlobalTransform2D;
import 'package:vector_math/vector_math.dart' show Vector2;

import '../components/tile_layer.dart';
import '../components/tilemap.dart';
import '../components/tilemap_animator.dart';
import '../resources/tilemap_assets.dart';
import 'extracted_tile.dart';

/// Extractor for tilemap layers.
///
/// Converts [TileLayer] components to [ExtractedTile] entities
/// in the render world. Handles animated tiles and visibility.
class TilemapExtractor extends Extractor {
  /// Whether to skip invisible layers.
  final bool respectVisibility;

  TilemapExtractor({this.respectVisibility = true});

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final assets = mainWorld.getResource<TilemapAssets>();
    if (assets == null) return;

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
        );
      }
    }
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
  ) {
    final tiles = layer.tiles;
    if (tiles == null || tiles.isEmpty) return;

    final tileWidth = loaded.tileWidth.toDouble();
    final tileHeight = loaded.tileHeight.toDouble();
    final layerColor = layer.effectiveColor;

    for (final tile in tiles) {
      if (tile.gid == 0) continue; // Empty tile

      // Get tileset for this tile
      final tileset = loaded.tilesets.elementAtOrNull(tile.tilesetIndex);
      if (tileset == null) continue;

      // Get current frame if animated
      int localId = tile.localId;
      if (tile.animated && animator != null) {
        // Convert to GID for animation lookup
        final gid = tileset.localIdToGid(tile.localId);
        localId = animator.getCurrentFrame(gid);
        // Convert back to local ID if the animation returned a different tile
        if (localId != tile.localId) {
          // The animation frame is a local ID
        }
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

      // Apply layer parallax (simple parallax, more complex would need camera)
      worldX *= layer.parallax.dx;
      worldY *= layer.parallax.dy;

      // Apply map transform
      final mapPos = mapTransform.transformPoint(
        Vector2(worldX, worldY),
      );
      worldX = mapPos.x;
      worldY = mapPos.y;

      // Sort key: layer index * layerMultiplier + Y position
      final sortKey = DrawLayerExtension.sortKeyFromIndex(
        layerIndex: layer.layerIndex,
        subOrder: tile.y,
      );

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
