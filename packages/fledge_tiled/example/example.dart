// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tiled/fledge_tiled.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())
    ..addPlugin(TiledPlugin());

  await app.tick();

  // Load a tilemap:
  // final loader = AssetTilemapLoader(
  //   loadStringContent: (path) => rootBundle.loadString(path),
  // );
  //
  // final tilemap = await loader.load(
  //   'assets/maps/level1.tmx',
  //   (path, width, height) async => await loadTexture(path),
  // );
  //
  // // Store in assets
  // app.world.getResource<TilemapAssets>()!.put('level1', tilemap);
  //
  // // Spawn the tilemap
  // app.world.eventWriter<SpawnTilemapEvent>().send(
  //   SpawnTilemapEvent(
  //     assetKey: 'level1',
  //     config: TilemapSpawnConfig(
  //       spawnObjectEntities: true,
  //       entityObjectTypes: {'enemy', 'collectible'},
  //       onObjectSpawn: (entity, obj) {
  //         if (obj.type == 'enemy') {
  //           entity.insert(Enemy(
  //             health: obj.properties.getIntOr('health', 100),
  //           ));
  //         }
  //       },
  //     ),
  //   ),
  // );

  // Query tile layers:
  // for (final (_, layer) in world.query1<TileLayer>().iter()) {
  //   print('Layer: ${layer.name}, tiles: ${layer.tiles?.length}');
  // }

  print('Tiled plugin configured');
  print('See package README for full usage examples');
}

// Placeholder for example
class Enemy {
  final int health;
  Enemy({required this.health});
}
