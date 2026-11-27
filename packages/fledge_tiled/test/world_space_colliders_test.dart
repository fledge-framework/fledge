import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show TextureHandle, Transform2D;
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

/// One 32 px tile, solid all over.
const _tsx = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="ground" tilewidth="32" tileheight="32" tilecount="1" columns="1">
 <image source="ground.png" width="32" height="32"/>
 <tile id="0">
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="0" width="32" height="32"/>
  </objectgroup>
 </tile>
</tileset>''';

/// A 32x64 tile on a 32 px grid, drawn 4 px right and 2 px down
/// (`<tileoffset>`), blocking a 10 px band across its top.
const _tallTsx = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="tall" tilewidth="32" tileheight="64" tilecount="1" columns="1">
 <tileoffset x="4" y="2"/>
 <image source="tall.png" width="32" height="64"/>
 <tile id="0">
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="0" width="32" height="10"/>
  </objectgroup>
 </tile>
</tileset>''';

// A wall tile at cell (1, 1) on a layer inside a group offset by (8, 4)
// and itself offset by (2, 0); a `block` object at (10, 10) on an object
// layer offset by (0, 6); the tall tile at cell (2, 2).
const _tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="4" height="4" tilewidth="32" tileheight="32" infinite="0" nextlayerid="5" nextobjectid="2">
 <tileset firstgid="1" source="ground.tsx"/>
 <tileset firstgid="2" source="tall.tsx"/>
 <group id="1" name="g" offsetx="8" offsety="4" opacity="0.5" tintcolor="#ff8080" visible="1">
  <layer id="2" name="walls" width="4" height="4" offsetx="2" opacity="0.5" tintcolor="#80ffff">
   <data encoding="csv">
0,0,0,0,
0,1,0,0,
0,0,0,0,
0,0,0,0
</data>
  </layer>
 </group>
 <group id="3" name="hidden" visible="0">
  <objectgroup id="4" name="things" offsety="6">
   <object id="1" type="block" x="10" y="10" width="16" height="16"/>
  </objectgroup>
 </group>
 <layer id="5" name="tall" width="4" height="4">
  <data encoding="csv">
0,0,0,0,
0,0,0,0,
0,0,2,0,
0,0,0,0
</data>
 </layer>
</map>''';

Future<LoadedTilemap> _load() =>
    AssetTilemapLoader(
      loadStringContent: (path) async => switch (path) {
        'assets/maps/m.tmx' => _tmx,
        'assets/maps/ground.tsx' => _tsx,
        'assets/maps/tall.tsx' => _tallTsx,
        _ => throw StateError('unexpected $path'),
      },
    ).load(
      'assets/maps/m.tmx',
      (path, w, h) async => TextureHandle(id: 1, width: w, height: h),
    );

const _position = Offset(1000, 500);

Future<App> _spawn() async {
  final map = await _load();
  final app = App()
    ..addPlugin(TiledPlugin())
    ..addPlugin(const PhysicsPlugin());
  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent.fromHandle(
      app.world.getResource<Assets<TilemapAsset>>()!.add(map),
      position: _position,
      config: TilemapSpawnConfig(
        tileConfig: const TileLayerConfig(generateColliders: true),
        objectTypes: {'block': const ObjectTypeConfig()},
      ),
    ),
  );
  await app.tick();
  return app;
}

/// Whether a 2x2 probe at world ([x], [y]) collides with anything.
bool _hits(App app, double x, double y) {
  final probe = app.world.spawn()
    ..insert(Transform2D.from(x, y))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 2, height: 2)));
  app.world.updateEvents();
  const CollisionDetectionSystem().run(app.world);
  // Sent events are readable after the next swap.
  app.world.updateEvents();
  final hit = app.world.eventReader<CollisionEvent>().read().any(
    (e) => e.entityA == probe.entity || e.entityB == probe.entity,
  );
  app.world.despawn(probe.entity);
  return hit;
}

void main() {
  test('tile colliders sit where the tiles are drawn: the map\'s position '
      'and the layer\'s (and its group\'s) offsets included', () async {
    final app = await _spawn();
    // The wall's cell (1, 1) is drawn at map (32, 32) + offsets (10, 4).
    final left = _position.dx + 32 + 10, top = _position.dy + 32 + 4;
    expect(_hits(app, left + 15, top + 15), isTrue);
    expect(_hits(app, left - 4, top + 15), isFalse);
    expect(_hits(app, left + 33, top + 15), isFalse);
    // Not at the map-local position the collider used to sit at.
    expect(_hits(app, 32 + 15, 32 + 15), isFalse);
  });

  test('object colliders sit at the map\'s position plus their layer\'s '
      'offset', () async {
    final app = await _spawn();
    expect(_hits(app, _position.dx + 10 + 7, _position.dy + 16 + 7), isTrue);
    expect(_hits(app, _position.dx + 10 + 7, _position.dy + 10 - 4), isFalse);
  });

  test('a tile taller than the cell blocks where its art is drawn: bottom-'
      'aligned to the cell and moved by the tile offset', () async {
    final app = await _spawn();
    // Cell (2, 2) spans y 64..96; the 64 px tile reaches up to y 32, moved
    // (4, 2): its top band is y 34..44, x 68..100.
    final x = _position.dx + 80;
    expect(_hits(app, x, _position.dy + 38), isTrue);
    expect(_hits(app, x, _position.dy + 66), isFalse);
    expect(_hits(app, _position.dx + 101, _position.dy + 38), isFalse);
    expect(_hits(app, x, _position.dy + 46), isFalse);
  });

  test('a group\'s offset, opacity, visibility and tint fold into its '
      'layers', () async {
    final app = await _spawn();
    final walls = app.world
        .query1<TileLayer>()
        .iter()
        .map((e) => e.$2)
        .firstWhere((l) => l.name == 'walls');
    expect(walls.offset, const Offset(10, 4));
    expect(walls.opacity, closeTo(0.25, 1e-9));
    expect(walls.visible, isTrue);
    // #ff8080 x #80ffff, channel by channel.
    expect(walls.tintColor.r, closeTo(0x80 / 255, 1e-6));
    expect(walls.tintColor.g, closeTo(0x80 / 255 * 1.0, 1e-6));
    expect(walls.tintColor.b, closeTo(0x80 / 255, 1e-6));
    expect(walls.tintColor.a, 1.0);
    final things = app.world
        .query1<ObjectLayer>()
        .iter()
        .map((e) => e.$2)
        .firstWhere((l) => l.name == 'things');
    expect(things.visible, isFalse);
    expect(things.offset, const Offset(0, 6));
    final tall = app.world
        .query1<TileLayer>()
        .iter()
        .map((e) => e.$2)
        .firstWhere((l) => l.name == 'tall');
    expect(tall.tintColor, const Color(0xFFFFFFFF));
    expect(tall.offset, Offset.zero);
  });

  test('placeTileShapes flips about the tile\'s own size, not the '
      'tileset\'s largest', () {
    // A 20x40 image-collection tile on a 32 px grid, its collision along
    // its left edge; flipped horizontally it runs along its right edge.
    final shapes = TileCollider.placeTileShapes(
      [const RectangleShape(x: 0, y: 0, width: 4, height: 40)],
      tileRect: const Rect.fromLTWH(0, 0, 20, 40),
      gridX: 0,
      gridY: 0,
      cellWidth: 32,
      cellHeight: 32,
      horizontal: true,
    ).cast<RectangleShape>();
    expect(
      [for (final s in shapes) (s.x, s.y, s.width, s.height)],
      [(16.0, -8.0, 4.0, 40.0)],
    );
  });
}
