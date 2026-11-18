import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show ActiveCameraView, DrawLayer, Extractor, GlobalTransform2D, RenderWorld;

import '../components/tile_layer.dart';
import '../components/tilemap.dart';
import '../components/tilemap_animator.dart';
import '../resources/tilemap_assets.dart';
import 'extracted_tile.dart';
import 'tile_sprite_conversion.dart';

/// Extractor for tilemap layers.
///
/// Turns the tiles of every visible [TileLayer] near the camera into
/// `ExtractedSprite`s in the render world, drawn through the shared sprite
/// pipeline. Handles animated tiles and layer visibility.
///
/// Only tiles near the camera's last view ([ActiveCameraView]) are visited:
/// each layer keeps an index of its tiles by grid position, and the view is
/// mapped back into the layer's tile coordinates (through the map's
/// transform, the layer's parallax and offset), so the cost follows what's
/// on screen, not the size of the maps. The index is rebuilt when a layer's
/// `tiles` list is replaced or changes length; edit tiles by replacing
/// the list (or a `TileData` in it at the same index).
class TilemapExtractor extends Extractor {
  /// Whether to skip invisible layers.
  final bool respectVisibility;

  /// Also emit the deprecated [ExtractedTile] for every tile, for code that
  /// still reads it. Off by default: it doubles the render world's
  /// entities for nothing the shared pipeline needs.
  final bool emitLegacyTiles;

  /// World units beyond the camera's last view that are still extracted
  /// (camera movement since that paint).
  final double cullMargin;

  TilemapExtractor({
    this.respectVisibility = true,
    this.emitLegacyTiles = false,
    this.cullMargin = defaultCullMargin,
  });

  /// The default [cullMargin].
  static const double defaultCullMargin = 64;

  final Expando<_LayerIndex> _indexes = Expando('tile layer index');

  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    // ignore: deprecated_member_use_from_same_package
    final legacyAssets = mainWorld.getResource<TilemapAssets>();
    final visible = mainWorld
        .getResource<ActiveCameraView>()
        ?.visibleWorldRect
        ?.inflate(cullMargin);

