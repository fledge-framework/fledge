/// Tiled tilemap support for the Fledge ECS game framework.
///
/// This library provides full integration with [Tiled](https://www.mapeditor.org/),
/// a popular 2D tilemap editor. It supports:
///
/// - **TMX/TSX Parsing**: Load Tiled maps and external tilesets
/// - **Tile Layers**: Efficient rendering with atlas batching
/// - **Object Layers**: Spawn entities from Tiled objects
/// - **Animated Tiles**: Automatic tile animation support
/// - **Collision Shapes**: Generate collision from objects and tiles
/// - **Custom Properties**: Type-safe access to Tiled properties
/// - **Infinite Maps**: Chunk-based loading for large maps
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_tiled/fledge_tiled.dart';
///
/// void main() async {
///   final app = App()
///     .addPlugin(TimePlugin())
///     .addPlugin(TiledPlugin());
///
///   // Load a tilemap
///   final loader = AssetTilemapLoader(
///     loadStringContent: (path) => rootBundle.loadString(path),
///   );
///   final tilemap = await loader.load(
///     'assets/maps/level1.tmx',
///     (path, w, h) async => await loadTexture(path),
///   );
///
///   // Store and spawn
///   app.world.getResource<TilemapAssets>()!.put('level1', tilemap);
///   app.world.eventWriter<SpawnTilemapEvent>().send(
///     SpawnTilemapEvent(assetKey: 'level1'),
///   );
///
///   await app.run();
/// }
/// ```
///
/// ## Object Spawning
///
/// Objects from Tiled can be spawned as entities with custom components:
///
/// ```dart
/// SpawnTilemapEvent(
///   assetKey: 'level1',
///   config: TilemapSpawnConfig(
///     tileConfig: TileLayerConfig(
///       generateColliders: true,
///       colliderLayers: {'Collision'},
///     ),
///     objectTypes: {
///       'enemy': ObjectTypeConfig(
///         onSpawn: (entity, obj) {
///           entity.insert(Enemy(
///             health: obj.properties.getIntOr('health', 100),
///           ));
///         },
///       ),
///       'collectible': ObjectTypeConfig(
///         createCollider: false,
///         onSpawn: (entity, obj) {
///           entity.insert(Collectible(
///             value: obj.properties.getIntOr('value', 10),
///           ));
///         },
///       ),
///     },
///   ),
/// )
/// ```
library fledge_tiled;

// Plugin
export 'src/plugin.dart';

// Components
export 'src/components/tilemap.dart';
export 'src/components/tile_layer.dart';
export 'src/components/object_layer.dart';
export 'src/components/tilemap_animator.dart';

// Resources
export 'src/resources/tilemap_assets.dart';
export 'src/resources/tileset_registry.dart';

// Properties
export 'src/properties/tiled_properties.dart';

// Collision
export 'src/collision/collision_shapes.dart';
export 'src/collision/tile_collider.dart';

// Config
export 'src/config/spawn_config.dart';

// Systems
export 'src/systems/tilemap_spawn_system.dart';
export 'src/systems/tile_animation_system.dart';

// Extraction
export 'src/extraction/extracted_tile.dart';
export 'src/extraction/tilemap_extractor.dart';

// Loader
export 'src/loader/tilemap_loader.dart';
export 'src/loader/asset_tilemap_loader.dart';
