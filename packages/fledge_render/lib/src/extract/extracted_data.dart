/// Marker mixin for data extracted from the main world to the render world.
///
/// This mixin provides semantic meaning and documentation for extracted
/// components. While not enforced at compile time, classes implementing
/// this mixin should follow these guidelines:
///
/// **Immutability**: Extracted data should be immutable. Use `const`
/// constructors and final fields:
///
/// ```dart
/// class ExtractedEnemy with ExtractedData {
///   final double x;
///   final double y;
///   final int spriteIndex;
///
///   const ExtractedEnemy({
///     required this.x,
///     required this.y,
///     required this.spriteIndex,
///   });
/// }
/// ```
///
/// **Pre-computed values**: Transform data during extraction, not during
/// rendering. Convert grid positions to pixels, compute matrices, etc:
///
/// ```dart
/// // Good: Pre-computed in extractor
/// ExtractedSprite(
///   transform: globalTransform.matrix,  // Matrix ready to use
///   sortKey: (position.y * 1000).toInt(),  // Sort key computed
/// )
///
/// // Avoid: Deferring computation
/// ExtractedSprite(
///   position: position,  // Will need to compute matrix later
///   rotation: rotation,  // Will need to combine transforms
/// )
/// ```
///
/// **Render-only data**: Only include fields needed for rendering.
/// Don't copy game logic data like health, AI state, or inventory:
///
/// ```dart
/// // Good: Only render-relevant fields
/// ExtractedEnemy(
///   position: transform.translation,
///   spriteIndex: enemy.currentFrame,
///   tint: enemy.isDamaged ? Colors.red : Colors.white,
/// )
///
/// // Avoid: Game logic data
/// ExtractedEnemy(
///   health: enemy.health,      // Not needed for rendering
///   aiState: enemy.aiState,    // Not needed for rendering
/// )
/// ```
///
/// See also:
/// - [SortableExtractedData] for entities that need draw ordering
/// - [Extractor] for creating extracted data from main world entities
mixin ExtractedData {}

/// Mixin for extracted data that participates in draw ordering.
///
/// Provides a [sortKey] for sorting entities during the queue stage
/// of the render pipeline. This enables efficient batching and correct
/// draw order.
///
/// ## Sort Key Guidelines
///
/// Sort keys are integers that determine draw order. Lower values are
/// drawn first (behind), higher values are drawn last (in front).
///
/// Common sort key strategies:
///
/// **Y-sorting** (top-down games): Sort by Y position so objects lower
/// on screen appear in front:
///
/// ```dart
/// class ExtractedCharacter with SortableExtractedData {
///   @override
///   final int sortKey;
///
///   ExtractedCharacter({required double y, ...})
///     : sortKey = (y * 1000).toInt();  // Multiply for precision
/// }
/// ```
///
/// **Layer-based sorting**: Use [DrawLayer] enum for semantic layer names:
///
/// ```dart
/// import 'package:fledge_render/fledge_render.dart';
///
/// ExtractedSprite({required DrawLayer layer, required double y})
///   : sortKey = layer.sortKey(subOrder: (y * 1000).toInt());
/// ```
///
/// For dynamic layer indices (e.g., tilemaps), use [DrawLayerExtension.sortKeyFromIndex]:
///
/// ```dart
/// ExtractedTile({required int layerIndex, required double y})
///   : sortKey = DrawLayerExtension.sortKeyFromIndex(
///       layerIndex: layerIndex,
///       subOrder: (y * 100).toInt(),
///     );
/// ```
///
/// **Explicit Z-index**: For UI or when explicit control is needed:
///
/// ```dart
/// ExtractedUIElement({required int zIndex})
///   : sortKey = zIndex * 1000;
/// ```
///
/// ## Usage in Render Systems
///
/// Query and sort extracted data in render systems:
///
/// ```dart
/// class SpriteBatchSystem {
///   void run(RenderWorld renderWorld) {
///     final sprites = renderWorld.query1<ExtractedSprite>()
///       .iter()
///       .toList()
///       ..sort((a, b) => a.$2.sortKey.compareTo(b.$2.sortKey));
///
///     for (final (_, sprite) in sprites) {
///       // Render in sorted order
///     }
///   }
/// }
/// ```
///
/// See also:
/// - [ExtractedData] for general extracted data guidelines
/// - [Extractor] for creating sorted extracted data
mixin SortableExtractedData on ExtractedData {
  /// Sort key for draw ordering.
  ///
  /// Lower values are drawn first (behind), higher values drawn last (in front).
  int get sortKey;
}
