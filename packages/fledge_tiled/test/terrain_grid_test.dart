import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

/// A corner Wang set: 1 = grass, 2 = road. Tile 0 is all grass, tile 1 all
/// road, tile 2 road on its top-right corner only.
const _wangSet = '''
  <wangsets>
   <wangset name="ground" type="corner" tile="-1">
    <wangcolor name="grass" color="#00ff00" tile="0" probability="1"/>
    <wangcolor name="road" color="#804000" tile="1" probability="1"/>
    <wangtile tileid="0" wangid="0,1,0,1,0,1,0,1"/>
    <wangtile tileid="1" wangid="0,2,0,2,0,2,0,2"/>
    <wangtile tileid="2" wangid="0,2,0,1,0,1,0,1"/>
   </wangset>
  </wangsets>''';

const _tsx =
    '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="ground" tilewidth="32" tileheight="32" tilecount="4" columns="4">
 <image source="ground.png" width="128" height="32"/>
$_wangSet
</tileset>''';

/// A 3×2 map whose ground layer is laid from the external tileset, and a
/// second tileset embedded in the map with the same Wang set.
String _tmx({required bool embedded}) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="3" height="2" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="1">
 ${embedded ? '<tileset firstgid="1" name="ground" tilewidth="32" tileheight="32" tilecount="4" columns="4">\n  <image source="ground.png" width="128" height="32"/>\n$_wangSet\n </tileset>' : '<tileset firstgid="1" source="ground.tsx"/>'}
 <layer id="1" name="ground" width="3" height="2">
  <data encoding="csv">
1,2,3,
2,2,1
</data>
 </layer>
</map>''';

Future<LoadedTilemap> _load({required bool embedded}) {
  final loader = AssetTilemapLoader(
    loadStringContent: (path) async {
      if (path.endsWith('.tmx')) return _tmx(embedded: embedded);
      if (path.endsWith('ground.tsx')) return _tsx;
      throw StateError('unexpected $path');
    },
  );
  return loader.load(
    'maps/test_${embedded ? 'embedded' : 'external'}.tmx',
    (path, w, h) async => TextureHandle(id: 1, width: w, height: h),
  );
}

void main() {
  for (final embedded in [false, true]) {
    final kind = embedded ? 'embedded' : 'external';

    test('the loader keeps the Wang tiles of an $kind tileset', () async {
      final map = (await _load(embedded: embedded)).map;
      final set = map.tilesets.single.wangSets.single;
      expect(set.wangTiles, hasLength(3));
      expect(set.wangTiles[2].wangId, [0, 2, 0, 1, 0, 1, 0, 1]);
    });

    test('TerrainGrid reads corner terrain ($kind tileset)', () async {
      final terrain = TerrainGrid.fromTilemap(
        (await _load(embedded: embedded)).map,
        layer: 'ground',
      );
      expect((terrain.width, terrain.height), (6, 4));
      expect(terrain.cellWidth, 16);
      // Tile (0, 0) is grass, (1, 0) road, (2, 0) road on its top right.
      expect(terrain.cornerAt(0, 0), 'grass');
      expect(terrain.cornerAt(2, 1), 'road');
      expect(terrain.cornerAt(4, 0), 'grass');
      expect(terrain.cornerAt(5, 0), 'road');
      expect(terrain.cornerAt(5, 1), 'grass');
      expect(terrain.terrainAt(40, 40), 'road');
      expect(terrain.cornerAt(-1, 0), isNull);
      expect(terrain.cornerAt(6, 0), isNull);
    });
  }

  test('a missing layer gives no terrain', () async {
    final terrain = TerrainGrid.fromTilemap(
      (await _load(embedded: false)).map,
      layer: 'nope',
    );
    expect(terrain.cornerAt(0, 0), isNull);
  });

  group('applyTerrainCosts', () {
    late TerrainGrid terrain;
    setUp(() async {
      terrain = TerrainGrid.fromTilemap(
        (await _load(embedded: false)).map,
        layer: 'ground',
      );
    });

    test('at corner resolution', () {
      final grid = CollisionGrid(width: 6, height: 4);
      applyTerrainCosts(grid, terrain, {'road': 1}, defaultCost: 3);
      expect(grid.costAt(0, 0), 3);
      expect(grid.costAt(2, 0), 1);
      expect(grid.costAt(5, 0), 1);
      expect(grid.costAt(5, 1), 3);
    });

    test('at tile resolution, the mean of the corners', () {
      final grid = CollisionGrid(width: 3, height: 2);
      applyTerrainCosts(grid, terrain, {'road': 1}, defaultCost: 3);
      expect(grid.costAt(0, 0), 3);
      expect(grid.costAt(1, 0), 1);
      expect(grid.costAt(2, 0), 2.5);
    });

    test('rejects a grid of another size', () {
      expect(
        () => applyTerrainCosts(CollisionGrid(width: 5, height: 4), terrain, {
          'road': 1,
        }),
        throwsArgumentError,
      );
    });
  });
}
