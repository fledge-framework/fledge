import 'dart:ui';

import 'package:fledge_assets/fledge_assets.dart'
    show Assets, Handle, HotReloadPollSystem;
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show Transform2D, GlobalTransform2D, StaticTransform;
import 'package:tiled/tiled.dart' as tiled;

import '../collision/tile_collider.dart';
import '../components/object_layer.dart';
import '../components/tile_layer.dart';
import '../components/tilemap.dart';
import '../components/tilemap_animator.dart';
import '../config/spawn_config.dart';
import '../properties/tiled_properties.dart';
import '../resources/tiled_assets.dart' show TilemapAsset;
import '../resources/tilemap_assets.dart';

/// Event to spawn a tilemap in the world.
///
/// Sent to trigger tilemap creation. The tilemap must already be loaded
/// when [TilemapSpawnSystem] reads the event: an event whose handle isn't
/// ready yet (an `Assets.load` still in flight, or one that failed; see
/// `Handle.error`) is dropped. The legacy [assetKey] form looks the map up
/// in `Assets<TilemapAsset>` by path, then in the deprecated
/// [TilemapAssets].
///
/// Example:
/// ```dart
/// // First load the map into Assets<TilemapAsset>
/// final tmx = TmxLoader(
///   tilemapLoader: AssetTilemapLoader(loadStringContent: loadString),
///   textureLoader: textureLoader,
/// );
/// final handle = world
///     .getResource<Assets<TilemapAsset>>()!
///     .add(await tmx.load('level1.tmx'));
///
/// // Then spawn it
/// world.eventWriter<SpawnTilemapEvent>().send(SpawnTilemapEvent.fromHandle(
///   handle,
///   position: Offset(100, 200),
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
/// ```
class SpawnTilemapEvent {
  /// Key of the loaded tilemap in the deprecated [TilemapAssets] store.
  ///
  /// Consulted only when [handle] is null. Prefer [handle].
  final String? assetKey;

  /// Handle into `Assets<TilemapAsset>` when the tilemap was loaded
  /// through the modern asset store. Preferred over [assetKey].
  final Handle<TilemapAsset>? handle;

  /// World position to spawn the tilemap.
  final Offset position;

  /// Configuration for spawning.
  final TilemapSpawnConfig config;

  const SpawnTilemapEvent({
    required String this.assetKey,
    this.position = Offset.zero,
    this.config = const TilemapSpawnConfig(),
  }) : handle = null;

  /// Spawn the tilemap referenced by [handle] from `Assets<TilemapAsset>`.
  const SpawnTilemapEvent.fromHandle(
    Handle<TilemapAsset> this.handle, {
    this.position = Offset.zero,
    this.config = const TilemapSpawnConfig(),
  }) : assetKey = null;
}

/// Event fired when a tilemap is spawned.
///
/// Contains the spawned entity and map data.
class TilemapSpawnedEvent {
  /// The root tilemap entity.
  final Entity entity;

  /// Key of the tilemap in the deprecated [TilemapAssets] store.
  ///
  /// Null when the tilemap was spawned via a `Handle<TilemapAsset>`.
  final String? assetKey;

  /// Handle into `Assets<TilemapAsset>`, when the tilemap was spawned
  /// through the modern asset store.
  final Handle<TilemapAsset>? handle;

  const TilemapSpawnedEvent({required this.entity, this.assetKey, this.handle});
}

