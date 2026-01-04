import '../layers/collision_layers.dart';

/// Configuration for collision behavior.
///
/// Attach alongside [Collider] to control collision layer filtering
/// and sensor behavior.
///
/// ## Layer/Mask System
///
/// Collision occurs when both entities agree to interact:
/// ```
/// (A.layer & B.mask) != 0 && (B.layer & A.mask) != 0
/// ```
///
/// - [layer] - What layers this entity belongs to (what it IS)
/// - [mask] - What layers this entity collides with (what it INTERACTS WITH)
///
/// ## Sensors
///
/// When [isSensor] is true, the entity generates [CollisionEvent]s but
/// doesn't block movement. Useful for triggers, transition zones, etc.
///
/// ## Defaults
///
/// Entities without [CollisionConfig] are treated as:
/// - layer: [CollisionLayers.all] (belongs to all layers)
/// - mask: [CollisionLayers.all] (collides with all layers)
/// - isSensor: false (blocks movement)
///
/// Example:
/// ```dart
/// // Player - solid, collides with solid and trigger layers
/// entity.insert(CollisionConfig(
///   layer: GameLayers.player,
///   mask: GameLayers.solid | GameLayers.trigger | GameLayers.enemy,
/// ));
///
/// // Transition zone - sensor that only interacts with player
/// entity.insert(CollisionConfig.sensor(
///   layer: GameLayers.trigger,
///   mask: GameLayers.player,
/// ));
/// ```
class CollisionConfig {
  /// Bitmask of layers this entity belongs to.
  ///
  /// Use [CollisionLayers] constants or game-specific layers:
  /// `GameLayers.player | GameLayers.enemy`
  final int layer;

  /// Bitmask of layers this entity collides with.
  ///
  /// Collision occurs when: `(A.layer & B.mask) != 0 && (B.layer & A.mask) != 0`
  final int mask;

  /// If true, generates [CollisionEvent] but doesn't block movement.
  ///
  /// Useful for triggers, transition zones, and detection areas.
  final bool isSensor;

  /// Creates a collision configuration.
  ///
  /// By default, belongs to all layers, collides with all layers,
  /// and blocks movement (not a sensor).
  const CollisionConfig({
    this.layer = CollisionLayers.all,
    this.mask = CollisionLayers.all,
    this.isSensor = false,
  });

  /// Creates a sensor configuration (generates events, no blocking).
  ///
  /// By default uses [CollisionLayers.trigger] layer and collides
  /// with all layers.
  const CollisionConfig.sensor({
    this.layer = CollisionLayers.trigger,
    this.mask = CollisionLayers.all,
  }) : isSensor = true;

  /// Creates a solid configuration (blocks movement).
  ///
  /// By default uses [CollisionLayers.solid] layer and collides
  /// with all layers.
  const CollisionConfig.solid({
    this.layer = CollisionLayers.solid,
    this.mask = CollisionLayers.all,
  }) : isSensor = false;

  /// Returns true if this entity can collide with another.
  ///
  /// Collision is bidirectional: both entities must have overlapping
  /// layer/mask pairs.
  bool canCollideWith(CollisionConfig other) {
    return (layer & other.mask) != 0 && (other.layer & mask) != 0;
  }

  @override
  String toString() => 'CollisionConfig(layer: 0x${layer.toRadixString(16)}, '
      'mask: 0x${mask.toRadixString(16)}, isSensor: $isSensor)';
}
