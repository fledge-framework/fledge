import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled/tiled.dart' as tiled;

void main() {
  test('a tile bigger than the map grid is drawn at its own size, on its '
      'cell\'s bottom-left corner', () {
    final world = World();
    final loaded = LoadedTilemap(
      map: tiled.TiledMap(width: 4, height: 4, tileWidth: 16, tileHeight: 16),
      tilesets: [
        LoadedTileset(
          source: 'trees.tsx',
          name: 'trees',
          firstGid: 1,
          tileWidth: 32,
          tileHeight: 48,
          columns: 1,
          tileCount: 1,
          atlas: TextureAtlas.grid(
            texture: const TextureHandle(id: 2, width: 32, height: 48),
            columns: 1,
            rows: 1,
          ),
        ),
      ],
      animations: const {},
      sourcePath: 'forest.tmx',
    );
    world.insertResource(TilemapAssets()..put('map', loaded));
    final map = world.spawn()
      ..insert(Tilemap.fromTiledMap(loaded.map))
      ..insert(GlobalTransform2D.identity());
    world
        .spawnChild(map.entity)
        .insert(
          TileLayer(
            name: 'trees',
            layerIndex: 0,
            tiledLayer: tiled.TileLayer(name: 'trees', width: 4, height: 4),
            tiles: const [
              TileData(gid: 1, x: 1, y: 2, localId: 0, tilesetIndex: 0),
            ],
          ),
        );

    final renderWorld = RenderWorld();
    TilemapExtractor().extract(world, renderWorld);
    final sprite = renderWorld.extractedSprites.single;
    expect((sprite.size.x, sprite.size.y), (32.0, 48.0));
    // Cell (1, 2) spans x 16..32, y 32..48: the tree's box is x 16..48,
    // y 0..48.
    expect(
      (sprite.transform.storage[6], sprite.transform.storage[7]),
      (32.0, 24.0),
    );
  });
}
