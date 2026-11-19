import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

/// A two-tile sheet: tile 0 has a collision rectangle across its top,
/// tile 1 has none.
const _tsx = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="ground" tilewidth="32" tileheight="32" tilecount="2" columns="2">
 <image source="ground.png" width="64" height="32"/>
 <tile id="0">
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="0" width="32" height="20"/>
  </objectgroup>
 </tile>
</tileset>''';

// Row 0: tile 0 twice (they merge), nothing, tile 1 (no collision).
// Row 1: tile 0 flipped horizontally, nothing, flipped vertically, and
// flipped diagonally (Tiled's flip bits 0x80000000, 0x40000000,
// 0x20000000 over gid 1).
const _tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="4" height="2" tilewidth="32" tileheight="32" infinite="0" nextlayerid="3" nextobjectid="1">
 <tileset firstgid="1" source="ground.tsx"/>
 <layer id="1" name="walls" width="4" height="2">
  <data encoding="csv">
1,1,0,2,
2147483649,0,1073741825,536870913
</data>
 </layer>
 <layer id="2" name="decor" width="4" height="2">
  <data encoding="csv">
0,0,1,0,
0,0,0,0
</data>
 </layer>
</map>''';

Future<LoadedTilemap> _load() =>
    AssetTilemapLoader(
      loadStringContent: (path) async => switch (path) {
        'assets/maps/dome.tmx' => _tmx,
        'assets/maps/ground.tsx' => _tsx,
        _ => throw StateError('unexpected $path'),
      },
    ).load(
      'assets/maps/dome.tmx',
      (path, w, h) async => TextureHandle(id: 1, width: w, height: h),
    );

/// The rectangles the tile layers' colliders hold, by layer name.
Future<Map<String, List<(double, double, double, double)>>> _colliders({
  Set<String>? layers,
}) async {
  final map = await _load();
  final app = App()..addPlugin(TiledPlugin());
  final out = <String, List<(double, double, double, double)>>{};
  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent.fromHandle(
      app.world.getResource<Assets<TilemapAsset>>()!.add(map),
      config: TilemapSpawnConfig(
        tileConfig: TileLayerConfig(
          generateColliders: true,
          colliderLayers: layers,
          onColliderSpawn: (entity, layer, collider) {
            out[layer] = [
              for (final s in collider.shapes.cast<RectangleShape>())
                (s.x, s.y, s.width, s.height),
            ];
          },
        ),
      ),
    ),
  );
  await app.tick();
  return out;
}

void main() {
  test('a tile layer gathers its tiles\' collision, neighbours merged and '
      'flipped tiles flipped', () async {
    final walls = (await _colliders())['walls']!;
    expect(
      walls,
      unorderedEquals([
        // Row 0: the two plain tiles, merged; tile 1 adds nothing.
        (0.0, 0.0, 64.0, 20.0),
        // Flipped horizontally: the full-width rectangle stays put.
        (0.0, 32.0, 32.0, 20.0),
        // Flipped vertically: along the tile's bottom.
        (64.0, 44.0, 32.0, 20.0),
        // Flipped diagonally (a transpose): down the tile's left side.
        (96.0, 32.0, 20.0, 32.0),
      ]),
    );
  });

  test('colliderLayers picks the layers that block', () async {
    final all = await _colliders();
    expect(all.keys, containsAll(['walls', 'decor']));
    final some = await _colliders(layers: {'walls'});
    expect(some.keys, ['walls']);
  });

  test('flipShapes mirrors rectangles inside the tile and leaves the rest', () {
    const rect = RectangleShape(x: 2, y: 4, width: 10, height: 6);
    List<(double, double, double, double)> flip({
      bool h = false,
      bool v = false,
      bool d = false,
    }) => [
      for (final s in TileCollider.flipShapes(
        [rect],
        tileWidth: 32,
        tileHeight: 32,
        horizontal: h,
        vertical: v,
        diagonal: d,
      ).cast<RectangleShape>())
        (s.x, s.y, s.width, s.height),
    ];
    expect(flip(), [(2.0, 4.0, 10.0, 6.0)]);
    expect(flip(h: true), [(20.0, 4.0, 10.0, 6.0)]);
    expect(flip(v: true), [(2.0, 22.0, 10.0, 6.0)]);
    expect(flip(d: true), [(4.0, 2.0, 6.0, 10.0)]);
    // Rotated 90 degrees clockwise in Tiled: diagonal then horizontal.
    expect(flip(d: true, h: true), [(22.0, 2.0, 6.0, 10.0)]);
    const point = PointShape(x: 1, y: 1);
    expect(
      TileCollider.flipShapes(
        [point],
        tileWidth: 32,
        tileHeight: 32,
        horizontal: true,
      ),
      [point],
    );
  });
}
