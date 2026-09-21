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

  /// Opt-in flag for dynamic-vs-dynamic blocking.
  ///
  /// Two dynamic bodies (both carrying [Velocity]) block each other
  /// during collision resolution when **both** have this flag set and
  /// their layer / mask pair agrees. Neither body is pushed —
  /// resolution zeros the blocked axis on each side, so if both are
  /// moving into each other they simply stop.
  ///
  /// Static-vs-dynamic blocking is unaffected — a dynamic body is
  /// always blocked by static colliders it can collide with,
  /// regardless of this flag.
  ///
  /// Default: `false`, so pre-existing dynamic bodies keep passing
  /// through each other.
  final bool blocksDynamic;

  /// After this much continuous contact with another dynamic body
  /// that also has [yieldAfter] set, blocking between the two turns
  /// off (they pass through each other) until they separate. When
  /// they separate the yield resets and blocking resumes.
  ///
  /// Contact time is measured in the physics clock — deterministic
  /// under [PhysicsMode.fixed], approximate under
  /// [PhysicsMode.variable]. When two bodies with different
  /// `yieldAfter` values meet, the pair yields at
  /// `min(a.yieldAfter, b.yieldAfter)`.
  ///
  /// Only applies to dynamic-vs-dynamic blocking (both bodies must
  /// also carry [blocksDynamic]) — static walls never yield to
  /// dynamic bodies.
  ///
  /// Default: `null`, so pairs stay blocked forever.
  final Duration? yieldAfter;

  /// Creates a collision configuration.
  ///
  /// By default, belongs to all layers, collides with all layers,
  /// blocks movement (not a sensor), and does not participate in
  /// dynamic-vs-dynamic blocking.
  const CollisionConfig({
    this.layer = CollisionLayers.all,
    this.mask = CollisionLayers.all,
    this.isSensor = false,
    this.blocksDynamic = false,
    this.yieldAfter,
  });

  /// Creates a sensor configuration (generates events, no blocking).
  ///
  /// By default uses [CollisionLayers.trigger] layer and collides
  /// with all layers.
  const CollisionConfig.sensor({
    this.layer = CollisionLayers.trigger,
    this.mask = CollisionLayers.all,
  }) : isSensor = true,
       blocksDynamic = false,
       yieldAfter = null;

  /// Creates a solid configuration (blocks movement).
  ///
  /// By default uses [CollisionLayers.solid] layer and collides
  /// with all layers.
  const CollisionConfig.solid({
    this.layer = CollisionLayers.solid,
    this.mask = CollisionLayers.all,
    this.blocksDynamic = false,
    this.yieldAfter,
  }) : isSensor = false;

  /// Returns true if this entity can collide with another.
  ///
  /// Collision is bidirectional: both entities must have overlapping
  /// layer/mask pairs.
  bool canCollideWith(CollisionConfig other) {
    return (layer & other.mask) != 0 && (other.layer & mask) != 0;
  }

  @override
  String toString() =>
      'CollisionConfig(layer: 0x${layer.toRadixString(16)}, '
      'mask: 0x${mask.toRadixString(16)}, isSensor: $isSensor)';
}
