import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show
        ActiveCameraView,
        DrawLayer,
        DrawLayerExtension,
        Extractor,
        ExtractedSprite,
        GlobalTransform2D,
        RenderWorld;

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
/// transform, the layer's parallax shift and offset), so the cost follows
/// what's on screen, not the size of the maps. The index is rebuilt when a
/// layer's `tiles` list is replaced or changes length, so edit tiles by
/// replacing the list: changing a `TileData` in place isn't seen.
///
/// Tiles are drawn at their image's size, anchored at their cell's
/// bottom-left and moved by the tileset's tile offset, as Tiled draws them,
/// so tiles taller or wider than the map grid and image-collection tiles
/// (each drawn from its own texture) come out right.
///
/// Layer parallax works as in Tiled: a layer with parallax factor `p` moves
/// `p` times as fast as the camera, which means it is shifted by
/// `camera * (1 - p)` (in the map's own coordinates). Without an
/// [ActiveCameraView] there is no shift.
///
/// Each tile's `ExtractedSprite` is built once and kept with the index
/// (nothing downstream changes an extracted sprite), and added again every
/// frame it's in view; animated tiles are built afresh. The kept sprites are
/// dropped when what they were built from changes: the map's transform, or
/// the layer's colour, offset or parallax shift.
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
    final camera = mainWorld.getResource<ActiveCameraView>();
    final visible = camera?.visibleWorldRect?.inflate(cullMargin);

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

      final layers = mainWorld.getChildren(mapEntity);
      // A whole map nowhere near the view is skipped before its layers.
      if (visible != null &&
          _farFromView(mainWorld, tilemap, layers, mapTransform, visible)) {
        continue;
      }

      for (final layerEntity in layers) {
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
          camera,
        );
      }
    }
  }

  final Expando<_MapBounds> _bounds = Expando('tilemap bounds');

  /// Whether [tilemap]'s whole area, in the world, misses [visible]. Only
  /// for finite maps drawn without parallax and without rotation
  /// (anything else is never skipped here); layer offsets widen the area.
  bool _farFromView(
    World world,
    Tilemap tilemap,
    Iterable<Entity> layers,
    GlobalTransform2D mapTransform,
    Rect visible,
  ) {
    // An infinite map's chunks reach outside its nominal size.
    if (tilemap.infinite) return false;
    final bounds = _bounds[tilemap] ??= _MapBounds.of(world, layers);
    if (!bounds.plain) return false;
    final m = mapTransform.matrix.storage;
    if (m[1] != 0 || m[3] != 0) return false;
    final w = tilemap.width * tilemap.tileWidth.toDouble();
    final h = tilemap.height * tilemap.tileHeight.toDouble();
    final x0 = m[6], x1 = m[6] + m[0] * w;
    final y0 = m[7], y1 = m[7] + m[4] * h;
    final area = Rect.fromLTRB(
      math.min(x0, x1) - bounds.pad,
      math.min(y0, y1) - bounds.pad,
      math.max(x0, x1) + bounds.pad,
      math.max(y0, y1) + bounds.pad,
    );
    return !area.overlaps(visible);
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

  final Expando<({int cols, int rows})> _reaches = Expando('tile reach');

  /// How many cells beyond its own a tile of [loaded] can draw into: tiles
  /// bigger than the map grid, and tile offsets.
  ({int cols, int rows}) _reachOf(LoadedTilemap loaded) =>
      _reaches[loaded] ??= () {
        var extraW = 0.0, extraH = 0.0;
        for (final tileset in loaded.tilesets) {
          var w = tileset.tileWidth.toDouble();
          var h = tileset.tileHeight.toDouble();
          for (final image in tileset.tileImages.values) {
            w = math.max(w, image.width.toDouble());
            h = math.max(h, image.height.toDouble());
          }
          // A diagonal flip swaps a tile's width and height.
          final size = math.max(w, h);
          extraW = math.max(
            extraW,
            size - loaded.tileWidth + tileset.tileOffset.dx.abs(),
          );
          extraH = math.max(
            extraH,
            size - loaded.tileHeight + tileset.tileOffset.dy.abs(),
          );
        }
        return (
          cols: (math.max(0.0, extraW) / loaded.tileWidth).ceil(),
          rows: (math.max(0.0, extraH) / loaded.tileHeight).ceil(),
        );
      }();

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
    ActiveCameraView? camera,
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
    final det = s0 * s4 - s1 * s3;

    // Parallax: the layer is shifted by camera * (1 - p), with the camera's
    // centre taken into the map's own coordinates.
    var shiftX = 0.0, shiftY = 0.0;
    if (camera != null && (px != 1 || py != 1) && det != 0) {
      final wx = camera.x - s6, wy = camera.y - s7;
      final camX = (s4 * wx - s3 * wy) / det;
      final camY = (-s1 * wx + s0 * wy) / det;
      shiftX = camX * (1 - px);
      shiftY = camY * (1 - py);
    }
    final drawLayer = (layer.layerClass == 'above')
        ? DrawLayer.foreground
        : DrawLayer.ground;

    // The tiles to visit: the view mapped back into the layer's grid, or
    // every tile if there's no view (or the transform can't be undone).
    var minX = index.minX, maxX = index.maxX;
    var minY = index.minY, maxY = index.maxY;
    if (visible != null && det != 0) {
      var lowX = double.infinity, highX = double.negativeInfinity;
      var lowY = double.infinity, highY = double.negativeInfinity;
      // The view's four corners (no list: this runs for every layer).
      for (var c = 0; c < 4; c++) {
        final cx = c.isEven ? visible.left : visible.right;
        final cy = c < 2 ? visible.top : visible.bottom;
        // Undo the map's transform, then the parallax shift and offset.
        final wx = cx - s6, wy = cy - s7;
        final x = (s4 * wx - s3 * wy) / det - shiftX - ox;
        final y = (-s1 * wx + s0 * wy) / det - shiftY - oy;
        lowX = math.min(lowX, x);
        highX = math.max(highX, x);
        lowY = math.min(lowY, y);
        highY = math.max(highY, y);
      }
      // The tiles overlapping it (a tile covers [x w, (x + 1) w)); the
      // view is already widened by the cull margin.
      // Tiles bigger than a cell, or moved by a tile offset, reach into
      // neighbouring cells: widen the range by that reach.
      final reach = _reachOf(loaded);
      minX = math.max(minX, (lowX / tileWidth).floor() - reach.cols);
      maxX = math.min(maxX, (highX / tileWidth).floor() + reach.cols);
      minY = math.max(minY, (lowY / tileHeight).floor() - reach.rows);
      maxY = math.min(maxY, (highY / tileHeight).floor() + reach.rows);
    }

    // The kept sprites, unless what they were built from has changed.
    index.keepFor(mapTransform, layerColor, ox + shiftX, oy + shiftY);

    for (var ty = minY; ty <= maxY; ty++) {
      for (var tx = minX; tx <= maxX; tx++) {
        final cell = index.cellOf(tx, ty);
        if (cell < 0) continue;
        final kept = index.sprites[cell];
        if (kept != null) {
          renderWorld.addSprite(kept);
          continue;
        }
        final tile = index.tileAt(cell);
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
        final texture = tileset.getTileTexture(localId);
        final sourceRect = tileset.getTileRect(localId);

        final lx = tile.x * tileWidth + ox + shiftX;
        final ly = tile.y * tileHeight + oy + shiftY;
        final worldX = s0 * lx + s3 * ly + s6;
        final worldY = s1 * lx + s4 * ly + s7;

        // Sort key based on layer class:
        // - "above" layers use DrawLayer.foreground (renders above
        //   characters)
        // - Other layers use DrawLayer.ground (renders below characters)
        // Sub-order: row * 100 + layerIndex (row first, then layer index),
        // clamped into the layer range; the unclamped value rides along as
        // the precise sub-order so rows >= 1,000 still sort by row.
        // A `y_sort` tile on a layer under the characters is drawn among
        // them instead, sorted at its line (its collision's bottom): a
        // wall's base, so whoever stands behind it is drawn behind it.
        final line = drawLayer == DrawLayer.ground
            ? tileset.ySortLine(tile.localId, tile.flipFlags)
            : null;
        final int sortKey;
        final double preciseSubOrder;
        if (line != null) {
          // The line is measured from the image's top; the image sits on
          // the cell's bottom edge, moved by the tile offset.
          final diagonal = tile.flipFlags & 4 != 0;
          final imageHeight = diagonal ? sourceRect.width : sourceRect.height;
          final boxHeight = imageHeight > 0 ? imageHeight : tileHeight;
          final top = tileHeight - boxHeight + tileset.tileOffset.dy;
          final lineY = worldY + s4 * (top + line);
          sortKey = DrawLayer.characters.sortKey(
            subOrder: DrawLayerExtension.ySortSubOrder(lineY),
          );
          preciseSubOrder = lineY * DrawLayerExtension.ySortScale;
        } else {
          sortKey = tileSortKey(
            drawLayer: drawLayer,
            row: tile.y,
            layerIndex: layer.layerIndex,
          );
          preciseSubOrder = tilePreciseSubOrder(
            row: tile.y,
            layerIndex: layer.layerIndex,
          );
        }

        final sprite = tileToSprite(
          texture: texture,
          sourceRect: sourceRect,
          tileTopLeft: Offset(worldX, worldY),
          tileWidth: tileWidth,
          tileHeight: tileHeight,
          color: layerColor,
          sortKey: sortKey,
          flipFlags: tile.flipFlags,
          preciseSubOrder: preciseSubOrder,
          drawOffset: tileset.tileOffset,
        );
        // An animated tile's frame changes: built every time.
        if (!tile.animated) index.sprites[cell] = sprite;
        renderWorld.addSprite(sprite);
        if (emitLegacyTiles) {
          renderWorld.add(
            // ignore: deprecated_member_use_from_same_package
            ExtractedTile(
              texture: texture,
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

/// What decides whether a map can be skipped as a whole: no layer has
/// parallax ([plain]), and how far its layers are offset ([pad]).
class _MapBounds {
  _MapBounds(this.plain, this.pad);

  static _MapBounds of(World world, Iterable<Entity> layers) {
    var plain = true;
    var pad = 0.0;
    for (final entity in layers) {
      final layer = world.get<TileLayer>(entity);
      if (layer == null) continue;
      if (layer.parallax.dx != 1 || layer.parallax.dy != 1) plain = false;
      pad = math.max(
        pad,
        math.max(layer.offset.dx.abs(), layer.offset.dy.abs()),
      );
    }
    return _MapBounds(plain, pad);
  }

  final bool plain;
  final double pad;
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

  /// Each cell's sprite, once built (see [keepFor]).
  late final List<ExtractedSprite?> sprites = List.filled(_cells.length, null);

  bool get isEmpty => maxX < minX;

  /// The cell at grid position ([x], [y]), or -1 outside the layer.
  int cellOf(int x, int y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return -1;
    return (y - minY) * (maxX - minX + 1) + (x - minX);
  }

  TileData? tileAt(int cell) => _cells[cell];

  TileData? at(int x, int y) {
    final cell = cellOf(x, y);
    return cell < 0 ? null : _cells[cell];
  }

  // What the kept sprites were built from.
  GlobalTransform2D? _transform;
  int _transformVersion = -1;
  final _matrix = List<double>.filled(9, double.nan);
  Color? _color;
  double _ox = double.nan, _oy = double.nan;

  /// Drops the kept sprites if the map's transform, the layer's colour, or
  /// its total offset (offset plus parallax shift) differ from what they
  /// were built from.
  void keepFor(GlobalTransform2D transform, Color color, double ox, double oy) {
    final m = transform.matrix.storage;
    var same =
        identical(transform, _transform) &&
        transform.version == _transformVersion &&
        color == _color &&
        ox == _ox &&
        oy == _oy;
    // A transform set by hand doesn't bump its version: compare the matrix.
    for (var i = 0; same && i < 9; i++) {
      same = m[i] == _matrix[i];
    }
    if (same) return;
    sprites.fillRange(0, sprites.length, null);
    _transform = transform;
    _transformVersion = transform.version;
    for (var i = 0; i < 9; i++) {
      _matrix[i] = m[i];
    }
    _color = color;
    _ox = ox;
    _oy = oy;
  }
}
