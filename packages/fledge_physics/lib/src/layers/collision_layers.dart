/// Base collision layer definitions.
///
/// Games can extend these with their own layers starting at [gameLayersStart].
///
/// Example:
/// ```dart
/// abstract class MyGameLayers {
///   // Use framework layers
///   static const int solid = CollisionLayers.solid;
///   static const int trigger = CollisionLayers.trigger;
///
///   // Define game-specific layers (start at bit 8)
///   static const int player = CollisionLayers.gameLayersStart << 0;     // 0x0100
///   static const int enemy = CollisionLayers.gameLayersStart << 1;      // 0x0200
///   static const int projectile = CollisionLayers.gameLayersStart << 2; // 0x0400
/// }
/// ```
abstract class CollisionLayers {
  // Private constructor prevents instantiation.
  CollisionLayers._();

  /// Default layer for static geometry (walls, terrain, obstacles).
  static const int solid = 1 << 0; // 0x0001

  /// Trigger/sensor layer for non-blocking collision detection.
  ///
  /// Entities on this layer generate collision events but don't block movement.
  static const int trigger = 1 << 1; // 0x0002

  /// All layers mask - collides with everything.
  static const int all = 0xFFFFFFFF;

  /// No layers - collides with nothing.
  static const int none = 0;

  /// Starting bit for game-specific layers.
  ///
  /// Bits 0-7 are reserved for framework use.
  /// Bits 8-31 are available for game-specific layers.
  static const int gameLayersStart = 1 << 8; // 0x0100
}
