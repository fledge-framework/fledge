import 'dart:ui' show Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled/tiled.dart' as tiled;

const _tile = 16;
const _texture = TextureHandle(id: 3, width: 32, height: 16);

/// A 100x100 map with a tile in every cell.
World _world() {
  final world = World();
  final loaded = LoadedTilemap(
    map: tiled.TiledMap(
      width: 100,
      height: 100,
      tileWidth: _tile,
      tileHeight: _tile,
    ),
    tilesets: [
      LoadedTileset(
        source: 'test.tsx',
        name: 'test',
        firstGid: 1,
        tileWidth: _tile,
        tileHeight: _tile,
        columns: 2,
        tileCount: 2,
        atlas: TextureAtlas.grid(texture: _texture, columns: 2, rows: 1),
      ),
    ],
    animations: const {},
    sourcePath: 'test.tmx',
  );
  world.insertResource(TilemapAssets()..put('map', loaded));
  final map = world.spawn()
    ..insert(Tilemap.fromTiledMap(loaded.map))
    ..insert(GlobalTransform2D.identity());
  world
      .spawnChild(map.entity)
      .insert(
        TileLayer(
          name: 'ground',
          layerIndex: 0,
          tiledLayer: tiled.TileLayer(name: 'ground', width: 100, height: 100),
          tiles: [
            for (var y = 0; y < 100; y++)
              for (var x = 0; x < 100; x++)
                TileData(gid: 1, x: x, y: y, localId: 0, tilesetIndex: 0),
          ],
        ),
      );
  return world;
}

int _sprites(World world) {
  final renderWorld = RenderWorld();
  TilemapExtractor().extract(world, renderWorld);
  return renderWorld.query1<ExtractedSprite>().iter().length;
}

void main() {
  test('without a camera view every tile is extracted', () {
    expect(_sprites(_world()), 100 * 100);
  });

  test('before the first paint every tile is extracted', () {
    final world = _world()..insertResource(ActiveCameraView(x: 800, y: 800));
    expect(_sprites(world), 100 * 100);
  });

  test('with a known view only tiles near it are extracted', () {
    final world = _world()
      ..insertResource(
        ActiveCameraView(x: 800, y: 800)..viewportSize = const Size(320, 160),
      );
    final count = _sprites(world);
    // The view plus the margin on each side, in tiles, give or take an edge.
    const across = (320 + 2 * TilemapExtractor.defaultCullMargin) / _tile + 1;
    const down = (160 + 2 * TilemapExtractor.defaultCullMargin) / _tile + 1;
    expect(count, lessThanOrEqualTo((across + 1) * (down + 1)));
    expect(count, greaterThan(across * down * 0.8));
  });
}