/// System that spawns entities from loaded tilemaps.
///
/// Listens for [SpawnTilemapEvent] and creates the entity hierarchy:
/// - Root entity with [Tilemap] component
/// - Child entities for each layer ([TileLayer] or [ObjectLayer])
/// - Optional child entities for objects
class TilemapSpawnSystem implements System {
  /// The `SystemMeta.name` of [TilemapSpawnSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'tilemap_spawn';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    eventReads: {SpawnTilemapEvent},
    eventWrites: {TilemapSpawnedEvent},
    exclusive: true,
    // Exclusive, so it conflicts with every other system in
    // Schedules.first. The FirstSets phase chain orders it after every
    // frameStart / platform / input system; within the content phase,
    // spawn after queued hot reloads land so a map spawned this frame
    // sees the reloaded asset.
    sets: [FirstSets.content],
    after: [HotReloadPollSystem.systemName],
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  void run(World world) {
    final reader = world.eventReader<SpawnTilemapEvent>();
    final writer = world.eventWriter<TilemapSpawnedEvent>();
    final modernAssets = world.getResource<Assets<TilemapAsset>>();
    // ignore: deprecated_member_use_from_same_package
    final legacyAssets = world.getResource<TilemapAssets>();

    for (final event in reader.read()) {
      LoadedTilemap? loaded;
      Handle<TilemapAsset>? handle = event.handle;

      if (handle != null) {
        loaded = handle.get();
      } else if (event.assetKey != null && modernAssets != null) {
        final id = modernAssets.findByPath(event.assetKey!);
        if (id != null) {
          loaded = modernAssets.get(id);
        }
      }

      // Fall back to the legacy key-based store.
      if (loaded == null && event.assetKey != null && legacyAssets != null) {
        loaded = legacyAssets.get(event.assetKey!);
      }

      if (loaded == null) {
        continue;
      }

      final entity = _spawnTilemap(
        world,
        loaded,
        event.position,
        event.config,
        handle,
      );

      writer.send(
        TilemapSpawnedEvent(
          entity: entity,
          assetKey: event.assetKey,
          handle: handle,
        ),
      );
    }
  }

  Entity _spawnTilemap(
    World world,
    LoadedTilemap loaded,
    Offset position,
    TilemapSpawnConfig config,
    Handle<TilemapAsset>? asset,
  ) {
    // Create root tilemap entity
    final mapEntity = world.spawn()
      ..insert(Tilemap.fromTiledMap(loaded.map, asset: asset))
      ..insert(Transform2D.from(position.dx, position.dy))
      ..insert(GlobalTransform2D());
    if (config.staticTransforms) mapEntity.insert(const StaticTransform());

    // Add animator if there are animated tiles
    if (loaded.animations.isNotEmpty) {
      mapEntity.insert(
        TilemapAnimator(animations: Map.from(loaded.animations)),
      );
    }

    // Spawn layer entities as children
    int layerIndex = 0;
    _spawnLayers(
      world,
      mapEntity.entity,
      loaded.map.layers,
      loaded,
      config,
      layerIndex,
      const _Inherited(),
    );

    return mapEntity.entity;
  }

