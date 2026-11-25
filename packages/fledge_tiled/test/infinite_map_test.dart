import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 16x16 chunk at ([x], [y]) holding [gid] at the given local cells.
String _chunk(int x, int y, Map<(int, int), int> cells) {
  final rows = [
    for (var ly = 0; ly < 16; ly++)
      [for (var lx = 0; lx < 16; lx++) cells[(lx, ly)] ?? 0].join(','),
  ];
  return '<chunk x="$x" y="$y" width="16" height="16">'
      '${rows.join(',\n')}</chunk>';
}

/// An infinite map whose `Collision` layer has a tile in the chunk up
/// and left of the origin (at tile (-1, -1)) and one in the chunk at the
/// origin (tile (2, 1), flipped horizontally).
final _tmx =
    '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="4" height="4" tilewidth="16" tileheight="16" infinite="1" nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" name="t" tilewidth="16" tileheight="16" tilecount="4" columns="2">
  <image source="t.png" width="32" height="32"/>
 </tileset>
 <layer id="1" name="Collision" width="4" height="4">
  <data encoding="csv">
${_chunk(-16, -16, {(15, 15): 1})}
${_chunk(0, 0, {(2, 1): 0x80000002})}
  </data>
 </layer>
</map>''';

Future<LoadedTilemap> _load() =>
    AssetTilemapLoader(
      loadStringContent: (path) async => switch (path) {
        'assets/maps/infinite.tmx' => _tmx,
        _ => throw StateError('unexpected $path'),
      },
    ).load(
      'assets/maps/infinite.tmx',
      (path, w, h) async => TextureHandle(id: 1, width: w, height: h),
    );

void main() {
  test('an infinite map spawns the tiles of its chunks, at their tile '
      'coordinates', () async {
    final app = App()..addPlugin(TiledPlugin());
    app.world.eventWriter<SpawnTilemapEvent>().send(
      SpawnTilemapEvent.fromHandle(
        app.world.getResource<Assets<TilemapAsset>>()!.add(await _load()),
      ),
    );
    await app.tick();

    final layer = app.world.query1<TileLayer>().iter().single.$2;
    expect([
      for (final t in layer.tiles!) (t.x, t.y, t.localId, t.flipHorizontal),
    ], unorderedEquals([(-1, -1, 0, false), (2, 1, 1, true)]));
    expect(
      layer.chunks!.keys,
      unorderedEquals(const [ChunkKey(-1, -1), ChunkKey(0, 0)]),
    );
    expect(layer.chunks![const ChunkKey(-1, -1)]!.worldX, -256);

    // And they're drawn.
    final renderWorld = RenderWorld();
    TilemapExtractor().extract(app.world, renderWorld);
    final centres = {
      for (final s in renderWorld.extractedSprites)
        (s.transform.storage[6], s.transform.storage[7]),
    };
    expect(centres, {(-8.0, -8.0), (40.0, 24.0)});
  });

  test('extractCollisionGrid covers an infinite map\'s chunks from their '
      'top-left tile', () async {
    final map = await _load();
    final origin = collisionGridOrigin(map);
    expect(origin, (x: -16, y: -16));

    final grid = extractCollisionGrid(map);
    expect((grid.width, grid.height), (32, 32));
    expect(grid.blockedCount, 2);
    expect(grid.isBlocked(-1 - origin.x, -1 - origin.y), isTrue);
    expect(grid.isBlocked(2 - origin.x, 1 - origin.y), isTrue);
  });

  test('extractCollisionGridFromTmx reads chunks inside the grid', () {
    final grid = extractCollisionGridFromTmx(_tmx, mapWidth: 4, mapHeight: 4);
    expect(grid.blockedCount, 1);
    expect(grid.isBlocked(2, 1), isTrue);
  });

  test('extractCollisionGridFromTmx throws on content that is not a map, '
      'instead of returning an all-walkable grid', () {
    expect(
      () =>
          extractCollisionGridFromTmx('<map><layer', mapWidth: 4, mapHeight: 4),
      throwsA(anything),
    );
    expect(
      () =>
          extractCollisionGridFromTmx('<tileset/>', mapWidth: 4, mapHeight: 4),
      throwsA(anything),
    );
  });

  test('a finite map\'s grid is still the map, from tile (0, 0)', () async {
    final map =
        await AssetTilemapLoader(
          loadStringContent: (path) async =>
              '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="3" height="2" tilewidth="16" tileheight="16" infinite="0" nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" name="t" tilewidth="16" tileheight="16" tilecount="4" columns="2">
  <image source="t.png" width="32" height="32"/>
 </tileset>
 <layer id="1" name="Collision" width="3" height="2">
  <data encoding="csv">
0,1,0,
0,0,1
</data>
 </layer>
</map>''',
        ).load(
          'assets/maps/finite_grid.tmx',
          (path, w, h) async => TextureHandle(id: 1, width: w, height: h),
        );
    expect(collisionGridOrigin(map), (x: 0, y: 0));
    final grid = extractCollisionGrid(map);
    expect((grid.width, grid.height), (3, 2));
    expect(grid.isBlocked(1, 0) && grid.isBlocked(2, 1), isTrue);
    expect(grid.blockedCount, 2);
  });
}
