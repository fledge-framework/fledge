// ExtractedTile is deprecated but still emitted; this test checks it.
// ignore_for_file: deprecated_member_use

import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled/tiled.dart' as tiled;
import 'package:vector_math/vector_math.dart';

/// Tiled used to pack `row * 100 + layerIndex` into the sort key with
/// no clamp, so from tile row 1,000 the sub-order spilled into the next
/// DrawLayer (ground tiles drew over characters, and so on). The packed
/// key is now clamped into the layer range and the unclamped value
/// rides along as the precise sub-order.

const _tileSize = 16;
const _mapWidth = 4;
const _mapHeight = 6000;
const _rows = [0, 999, 1000, 5000];
const _texture = TextureHandle(id: 3, width: 32, height: 16);

// One tint per Tiled layer so extracted output can be traced back.
const _layerColors = [
  Color(0xFF000010), // layer 0, ground
  Color(0xFF000020), // layer 1, ground
  Color(0xFF000030), // layer 2, class="above" -> foreground
];

LoadedTilemap _loaded() => LoadedTilemap(
  map: tiled.TiledMap(
    width: _mapWidth,
    height: _mapHeight,
    tileWidth: _tileSize,
    tileHeight: _tileSize,
  ),
  tilesets: [
    LoadedTileset(
      source: 'test.tsx',
      name: 'test',
      firstGid: 1,
      tileWidth: _tileSize,
      tileHeight: _tileSize,
      columns: 2,
      tileCount: 2,
      atlas: TextureAtlas.grid(texture: _texture, columns: 2, rows: 1),
    ),
  ],
  animations: const {},
  sourcePath: 'test.tmx',
);

World _world({TilemapAnimator? animator}) {
  final world = World();
  final loaded = _loaded();
  world.insertResource(TilemapAssets()..put('map', loaded));
  final map = world.spawn()
    ..insert(Tilemap.fromTiledMap(loaded.map))
    ..insert(GlobalTransform2D.identity());
  if (animator != null) map.insert(animator);
  for (var index = 0; index < _layerColors.length; index++) {
    world
        .spawnChild(map.entity)
        .insert(
          TileLayer(
            name: 'layer$index',
            layerIndex: index,
            tiledLayer: tiled.TileLayer(
              name: 'layer$index',
              width: _mapWidth,
              height: _mapHeight,
            ),
            tintColor: _layerColors[index],
            layerClass: index == 2 ? 'above' : null,
            tiles: [
              for (final row in _rows)
                TileData(
                  gid: 1,
                  x: 0,
                  y: row,
                  tilesetIndex: 0,
                  localId: 0,
                  animated: animator != null,
                ),
            ],
          ),
        );
  }
  return world;
}

/// (row, layerIndex) of a tile from its centre y and tint.
(int, int) _id(double centreY, Color color) =>
    ((centreY - _tileSize / 2) ~/ _tileSize, _layerColors.indexOf(color));

