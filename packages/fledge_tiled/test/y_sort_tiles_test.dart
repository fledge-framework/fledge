import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiled/tiled.dart' as tiled;

/// Tile 0 sorts with characters at its collision's bottom (y 4 to 18),
/// tile 1 (no collision) at its own bottom, tile 2 at its `sort_y`;
/// tile 3 is an ordinary tile.
const _tsx = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="walls" tilewidth="32" tileheight="32" tilecount="4" columns="4">
 <image source="walls.png" width="128" height="32"/>
 <tile id="0">
  <properties><property name="y_sort" type="bool" value="true"/></properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="4" width="32" height="14"/>
  </objectgroup>
 </tile>
 <tile id="1">
  <properties><property name="y_sort" type="bool" value="true"/></properties>
 </tile>
 <tile id="2">
  <properties>
   <property name="y_sort" type="bool" value="true"/>
   <property name="sort_y" type="int" value="5"/>
  </properties>
 </tile>
 <tile id="3">
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="0" width="32" height="32"/>
  </objectgroup>
 </tile>
</tileset>''';

const _tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="1" height="1" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" source="walls.tsx"/>
 <layer id="1" name="walls" width="1" height="1">
  <data encoding="csv">
1
</data>
 </layer>
</map>''';

Future<LoadedTilemap> _load() =>
    AssetTilemapLoader(
      loadStringContent: (path) async => switch (path) {
        'assets/maps/room.tmx' => _tmx,
        'assets/maps/walls.tsx' => _tsx,
        _ => throw StateError('unexpected $path'),
      },
    ).load(
      'assets/maps/room.tmx',
      (path, w, h) async => TextureHandle(id: 1, width: w, height: h),
    );

const _size = 32;
const _row = 3;

World _world(LoadedTileset tileset, {String? layerClass}) {
  final world = World();
  final loaded = LoadedTilemap(
    map: tiled.TiledMap(
      width: 4,
      height: 8,
      tileWidth: _size,
      tileHeight: _size,
    ),
    tilesets: [tileset],
    animations: const {},
    sourcePath: 'room.tmx',
  );
  world.insertResource(TilemapAssets()..put('map', loaded));
  final map = world.spawn()
    ..insert(Tilemap.fromTiledMap(loaded.map))
    ..insert(GlobalTransform2D.identity());
  world
      .spawnChild(map.entity)
      .insert(
        TileLayer(
          name: 'walls',
          layerIndex: 0,
          tiledLayer: tiled.TileLayer(name: 'walls', width: 4, height: 8),
          tintColor: const Color(0xFFFFFFFF),
          layerClass: layerClass,
          tiles: [
            for (var id = 0; id < 4; id++)
              TileData(
                gid: id + 1,
                x: id,
                y: _row,
                tilesetIndex: 0,
                localId: id,
                flipVertical: id == 1,
              ),
          ],
        ),
      );
  return world;
}

LoadedTileset _tileset() => LoadedTileset(
  source: 'walls.tsx',
  name: 'walls',
  firstGid: 1,
  tileWidth: _size,
  tileHeight: _size,
  columns: 4,
  tileCount: 4,
  atlas: TextureAtlas.grid(
    texture: const TextureHandle(id: 1, width: 128, height: 32),
    columns: 4,
    rows: 1,
  ),
  ySortSpans: {
    0: const Rect.fromLTWH(0, 4, 32, 14),
    1: const Rect.fromLTWH(0, 4, 32, 14),
    2: const Rect.fromLTRB(0, 5, 32, 5),
  },
);

void main() {
  test('a y_sort tile sorts at its collision, its own bottom, or its '
      'sort_y; flips move the line; other tiles have none', () async {
    final tileset = (await _load()).tilesets.single;
    expect(tileset.ySortLine(0, 0), 18, reason: "its collision's bottom");
    expect(tileset.ySortLine(1, 0), 32, reason: 'no collision: the tile');
    expect(tileset.ySortLine(2, 0), 5, reason: 'its sort_y');
    expect(tileset.ySortLine(3, 0), isNull, reason: 'not y_sort');
    expect(tileset.ySortLine(0, TileFlipFlags.vertical), 28);
    expect(tileset.ySortLine(0, TileFlipFlags.horizontal), 18);
  });

  for (final (name, extractor) in <(String, Extractor Function())>[
    ('TilemapExtractor', TilemapExtractor.new),
    // ignore: deprecated_member_use_from_same_package
    ('CulledTilemapExtractor', CulledTilemapExtractor.new),
  ]) {
    test('$name draws y_sort tiles among the characters at their line, '
        'the rest on the ground', () {
      final render = RenderWorld();
      extractor().extract(_world(_tileset()), render);
      final byColumn = {
        for (final s in render.extractedSprites)
          ((s.transform.storage[6] - _size / 2) ~/ _size): s,
      };
      expect(byColumn, hasLength(4));
      const top = _row * _size;
      for (final (column, line) in [(0, 18.0), (1, 28.0), (2, 5.0)]) {
        final sprite = byColumn[column]!;
        expect(sprite.layer, DrawLayer.characters, reason: 'tile $column');
        expect(
          sprite.preciseSubOrder,
          (top + line) * DrawLayerExtension.ySortScale,
          reason: 'tile $column sorts at its line',
        );
        // A character standing just above the line draws under it.
        final behind = DrawLayer.characters.sortKey(
          subOrder: DrawLayerExtension.ySortSubOrder(top + line - 1),
        );
        expect(behind, lessThan(sprite.sortKey));
      }
      expect(byColumn[3]!.layer, DrawLayer.ground);
    });
  }

  test('on an above layer a y_sort tile stays in the foreground', () {
    final render = RenderWorld();
    TilemapExtractor().extract(_world(_tileset(), layerClass: 'above'), render);
    expect(render.extractedSprites.map((s) => s.layer).toSet(), {
      DrawLayer.foreground,
    });
  });
}