  int _spawnLayers(
    World world,
    Entity parent,
    List<tiled.Layer> layers,
    LoadedTilemap loaded,
    TilemapSpawnConfig config,
    int layerIndex,
    _Inherited inherited,
  ) {
    for (final layer in layers) {
      if (layer is tiled.TileLayer) {
        _spawnTileLayer(
          world,
          parent,
          layer,
          layerIndex,
          loaded,
          config,
          inherited.apply(layer),
        );
        layerIndex++;
      } else if (layer is tiled.ObjectGroup) {
        _spawnObjectLayer(
          world,
          parent,
          layer,
          layerIndex,
          loaded,
          config,
          inherited.apply(layer),
        );
        layerIndex++;
      } else if (layer is tiled.Group) {
        // A group's offset, parallax, opacity, visibility and tint apply
        // to every layer in it, as Tiled draws them.
        layerIndex = _spawnLayers(
          world,
          parent,
          layer.layers,
          loaded,
          config,
          layerIndex,
          inherited.apply(layer),
        );
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
    _Inherited look,
  ) {
    final chunks = layer.data == null && layer.chunks != null
        ? <ChunkKey, TileChunk>{}
        : null;
    final tiles = _buildTileData(layer, loaded, chunks);

    final layerEntity = world.spawnChild(parent)
      ..insert(
        TileLayer(
          name: layer.name,
          layerIndex: layerIndex,
          tiledLayer: layer,
          opacity: look.opacity,
          visible: look.visible,
          offset: look.offset,
          parallax: look.parallax,
          tintColor: look.tint,
          layerClass: layer.class_,
          tiles: tiles,
          chunks: chunks,
        ),
      )
      ..insert(Transform2D())
      ..insert(GlobalTransform2D());

    config.onLayerSpawn?.call(layerEntity, layer.name);

    // Generate tile colliders if enabled
    if (config.tileConfig.generateColliders) {
      // Check if this layer should have colliders generated
      if (config.tileConfig.colliderLayers == null ||
          config.tileConfig.colliderLayers!.contains(layer.name)) {
        _generateTileColliders(
          world,
          layerEntity.entity,
          tiles,
          loaded,
          layer.name,
          config.tileConfig,
          look.offset,
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
    TileLayerConfig tileConfig,
    Offset layerOffset,
  ) {
    final cellWidth = loaded.tileWidth.toDouble();
    final cellHeight = loaded.tileHeight.toDouble();

    // Every tile's collision in the map's space, where its art is drawn
    // (flipped with the tile, on the cell's bottom-left corner, moved by
    // the tileset's tile offset).
    var allShapes = <CollisionShape>[];
    for (final tile in tiles) {
      final tileset = loaded.tilesets.elementAtOrNull(tile.tilesetIndex);
      if (tileset == null) continue;

      final shapes = tileset.getCollisionShapes(tile.localId);
      if (shapes.isEmpty) continue;

      allShapes.addAll(
        TileCollider.placeTileShapes(
          shapes,
          tileRect: tileset.getTileRect(tile.localId),
          tileOffset: tileset.tileOffset,
          gridX: tile.x,
          gridY: tile.y,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          horizontal: tile.flipHorizontal,
          vertical: tile.flipVertical,
          diagonal: tile.flipDiagonal,
        ),
      );
    }

    if (allShapes.isEmpty) return;

    // Optimize by merging adjacent rectangles (always enabled)
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

    if (allShapes.isEmpty) return;

    // Spawn collider entity as child of the layer. The shapes stay in the
    // map's space; the layer's offset (its groups' included) is the
    // entity's, so physics, which carries the map root's position down
    // to it, finds the collision where the layer is drawn.
    final collider = Collider(shapes: allShapes);
    final colliderEntity = world.spawnChild(layerEntity)
      ..insert(Transform2D.from(layerOffset.dx, layerOffset.dy))
      ..insert(GlobalTransform2D())
      ..insert(collider);

    tileConfig.onColliderSpawn?.call(colliderEntity, layerName, collider);
  }

  /// The layer's tiles: from its data on a finite map, or from its chunks
  /// on an infinite one (at the chunks' tile coordinates, which can be
  /// negative). For an infinite map the tiles are also grouped by chunk
  /// into [chunks], when given.
  List<TileData> _buildTileData(
    tiled.TileLayer layer,
    LoadedTilemap loaded, [
    Map<ChunkKey, TileChunk>? chunks,
  ]) {
    final tiles = <TileData>[];

    void addRow(List<int> data, int width, int originX, int originY) {
      if (width <= 0) return;
      for (int i = 0; i < data.length; i++) {
        final rawGid = data[i];
        if (rawGid == 0) continue; // Empty tile

        // Clear flip flags to get actual GID
        final gid = rawGid & 0x1FFFFFFF;

        // Find tileset for this GID
        final lookup = loaded.getTilesetForGid(gid);
        if (lookup == null) continue;

        tiles.add(
          TileData.fromGid(
            rawGid,
            originX + i % width,
            originY + i ~/ width,
            lookup.tilesetIndex,
            lookup.tileset.firstGid,
            animated: loaded.hasAnimation(gid),
          ),
        );
      }
    }

    final data = layer.data;
    if (data != null) {
      addRow(data, layer.width, 0, 0);
      return tiles;
    }

    final layerChunks = layer.chunks;
    if (layerChunks == null) return tiles;
    final tileWidth = loaded.tileWidth.toDouble();
    final tileHeight = loaded.tileHeight.toDouble();
    for (final chunk in layerChunks) {
      final start = tiles.length;
      addRow(chunk.data, chunk.width, chunk.x, chunk.y);
      if (chunks == null || chunk.width <= 0 || chunk.height <= 0) continue;
      // Chunk coordinates in chunks; floor division keeps negative chunks
      // (x = -16 with 16-wide chunks is chunk -1) apart from chunk 0.
      final key = ChunkKey(
        (chunk.x / chunk.width).floor(),
        (chunk.y / chunk.height).floor(),
      );
      chunks[key] = TileChunk(
        key: key,
        width: chunk.width,
        height: chunk.height,
        tiles: tiles.sublist(start),
        worldX: chunk.x * tileWidth,
        worldY: chunk.y * tileHeight,
      );
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
    _Inherited look,
  ) {
    final objects = layer.objects.map((obj) {
      // A tile object takes its tile's class and properties as defaults.
      final rawGid = obj.gid;
      final tile = rawGid == null
          ? null
          : loaded.getTilesetForGid(rawGid & 0x1FFFFFFF);
      final ownType = obj.type.isEmpty ? null : obj.type;
      final tileProperties = tile?.tileset.getProperties(tile.localId);
      final ownProperties = TiledProperties.fromCustomProperties(
        obj.properties,
      );
      return TiledObjectData(
        id: obj.id,
        name: obj.name,
        type: ownType ?? tile?.tileset.getTileClass(tile.localId) ?? obj.type,
        x: obj.x,
        y: obj.y,
        width: obj.width,
        height: obj.height,
        rotation: obj.rotation,
        shape: _parseShape(obj),
        points: _parsePoints(obj),
        gid: obj.gid,
        tile: tile,
        properties: tileProperties == null
            ? ownProperties
            : ownProperties.withDefaults(tileProperties),
        visible: obj.visible,
      );
    }).toList();

    final layerEntity = world.spawnChild(parent)
      ..insert(
        ObjectLayer(
          name: layer.name,
          layerIndex: layerIndex,
          objects: objects,
          drawOrder: layer.drawOrder == tiled.DrawOrder.indexOrder
              ? DrawOrder.indexOrder
              : DrawOrder.topDown,
          color: look.tint,
          opacity: look.opacity,
          visible: look.visible,
          offset: look.offset,
        ),
      )
      ..insert(Transform2D())
      ..insert(GlobalTransform2D());

    config.onLayerSpawn?.call(layerEntity, layer.name);

    // Spawn individual object entities based on objectTypes map
    final objectTypes = config.objectTypes;
    if (objectTypes != null && objectTypes.isNotEmpty) {
      for (final obj in objects) {
        // Only spawn objects with types in the objectTypes map
        final objType = obj.type;
        if (objType == null || !objectTypes.containsKey(objType)) {
          continue;
        }

        final typeConfig = objectTypes[objType]!;
        _spawnObjectEntity(
          world,
          layerEntity.entity,
          obj,
          typeConfig,
          look.offset,
        );
      }
    }
  }

  void _spawnObjectEntity(
    World world,
    Entity layerEntity,
    TiledObjectData obj,
    ObjectTypeConfig typeConfig,
    Offset layerOffset,
  ) {
    // Where the object is drawn in the map: its layer's offset included.
    final entity = world.spawnChild(layerEntity)
      ..insert(Transform2D.from(obj.x + layerOffset.dx, obj.y + layerOffset.dy))
      ..insert(GlobalTransform2D())
      ..insert(TiledObject.fromData(obj));

    // Create collision shapes if enabled for this type
    if (typeConfig.createCollider) {
      final shapes = TileCollider.fromObject(obj);
      if (shapes.isNotEmpty) {
        entity.insert(Collider(shapes: shapes));
      }
    }

    // Call custom setup callback for this type
    typeConfig.onSpawn?.call(entity, obj);
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

  static Color _parseColor(String? hex) {
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

/// What a layer takes from the groups it's in, as Tiled draws it: offsets
/// add up, parallax factors and opacities multiply, it's visible only
/// when every group is, and tints multiply channel by channel.
class _Inherited {
  final Offset offset;
  final Offset parallax;
  final double opacity;
  final bool visible;
  final Color tint;

  const _Inherited({
    this.offset = Offset.zero,
    this.parallax = const Offset(1, 1),
    this.opacity = 1,
    this.visible = true,
    this.tint = const Color(0xFFFFFFFF),
  });

  /// [layer]'s own settings on top of these.
  _Inherited apply(tiled.Layer layer) {
    final own = TilemapSpawnSystem._parseColor(layer.tintColorHex);
    return _Inherited(
      offset: offset + Offset(layer.offsetX, layer.offsetY),
      parallax: Offset(
        parallax.dx * layer.parallaxX,
        parallax.dy * layer.parallaxY,
      ),
      opacity: opacity * layer.opacity,
      visible: visible && layer.visible,
      tint: tint == const Color(0xFFFFFFFF)
          ? own
          : Color.from(
              alpha: tint.a * own.a,
              red: tint.r * own.r,
              green: tint.g * own.g,
              blue: tint.b * own.b,
            ),
    );
  }
}
