import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show Transform2D, GlobalTransform2D;
import 'package:tiled/tiled.dart' as tiled;

import '../collision/collision_shapes.dart';
import '../collision/tile_collider.dart';
import '../components/object_layer.dart';
import '../components/tile_layer.dart';
import '../components/tilemap.dart';
import '../components/tilemap_animator.dart';
import '../properties/tiled_properties.dart';
import '../resources/tilemap_assets.dart';

/// Event to spawn a tilemap in the world.
///
/// Sent to trigger tilemap creation. The tilemap must be loaded
/// in [TilemapAssets] before spawning.
///
/// Example:
/// ```dart
/// // First load the map
/// final loader = AssetTilemapLoader(...);
/// final tilemap = await loader.load('level1.tmx', textureLoader);
/// world.getResource<TilemapAssets>()!.put('level1', tilemap);
///
/// // Then spawn it
/// world.eventWriter<SpawnTilemapEvent>().send(SpawnTilemapEvent(
///   assetKey: 'level1',
///   position: Offset(100, 200),
/// ));
/// ```
class SpawnTilemapEvent {
  /// Key of the loaded tilemap in TilemapAssets.
  final String assetKey;

  /// World position to spawn the tilemap.
  final Offset position;

  /// Configuration for spawning.
  final TilemapSpawnConfig config;

  const SpawnTilemapEvent({
    required this.assetKey,
    this.position = Offset.zero,
    this.config = const TilemapSpawnConfig(),
  });
}

/// Event fired when a tilemap is spawned.
///
/// Contains the spawned entity and map data.
class TilemapSpawnedEvent {
  /// The root tilemap entity.
  final Entity entity;

  /// Key of the tilemap in assets.
  final String assetKey;

  const TilemapSpawnedEvent({
    required this.entity,
    required this.assetKey,
  });
}

/// Configuration for tilemap spawning.
class TilemapSpawnConfig {
  /// Whether to spawn individual entities for objects.
  final bool spawnObjectEntities;

  /// Whether to create collision shapes from objects.
  final bool createColliders;

  /// Whether to generate colliders from tile collision data.
  ///
  /// When enabled, tiles with collision shapes defined in their tileset
  /// will have those shapes collected and spawned as a [Collider] component.
  ///
  /// Example:
  /// ```dart
  /// SpawnTilemapEvent(
  ///   assetKey: 'level1',
  ///   config: TilemapSpawnConfig(
  ///     generateTileColliders: true,
  ///     optimizeTileColliders: true,
  ///   ),
  /// )
  /// ```
  final bool generateTileColliders;

  /// Whether to optimize tile colliders by merging adjacent rectangles.
  ///
  /// When enabled, adjacent rectangular collision shapes are merged into
  /// larger rectangles, reducing the number of collision checks needed.
  /// Only affects [RectangleShape] colliders.
  ///
  /// Requires [generateTileColliders] to be true.
  final bool optimizeTileColliders;

  /// Layer names to generate tile colliders for (null = all layers).
  ///
  /// Only tile layers with names in this set will have colliders generated.
  /// If null, all tile layers with collision data will be processed.
  final Set<String>? tileColliderLayers;

  /// Object types to spawn as entities (null = all).
  ///
  /// Only objects with types in this set will be spawned.
  final Set<String>? entityObjectTypes;

  /// Callback for custom object entity setup.
  ///
  /// Called for each spawned object entity, allowing custom
  /// component insertion based on object type/properties.
  final void Function(EntityCommands entity, TiledObjectData object)?
      onObjectSpawn;

  /// Callback for custom layer entity setup.
  final void Function(EntityCommands entity, String layerName)? onLayerSpawn;

  /// Callback for custom tile collider entity setup.
  ///
  /// Called when a tile collider entity is spawned, allowing custom
  /// component insertion. The [Collider] is already attached.
  final void Function(
          EntityCommands entity, String layerName, Collider collider)?
      onTileColliderSpawn;

  const TilemapSpawnConfig({
    this.spawnObjectEntities = false,
    this.createColliders = true,
    this.generateTileColliders = false,
    this.optimizeTileColliders = true,
    this.tileColliderLayers,
    this.entityObjectTypes,
    this.onObjectSpawn,
    this.onLayerSpawn,
    this.onTileColliderSpawn,
  });
}

