import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

const _tsx = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" name="terrain" tilewidth="16" tileheight="16" tilecount="4" columns="2">
 <image source="../art/terrain.png" width="32" height="32"/>
 <tile id="1" type="water">
  <properties><property name="speed" type="float" value="0.5"/></properties>
  <objectgroup draworder="index" id="2">
   <object id="1" x="0" y="0" width="16" height="8"/>
  </objectgroup>
 </tile>
</tileset>''';

void main() {
  test('TsxLoader loads a standalone tileset and its image', () async {
    final textures = <String>[];
    final loader = TsxLoader(
      assetPrefix: 'assets/',
      loadStringContent: (path) async => switch (path) {
        'assets/tilesets/terrain_standalone.tsx' => _tsx,
        _ => throw StateError('unexpected $path'),
      },
      textureLoader: (path, w, h) async {
        textures.add(path);
        return TextureHandle(id: 7, width: w, height: h);
      },
    );

    final tileset = await loader.load('tilesets/terrain_standalone.tsx');
    expect(tileset.name, 'terrain');
    expect((tileset.tileWidth, tileset.tileCount, tileset.columns), (16, 4, 2));
    expect(tileset.firstGid, 1);
    expect(tileset.atlas.texture.id, 7);
    // Resolved against the .tsx's folder.
    expect(textures, ['assets/art/terrain.png']);
    expect(tileset.getTileClass(1), 'water');
    expect(tileset.getProperties(1)!.getDouble('speed'), 0.5);
    expect(tileset.getCollisionShapes(1), hasLength(1));
  });

  test('through Assets.load, a TsxLoader without callbacks fails '
      'observably', () async {
    final assets = Assets<TilesetAsset>();
    final handle = assets.load('a.tsx', const TsxLoader());
    await Future<void>.delayed(Duration.zero);
    expect(handle.isReady, isFalse);
    expect(handle.error, isA<StateError>());
  });
}
