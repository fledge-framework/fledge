import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render/fledge_render.dart' show Extractors;

import 'extraction/tilemap_extractor.dart';
import 'resources/tiled_assets.dart' show TilemapAsset, TilesetAsset;
import 'resources/tilemap_assets.dart';
import 'resources/tileset_registry.dart';
import 'systems/tile_animation_system.dart';
import 'systems/tilemap_spawn_system.dart';

/// Plugin that adds Tiled tilemap support to Fledge.
///
/// Provides resources, systems, and extractors for loading and
/// rendering Tiled tilemaps.
///
/// ## Usage
///
/// ```dart
/// final app = App()
///   .addPlugin(WallTimePlugin())  // Required for animations
///   .addPlugin(RenderPlugin())    // For render extraction
///   .addPlugin(TiledPlugin());
///
/// // Load a tilemap
/// final loader = AssetTilemapLoader(
///   loadStringContent: (path) => rootBundle.loadString(path),
/// );
/// final tilemap = await loader.load('maps/level1.tmx', textureLoader);
///
/// // Store in assets
/// app.world.getResource<TilemapAssets>()!.put('level1', tilemap);
///
/// // Spawn the tilemap
/// app.world.eventWriter<SpawnTilemapEvent>().send(SpawnTilemapEvent(
///   assetKey: 'level1',
///   config: TilemapSpawnConfig(
///     tileConfig: TileLayerConfig(
///       generateColliders: true,
///       colliderLayers: {'Collision'},
///     ),
///     objectTypes: {
///       'enemy': ObjectTypeConfig(
///         onSpawn: (entity, obj) => entity.insert(Enemy()),
///       ),
///     },
///   ),
/// ));
///
/// await app.run();
/// ```
class TiledPlugin implements Plugin {
  /// Plugin configuration.
  final TiledPluginConfig config;

  /// Creates a TiledPlugin with optional configuration.
  TiledPlugin([this.config = const TiledPluginConfig()]);

  @override
  void build(App app) {
    // Insert resources — post-Phase-5 `Assets<TilemapAsset>` /
    // `Assets<TilesetAsset>` alongside the deprecated key-based
    // facades. The `Asset` suffix in the type parameters distinguishes
    // the loaded value from the per-entity `Tilemap` component in
    // `src/components/tilemap.dart` (which points at a
    // `LoadedTilemap`).
    app
        .insertResource<Assets<TilemapAsset>>(Assets<TilemapAsset>())
        .insertResource<Assets<TilesetAsset>>(Assets<TilesetAsset>())
        // ignore: deprecated_member_use_from_same_package
        .insertResource(TilemapAssets())
        // ignore: deprecated_member_use_from_same_package
        .insertResource(TilesetRegistry());

    // Register events
    app.addEvent<SpawnTilemapEvent>().addEvent<TilemapSpawnedEvent>();

    // Add systems
    app
        .addSystem(TilemapSpawnSystem(), schedule: Schedules.first)
        .addSystem(TileAnimationSystem(), schedule: Schedules.update);

    // Register extractor with render system (if present)
    final extractors = app.world.getResource<Extractors>();
    if (extractors != null) {
      extractors.register(TilemapExtractor(
        respectVisibility: config.respectLayerVisibility,
      ));
    }
  }

  @override
  void cleanup() {
    // Resources will be garbage collected with the world
  }
}

/// Configuration for the Tiled plugin.
class TiledPluginConfig {
  /// Whether to respect layer visibility during extraction.
  ///
  /// If true, invisible layers are not extracted to the render world.
  final bool respectLayerVisibility;

  /// Chunk size for infinite maps (in tiles).
  ///
  /// Only chunks within view will be loaded/rendered.
  final int chunkSize;

  /// Maximum number of chunks to keep loaded for infinite maps.
  final int maxLoadedChunks;

  const TiledPluginConfig({
    this.respectLayerVisibility = true,
    this.chunkSize = 16,
    this.maxLoadedChunks = 64,
  });
}