void main() {
  for (final (name, extractor) in <(String, Extractor Function())>[
    ('TilemapExtractor', TilemapExtractor.new),
    ('CulledTilemapExtractor', CulledTilemapExtractor.new),
  ]) {
    group(name, () {
      late List<ExtractedSprite> sprites;
      late List<ExtractedTile> tiles;

      setUp(() {
        final renderWorld = RenderWorld();
        extractor().extract(_world(), renderWorld);
        sprites = [
          for (final (_, s) in renderWorld.query1<ExtractedSprite>().iter()) s,
        ];
        tiles = [
          for (final (_, t) in renderWorld.query1<ExtractedTile>().iter()) t,
        ];
      });

      final expectedOrder = [
        // Ground: by row, then layer index.
        for (final row in _rows) ...[(row, 0), (row, 1)],
        // class="above" layer: foreground, after every ground tile.
        for (final row in _rows) (row, 2),
      ];

      test('rows 999 / 1,000 / 5,000 stay inside their DrawLayer', () {
        expect(sprites, hasLength(expectedOrder.length));
        expect(tiles, hasLength(expectedOrder.length));
        for (final s in sprites) {
          final (_, layerIndex) = _id(s.transform.storage[7], s.color);
          final layer = layerIndex == 2
              ? DrawLayer.foreground
              : DrawLayer.ground;
          expect(s.layer, layer);
          expect(s.sortKey ~/ DrawLayerExtension.layerMultiplier, layer.index);
        }
        for (final t in tiles) {
          final (_, layerIndex) = _id(t.position.dy + _tileSize / 2, t.color);
          final layer = layerIndex == 2
              ? DrawLayer.foreground
              : DrawLayer.ground;
          expect(t.sortKey ~/ DrawLayerExtension.layerMultiplier, layer.index);
        }
      });

      test('ExtractedSprite path sorts by row, then layer index', () {
        ExtractedSprite.sortByDrawOrder(sprites);
        expect([
          for (final s in sprites) _id(s.transform.storage[7], s.color),
        ], expectedOrder);
      });

      test('deprecated ExtractedTile path sorts by row, then layer index', () {
        tiles.sort(ExtractedTile.compareDrawOrder);
        expect([
          for (final t in tiles) _id(t.position.dy + _tileSize / 2, t.color),
        ], expectedOrder);
        // Both paths carry the same keys.
        expect(
          {for (final t in tiles) (t.sortKey, t.preciseSubOrder)},
          {for (final s in sprites) (s.sortKey, s.preciseSubOrder)},
        );
      });

      test('keys below row 1,000 are unchanged', () {
        final s = sprites.firstWhere(
          (s) => _id(s.transform.storage[7], s.color) == (999, 1),
        );
        expect(s.sortKey, DrawLayer.ground.sortKey(subOrder: 99901));
        expect(s.preciseSubOrder, 99901);
      });

      test('above layer still sorts above characters at any y', () {
        ExtractedSprite character(double y) => ExtractedSprite(
          entity: Entity.placeholder,
          texture: _texture,
          sourceRect: const Rect.fromLTWH(0, 0, 16, 16),
          transform: Matrix3.identity()..setEntry(1, 2, y),
          color: const Color(0xFFFFFFFF),
          sortKey: DrawLayer.characters.sortKey(
            subOrder: DrawLayerExtension.ySortSubOrder(y),
          ),
          preciseSubOrder: y * DrawLayerExtension.ySortScale,
          anchor: Vector2(0.5, 0.5),
          size: Vector2(16, 16),
        );
        final all = [
          ...sprites,
          character(0),
          character(1000 * 16.0),
          character(5000 * 16.0 + 8),
        ];
        ExtractedSprite.sortByDrawOrder(all);
        expect(
          [for (final s in all) s.layer],
          [
            for (var i = 0; i < 8; i++) DrawLayer.ground,
            for (var i = 0; i < 3; i++) DrawLayer.characters,
            for (var i = 0; i < 4; i++) DrawLayer.foreground,
          ],
        );
      });
    });
  }

  test('tile animation still swaps the source rect', () {
    final renderWorld = RenderWorld();
    // gid 1 -> frame showing local tile 1 (second column).
    final animator = TilemapAnimator(
      animations: {
        1: TileAnimation(frames: [TileAnimationFrame(tileId: 1, duration: 1)]),
      },
    );
    TilemapExtractor().extract(_world(animator: animator), renderWorld);
    final rects = {
      for (final (_, s) in renderWorld.query1<ExtractedSprite>().iter())
        s.sourceRect,
    };
    expect(rects, {const Rect.fromLTWH(16, 0, 16, 16)});
  });

  group('tileSortKey / tilePreciseSubOrder', () {
    test('clamp into the layer and keep the composite order', () {
      expect(
        tileSortKey(drawLayer: DrawLayer.ground, row: 10, layerIndex: 3),
        DrawLayer.ground.sortKey(subOrder: 1003),
      );
      expect(
        tileSortKey(drawLayer: DrawLayer.ground, row: 1000, layerIndex: 0),
        DrawLayer.ground.sortKey(subOrder: 99999),
      );
      expect(
        tileSortKey(
          drawLayer: DrawLayer.foreground,
          row: 100000,
          layerIndex: 5,
        ),
        DrawLayer.foreground.sortKey(subOrder: 99999),
      );
      expect(tilePreciseSubOrder(row: 5000, layerIndex: 2), 500002);
    });

    test('tileToSprite carries the precise sub-order', () {
      final s = tileToSprite(
        texture: _texture,
        sourceRect: const Rect.fromLTWH(0, 0, 16, 16),
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: tileSortKey(
          drawLayer: DrawLayer.ground,
          row: 2000,
          layerIndex: 1,
        ),
        flipFlags: 0,
        preciseSubOrder: tilePreciseSubOrder(row: 2000, layerIndex: 1),
      );
      expect(s.layer, DrawLayer.ground);
      expect(s.preciseSubOrder, 200001);
    });
  });
}