/// System that spawns entities from loaded tilemaps.
///
/// Listens for [SpawnTilemapEvent] and creates the entity hierarchy:
/// - Root entity with [Tilemap] component
/// - Child entities for each layer ([TileLayer] or [ObjectLayer])
/// - Optional child entities for objects
class TilemapSpawnSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'tilemap_spawn',
        eventReads: {SpawnTilemapEvent},
        eventWrites: {TilemapSpawnedEvent},
        exclusive: true,
      );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) async {
    final reader = world.eventReader<SpawnTilemapEvent>();
    final writer = world.eventWriter<TilemapSpawnedEvent>();
    final assets = world.getResource<TilemapAssets>();

    if (assets == null) return;

    for (final event in reader.read()) {
      final loaded = assets.get(event.assetKey);
      if (loaded == null) {
        continue;
      }

      final entity = _spawnTilemap(world, loaded, event.position, event.config);

      writer.send(TilemapSpawnedEvent(
        entity: entity,
        assetKey: event.assetKey,
      ));
    }
  }

  Entity _spawnTilemap(
    World world,
    LoadedTilemap loaded,
    Offset position,
    TilemapSpawnConfig config,
  ) {
    // Create root tilemap entity
    final mapEntity = world.spawn()
      ..insert(Tilemap.fromTiledMap(loaded.map))
      ..insert(Transform2D.from(position.dx, position.dy))
      ..insert(GlobalTransform2D());

    // Add animator if there are animated tiles
    if (loaded.animations.isNotEmpty) {
      mapEntity
          .insert(TilemapAnimator(animations: Map.from(loaded.animations)));
    }

    // Spawn layer entities as children
    int layerIndex = 0;
    _spawnLayers(
        world, mapEntity.entity, loaded.map.layers, loaded, config, layerIndex);

    return mapEntity.entity;
  }

  int _spawnLayers(
    World world,
    Entity parent,
    List<tiled.Layer> layers,
    LoadedTilemap loaded,
    TilemapSpawnConfig config,
    int layerIndex,
  ) {
    for (final layer in layers) {
      if (layer is tiled.TileLayer) {
        _spawnTileLayer(world, parent, layer, layerIndex, loaded, config);
        layerIndex++;
      } else if (layer is tiled.ObjectGroup) {
        _spawnObjectLayer(world, parent, layer, layerIndex, loaded, config);
        layerIndex++;
      } else if (layer is tiled.Group) {
        // Recursively handle layer groups
        layerIndex = _spawnLayers(
            world, parent, layer.layers, loaded, config, layerIndex);
      } else if (layer is tiled.ImageLayer) {
        // Image layers could be handled here
        layerIndex++;
      }
    }
    return layerIndex;
  }

  void _spawnTileLayer(
    World world,
    Entity parent,
    tiled.TileLayer layer,
    int layerIndex,
    LoadedTilemap loaded,
    TilemapSpawnConfig config,
  ) {
    final tiles = _buildTileData(layer, loaded);

    final layerEntity = world.spawnChild(parent)
      ..insert(TileLayer(
        name: layer.name,
        layerIndex: layerIndex,
        tiledLayer: layer,
        opacity: layer.opacity,
        visible: layer.visible,
        offset: Offset(layer.offsetX, layer.offsetY),
        parallax: Offset(layer.parallaxX, layer.parallaxY),
        tintColor: _parseColor(layer.tintColorHex),
        tiles: tiles,
      ))
      ..insert(Transform2D())
      ..insert(GlobalTransform2D());

    config.onLayerSpawn?.call(layerEntity, layer.name);

    // Generate tile colliders if enabled
    if (config.generateTileColliders) {
      // Check if this layer should have colliders generated
      if (config.tileColliderLayers == null ||
          config.tileColliderLayers!.contains(layer.name)) {
        _generateTileColliders(
          world,
          layerEntity.entity,
          tiles,
          loaded,
          layer.name,
          config,
        );
      }
    }
  }

  void _generateTileColliders(
    World world,
    Entity layerEntity,
    List<TileData> tiles,
    LoadedTilemap loaded,
    String layerName,
    TilemapSpawnConfig config,
  ) {
    // Collect collision data from tiles
    final collisionData = <TileCollisionData>[];

    for (final tile in tiles) {
      final tileset = loaded.tilesets.elementAtOrNull(tile.tilesetIndex);
      if (tileset == null) continue;

      final shapes = tileset.getCollisionShapes(tile.localId);
      if (shapes.isEmpty) continue;

      collisionData.add(TileCollisionData(
        gridX: tile.x,
        gridY: tile.y,
        shapes: shapes,
      ));
    }

    if (collisionData.isEmpty) return;

    // Generate world-space collision shapes
    final tileWidth = loaded.tileWidth.toDouble();
    final tileHeight = loaded.tileHeight.toDouble();

    var allShapes = TileCollider.fromTileLayer(
      tiles: collisionData,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
    );

    // Optionally optimize by merging adjacent rectangles
    if (config.optimizeTileColliders) {
      final rectangles = <RectangleShape>[];
      final otherShapes = <CollisionShape>[];

      for (final shape in allShapes) {
        if (shape is RectangleShape && shape.rotation == 0) {
          rectangles.add(shape);
        } else {
          otherShapes.add(shape);
        }
      }

      if (rectangles.isNotEmpty) {
        final merged = TileCollider.mergeRectangles(rectangles);
        allShapes = [...merged, ...otherShapes];
      }
    }

    if (allShapes.isEmpty) return;

    // Spawn collider entity as child of the layer
    final collider = Collider(shapes: allShapes);
    final colliderEntity = world.spawnChild(layerEntity)
      ..insert(Transform2D())
      ..insert(GlobalTransform2D())
      ..insert(collider);

    config.onTileColliderSpawn?.call(colliderEntity, layerName, collider);
  }

  List<TileData> _buildTileData(tiled.TileLayer layer, LoadedTilemap loaded) {
    final tiles = <TileData>[];
    final data = layer.data;
    if (data == null) return tiles;

    final width = layer.width;

    for (int i = 0; i < data.length; i++) {
      final rawGid = data[i];
      if (rawGid == 0) continue; // Empty tile

      final x = i % width;
      final y = i ~/ width;

      // Clear flip flags to get actual GID
      final gid = rawGid & 0x1FFFFFFF;

      // Find tileset for this GID
      final lookup = loaded.getTilesetForGid(gid);
      if (lookup == null) continue;

      final isAnimated = loaded.hasAnimation(gid);

      tiles.add(TileData.fromGid(
        rawGid,
        x,
        y,
        lookup.tilesetIndex,
        lookup.tileset.firstGid,
        animated: isAnimated,
      ));
    }

    return tiles;
  }

  void _spawnObjectLayer(
    World world,
    Entity parent,
    tiled.ObjectGroup layer,
    int layerIndex,
    LoadedTilemap loaded,
    TilemapSpawnConfig config,
  ) {
    final objects = layer.objects.map((obj) {
      return TiledObjectData(
        id: obj.id,
        name: obj.name,
        type: obj.type,
        x: obj.x,
        y: obj.y,
        width: obj.width,
        height: obj.height,
        rotation: obj.rotation,
        shape: _parseShape(obj),
        points: _parsePoints(obj),
        gid: obj.gid,
        properties: TiledProperties.fromCustomProperties(obj.properties),
        visible: obj.visible,
      );
    }).toList();

    final layerEntity = world.spawnChild(parent)
      ..insert(ObjectLayer(
        name: layer.name,
        layerIndex: layerIndex,
        objects: objects,
        drawOrder: layer.drawOrder == tiled.DrawOrder.indexOrder
            ? DrawOrder.indexOrder
            : DrawOrder.topDown,
        color: _parseColor(layer.tintColorHex),
        opacity: layer.opacity,
        visible: layer.visible,
        offset: Offset(layer.offsetX, layer.offsetY),
      ))
      ..insert(Transform2D())
      ..insert(GlobalTransform2D());

    config.onLayerSpawn?.call(layerEntity, layer.name);

    // Optionally spawn individual object entities
    if (config.spawnObjectEntities) {
      for (final obj in objects) {
        if (config.entityObjectTypes != null &&
            obj.type != null &&
            !config.entityObjectTypes!.contains(obj.type)) {
          continue;
        }

        _spawnObjectEntity(world, layerEntity.entity, obj, config);
      }
    }
  }

  void _spawnObjectEntity(
    World world,
    Entity layerEntity,
    TiledObjectData obj,
    TilemapSpawnConfig config,
  ) {
    final entity = world.spawnChild(layerEntity)
      ..insert(Transform2D.from(obj.x, obj.y))
      ..insert(GlobalTransform2D())
      ..insert(TiledObject.fromData(obj));

    // Create collision shapes if enabled
    if (config.createColliders) {
      final shapes = TileCollider.fromObject(obj);
      if (shapes.isNotEmpty) {
        entity.insert(Collider(shapes: shapes));
      }
    }

    // Call custom setup callback
    config.onObjectSpawn?.call(entity, obj);
  }

  ObjectShape _parseShape(tiled.TiledObject obj) {
    if (obj.isEllipse) return ObjectShape.ellipse;
    if (obj.isPoint) return ObjectShape.point;
    if (obj.isPolygon) return ObjectShape.polygon;
    if (obj.isPolyline) return ObjectShape.polyline;
    if (obj.gid != null) return ObjectShape.tile;
    if (obj.text != null) return ObjectShape.text;
    return ObjectShape.rectangle;
  }

  List<Offset>? _parsePoints(tiled.TiledObject obj) {
    if (obj.isPolygon && obj.polygon.isNotEmpty) {
      return obj.polygon.map((p) => Offset(p.x, p.y)).toList();
    }
    if (obj.isPolyline && obj.polyline.isNotEmpty) {
      return obj.polyline.map((p) => Offset(p.x, p.y)).toList();
    }
    return null;
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFFFFFFF);

    final cleaned = hex.replaceFirst('#', '');
    int? value;

    if (cleaned.length == 8) {
      // AARRGGBB
      value = int.tryParse(cleaned, radix: 16);
    } else if (cleaned.length == 6) {
      // RRGGBB
      value = int.tryParse('FF$cleaned', radix: 16);
    }

    return value != null ? Color(value) : const Color(0xFFFFFFFF);
  }
}
