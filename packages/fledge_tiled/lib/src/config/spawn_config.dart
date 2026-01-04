import 'package:fledge_ecs/fledge_ecs.dart';

import '../collision/collision_shapes.dart';
import '../components/object_layer.dart';

/// Configuration for tile layer spawning.
///
/// Controls how tile layers generate collision shapes.
class TileLayerConfig {
  /// Whether to generate colliders from tile collision data.
  ///
  /// When enabled, tiles with collision shapes defined in their tileset
  /// will have those shapes collected and spawned as a [Collider] component.
  /// Adjacent rectangular shapes are automatically merged for efficiency.
  final bool generateColliders;

  /// Layer names to generate tile colliders for (null = all layers).
  ///
  /// Only tile layers with names in this set will have colliders generated.
  /// If null, all tile layers with collision data will be processed.
  final Set<String>? colliderLayers;

  /// Callback for custom tile collider entity setup.
  ///
  /// Called when a tile collider entity is spawned, allowing custom
  /// component insertion. The [Collider] is already attached.
  final void Function(
    EntityCommands entity,
    String layerName,
    Collider collider,
  )? onColliderSpawn;

  const TileLayerConfig({
    this.generateColliders = false,
    this.colliderLayers,
    this.onColliderSpawn,
  });
}

/// Configuration for spawning a specific object type.
///
/// Each object type can have its own collider and spawn behavior.
class ObjectTypeConfig {
  /// Whether to create collision shapes from the object's geometry.
  ///
  /// When true, the object's shape (rectangle, ellipse, polygon, etc.)
  /// is converted to a [Collider] component.
  final bool createCollider;

  /// Callback for custom setup when this object type is spawned.
  ///
  /// Called after the entity is created with Transform2D, GlobalTransform2D,
  /// TiledObject, and optionally Collider. Use this to add custom components
  /// based on the object's properties.
  final void Function(EntityCommands entity, TiledObjectData object)? onSpawn;

  const ObjectTypeConfig({
    this.createCollider = true,
    this.onSpawn,
  });
}

/// Configuration for tilemap spawning.
///
/// Controls how tile layers and objects are spawned from a Tiled map.
///
/// Example:
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
///         createCollider: true,
///         onSpawn: (entity, obj) {
///           entity.insert(Enemy(health: obj.properties.getIntOr('health', 100)));
///         },
///       ),
///       'spawn_point': ObjectTypeConfig(
///         createCollider: false,
///       ),
///     },
///   ),
/// )
/// ```
class TilemapSpawnConfig {
  /// Configuration for tile layers.
  final TileLayerConfig tileConfig;

  /// Object spawning configuration by type.
  ///
  /// Keys are Tiled object type names, values configure how to spawn them.
  /// Only objects with types present in this map will be spawned as entities.
  /// If null or empty, no objects are spawned as individual entities.
  ///
  /// Example:
  /// ```dart
  /// objectTypes: {
  ///   'transition': ObjectTypeConfig(
  ///     createCollider: true,
  ///     onSpawn: (entity, obj) => entity.insert(TransitionZone(...)),
  ///   ),
  /// }
  /// ```
  final Map<String, ObjectTypeConfig>? objectTypes;

  /// Callback for custom layer entity setup.
  ///
  /// Called for each tile layer and object layer spawned.
  final void Function(EntityCommands entity, String layerName)? onLayerSpawn;

  const TilemapSpawnConfig({
    this.tileConfig = const TileLayerConfig(),
    this.objectTypes,
    this.onLayerSpawn,
  });
}
