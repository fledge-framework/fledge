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
/// - **Infinite Maps**: Tiles and collision grids from the map's chunks
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fledge_ecs/fledge_ecs.dart';
/// import 'package:fledge_tiled/fledge_tiled.dart';
///
/// void main() async {
///   final app = App()
///     .addPlugin(WallTimePlugin())
///     .addPlugin(TiledPlugin());
///
///   // Load a tilemap through the asset pipeline
///   final tmx = TmxLoader(
///     tilemapLoader: AssetTilemapLoader(
///       loadStringContent: (path) => rootBundle.loadString(path),
///     ),
///     textureLoader: (path, w, h) async => await loadTexture(path),
///   );
///   final tilemap = await tmx.load('assets/maps/level1.tmx');
///   final handle = app.world.getResource<Assets<TilemapAsset>>()!.add(tilemap);
///
///   // Spawn it
///   app.world.eventWriter<SpawnTilemapEvent>().send(
///     SpawnTilemapEvent.fromHandle(handle),
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
/// SpawnTilemapEvent.fromHandle(
///   handle,
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

// Re-export the physics package so downstream users can continue to
// access `Collider`, `CollisionShape`, `CollisionGrid`, `Pathfinder`,
// etc. from `package:fledge_tiled/fledge_tiled.dart` for one release
// while migrating imports.
// TODO(next-major): remove re-export; import from
// package:fledge_physics/fledge_physics.dart directly.
export 'package:fledge_physics/fledge_physics.dart';

// Plugin
export 'src/plugin.dart';

// Components
export 'src/components/tilemap.dart';
export 'src/components/tile_layer.dart';
export 'src/components/object_layer.dart';
export 'src/components/tilemap_animator.dart';

// Resources
export 'src/resources/tiled_assets.dart';
export 'src/resources/tilemap_assets.dart';
export 'src/resources/tileset_registry.dart';

// Properties
export 'src/properties/tiled_properties.dart';

// Collision (tiled-specific adapter; core shapes now live in fledge_physics)
export 'src/collision/tile_collider.dart';

// Config
export 'src/config/spawn_config.dart';

// Systems
export 'src/systems/tilemap_spawn_system.dart';
export 'src/systems/tile_animation_system.dart';

// Extraction
export 'src/extraction/culled_tilemap_extractor.dart';
export 'src/extraction/extracted_tile.dart';
export 'src/extraction/tile_sprite_conversion.dart';
export 'src/extraction/tilemap_extractor.dart';

// Loader
export 'src/loader/tilemap_loader.dart';
export 'src/loader/asset_tilemap_loader.dart';

// Pathfinding (tiled adapter; CollisionGrid + Pathfinder now live in fledge_physics)
export 'src/pathfinding/collision_extractor.dart';
export 'src/terrain/terrain_grid.dart';