    for (final (mapEntity, tilemap, mapTransform)
        in mainWorld.query2<Tilemap, GlobalTransform2D>().iter()) {
      final animator = mainWorld.get<TilemapAnimator>(mapEntity);

      // Find the loaded tilemap data — prefer the handle stored on the
      // component (set when spawned through Assets<TilemapAsset>), then
      // fall back to a match-by-dimensions scan of the legacy store.
      LoadedTilemap? loaded;
      final handle = tilemap.asset;
      if (handle != null) {
        loaded = handle.get();
      }
      if (loaded == null && legacyAssets != null) {
        loaded = _findLoadedTilemap(legacyAssets, tilemap);
      }
      if (loaded == null) continue;

      for (final layerEntity in mainWorld.getChildren(mapEntity)) {
        final layer = mainWorld.get<TileLayer>(layerEntity);
        if (layer == null) continue;
        if (respectVisibility &&
            !tilemap.isLayerVisible(layer.name, layer.visible)) {
          continue;
        }
        _extractLayer(
          renderWorld,
          layer,
          loaded,
          mapTransform,
          animator,
          visible,
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

  _LayerIndex _indexOf(TileLayer layer, List<TileData> tiles) {
    final cached = _indexes[layer];
    if (cached != null &&
        identical(cached.source, tiles) &&
        cached.length == tiles.length) {
      return cached;
    }
    return _indexes[layer] = _LayerIndex.build(tiles);
  }

  void _extractLayer(
    RenderWorld renderWorld,
    TileLayer layer,
    LoadedTilemap loaded,
    GlobalTransform2D mapTransform,
    TilemapAnimator? animator,
    Rect? visible,
  ) {
    final tiles = layer.tiles;
    if (tiles == null || tiles.isEmpty) return;
    final index = _indexOf(layer, tiles);
    if (index.isEmpty) return;

    final tileWidth = loaded.tileWidth.toDouble();
    final tileHeight = loaded.tileHeight.toDouble();
    final layerColor = layer.effectiveColor;
    final ox = layer.offset.dx;
    final oy = layer.offset.dy;
    final px = layer.parallax.dx;
    final py = layer.parallax.dy;
    // The map's transform, column-major (as GlobalTransform2D.transformPoint
    // applies it): world = (s0 x + s3 y + s6, s1 x + s4 y + s7).
    final m = mapTransform.matrix.storage;
    final s0 = m[0], s1 = m[1], s3 = m[3], s4 = m[4], s6 = m[6], s7 = m[7];
    final drawLayer = (layer.layerClass == 'above')
        ? DrawLayer.foreground
        : DrawLayer.ground;

    // The tiles to visit: the view mapped back into the layer's grid, or
    // every tile if there's no view (or the transform can't be undone).
    var minX = index.minX, maxX = index.maxX;
    var minY = index.minY, maxY = index.maxY;
    final det = s0 * s4 - s1 * s3;
    if (visible != null && det != 0 && px != 0 && py != 0) {
      var lowX = double.infinity, highX = double.negativeInfinity;
      var lowY = double.infinity, highY = double.negativeInfinity;
      for (final corner in [
        visible.topLeft,
        visible.topRight,
        visible.bottomLeft,
        visible.bottomRight,
      ]) {
        // Undo the map's transform, then the parallax and the offset.
        final wx = corner.dx - s6, wy = corner.dy - s7;
        final x = (s4 * wx - s3 * wy) / det / px - ox;
        final y = (-s1 * wx + s0 * wy) / det / py - oy;
        lowX = math.min(lowX, x);
        highX = math.max(highX, x);
        lowY = math.min(lowY, y);
        highY = math.max(highY, y);
      }
      // The tiles overlapping it (a tile covers [x w, (x + 1) w)); the
      // view is already widened by the cull margin.
      minX = math.max(minX, (lowX / tileWidth).floor());
      maxX = math.min(maxX, (highX / tileWidth).floor());
      minY = math.max(minY, (lowY / tileHeight).floor());
      maxY = math.min(maxY, (highY / tileHeight).floor());
    }

    for (var ty = minY; ty <= maxY; ty++) {
      for (var tx = minX; tx <= maxX; tx++) {
        final tile = index.at(tx, ty);
        if (tile == null || tile.gid == 0) continue;
        final tileset = loaded.tilesets.elementAtOrNull(tile.tilesetIndex);
        if (tileset == null) continue;

        var localId = tile.localId;
        if (tile.animated && animator != null) {
          localId = animator.getCurrentFrame(
            tileset.localIdToGid(tile.localId),
          );
        }
        if (!tileset.containsTile(localId)) continue;
        final sourceRect = tileset.getTileRect(localId);

        final lx = (tile.x * tileWidth + ox) * px;
        final ly = (tile.y * tileHeight + oy) * py;
        final worldX = s0 * lx + s3 * ly + s6;
        final worldY = s1 * lx + s4 * ly + s7;

        // Sort key based on layer class:
        // - "above" layers use DrawLayer.foreground (renders above
        //   characters)
        // - Other layers use DrawLayer.ground (renders below characters)
        // Sub-order: row * 100 + layerIndex (row first, then layer index),
        // clamped into the layer range; the unclamped value rides along as
        // the precise sub-order so rows >= 1,000 still sort by row.
        final sortKey = tileSortKey(
          drawLayer: drawLayer,
          row: tile.y,
          layerIndex: layer.layerIndex,
        );
        final preciseSubOrder = tilePreciseSubOrder(
          row: tile.y,
          layerIndex: layer.layerIndex,
        );

        renderWorld.add(
          tileToSprite(
            texture: tileset.atlas.texture,
            sourceRect: sourceRect,
            tileTopLeft: Offset(worldX, worldY),
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            color: layerColor,
            sortKey: sortKey,
            flipFlags: tile.flipFlags,
            preciseSubOrder: preciseSubOrder,
          ),
        );
        if (emitLegacyTiles) {
          renderWorld.add(
            // ignore: deprecated_member_use_from_same_package
            ExtractedTile(
              texture: tileset.atlas.texture,
              sourceRect: sourceRect,
              position: Offset(worldX, worldY),
              tileWidth: tileWidth,
              tileHeight: tileHeight,
              color: layerColor,
              sortKey: sortKey,
              flipFlags: tile.flipFlags,
              preciseSubOrder: preciseSubOrder,
            ),
          );
        }
      }
    }
  }
}

/// A layer's tiles by grid position: one cell per position over the
/// bounding box of its tiles (the last tile at a position wins).
class _LayerIndex {
  _LayerIndex._(
    this.source,
    this.length,
    this.minX,
    this.minY,
    this.maxX,
    this.maxY,
    this._cells,
  );

  static _LayerIndex build(List<TileData> tiles) {
    var minX = 1 << 30, minY = 1 << 30, maxX = -(1 << 30), maxY = -(1 << 30);
    for (final tile in tiles) {
      if (tile.gid == 0) continue;
      minX = math.min(minX, tile.x);
      minY = math.min(minY, tile.y);
      maxX = math.max(maxX, tile.x);
      maxY = math.max(maxY, tile.y);
    }
    if (maxX < minX) {
      return _LayerIndex._(tiles, tiles.length, 0, 0, -1, -1, const []);
    }
    final width = maxX - minX + 1;
    final cells = List<TileData?>.filled(width * (maxY - minY + 1), null);
    for (final tile in tiles) {
      if (tile.gid == 0) continue;
      cells[(tile.y - minY) * width + (tile.x - minX)] = tile;
    }
    return _LayerIndex._(tiles, tiles.length, minX, minY, maxX, maxY, cells);
  }

  /// The list it was built from, and its length then (a changed layer is
  /// re-indexed).
  final List<TileData> source;
  final int length;

  final int minX, minY, maxX, maxY;
  final List<TileData?> _cells;

  bool get isEmpty => maxX < minX;

  TileData? at(int x, int y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return null;
    return _cells[(y - minY) * (maxX - minX + 1) + (x - minX)];
  }
}
