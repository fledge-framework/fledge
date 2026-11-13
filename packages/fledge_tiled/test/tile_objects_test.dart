import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

/// An image-collection tileset in another folder than the map, its images
/// in a third. Tile 0 is a `prop` with a footprint and `solid`; tile 1 was
/// removed in Tiled (a gap); tile 2 has no class.
const _tsx = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="props" tilewidth="96" tileheight="64" tilecount="2" columns="0">
 <grid orientation="orthogonal" width="1" height="1"/>
 <tile id="0" type="prop">
  <properties>
   <property name="solid" type="bool" value="true"/>
   <property name="kind" value="crate"/>
  </properties>
  <image source="../art/crate.png" width="96" height="64"/>
  <objectgroup draworder="index" id="2">
   <object id="1" x="8" y="48" width="80" height="16"/>
  </objectgroup>
 </tile>
 <tile id="2">
  <image source="../art/rock.png" width="32" height="32"/>
 </tile>
</tileset>''';

const _tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down" width="10" height="10" tilewidth="32" tileheight="32" infinite="0" nextlayerid="2" nextobjectid="4">
 <tileset firstgid="1" source="../tilesets/props.tsx"/>
 <objectgroup id="1" name="objects">
  <object id="1" gid="1" x="100" y="200" width="96" height="64"/>
  <object id="2" gid="1" type="special" x="0" y="64" width="96" height="64">
   <properties>
    <property name="kind" value="barrel"/>
   </properties>
  </object>
  <object id="3" gid="3" x="10" y="42" width="32" height="32"/>
 </objectgroup>
</map>''';

/// Loads the map, recording which texture paths were requested.
Future<(LoadedTilemap, List<String>)> _load() async {
  final textures = <String>[];
  final loader = AssetTilemapLoader(
    loadStringContent: (path) async => switch (path) {
      'assets/maps/town.tmx' => _tmx,
      'assets/tilesets/props.tsx' => _tsx,
      _ => throw StateError('unexpected $path'),
    },
  );
  final map = await loader.load('assets/maps/town.tmx', (path, w, h) async {
    textures.add(path);
    return TextureHandle(id: textures.length, width: w, height: h);
  });
  return (map, textures);
}

void main() {
  test('normalizeAssetPath resolves dot segments', () {
    expect(normalizeAssetPath('assets/maps/../art/a.png'), 'assets/art/a.png');
    expect(normalizeAssetPath('a/./b//c.png'), 'a/b/c.png');
    expect(normalizeAssetPath('../x/../y.png'), '../y.png');
    expect(normalizeAssetPath('/a/../../b'), '/b');
  });

  test('an image-collection tileset loads each tile image', () async {
    final (map, textures) = await _load();
    // Relative to the tileset's own folder, with `..` resolved.
    expect(textures, ['assets/art/crate.png', 'assets/art/rock.png']);
    final tileset = map.tilesets.single;
    expect(tileset.isImageCollection, isTrue);
    expect(tileset.getTileImage(0)!.width, 96);
    expect(tileset.getTileImage(2)!.height, 32);
    expect(tileset.getTileClass(0), 'prop');
    // The gap left by a removed tile is not a tile; the one after it is.
    expect(map.getTilesetForGid(2), isNull);
    expect(map.getTilesetForGid(3)!.localId, 2);
  });

  test('tile objects take their tile class, properties and image', () async {
    final (map, _) = await _load();
    final app = App()..addPlugin(TiledPlugin());
    final seen = <int, TiledObjectData>{};
    void record(EntityCommands entity, TiledObjectData object) =>
        seen[object.id] = object;
    final handle = app.world.getResource<Assets<TilemapAsset>>()!.add(map);
    app.world.eventWriter<SpawnTilemapEvent>().send(
      SpawnTilemapEvent.fromHandle(
        handle,
        config: TilemapSpawnConfig(
          objectTypes: {
            'prop': ObjectTypeConfig(createCollider: false, onSpawn: record),
            'special': ObjectTypeConfig(createCollider: false, onSpawn: record),
          },
        ),
      ),
    );
    await app.tick();

    final plain = seen[1]!;
    expect(plain.type, 'prop');
    expect(plain.properties.getBool('solid'), isTrue);
    expect(plain.properties.getString('kind'), 'crate');
    expect(plain.tileImage!.width, 96);
    final footprint = plain.tileCollision.single as RectangleShape;
    expect((footprint.x, footprint.y), (8, 48));
    expect((footprint.width, footprint.height), (80, 16));

    // Its own class and properties win over the tile's.
    final special = seen[2]!;
    expect(special.type, 'special');
    expect(special.properties.getString('kind'), 'barrel');
    expect(special.properties.getBool('solid'), isTrue);

    // No class anywhere: not spawned by type.
    expect(seen.containsKey(3), isFalse);
  });
}
