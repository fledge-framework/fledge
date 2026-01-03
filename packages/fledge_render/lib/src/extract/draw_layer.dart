/// Standard draw layers for organizing render order.
///
/// Each layer represents a range of sort keys, allowing for sub-sorting
/// within each layer (e.g., Y-sorting characters within the characters layer).
///
/// ## Layer Ranges
///
/// | Layer       | Sort Key Range   |
/// |-------------|------------------|
/// | background  | 0 - 99,999       |
/// | ground      | 100,000 - 199,999|
/// | characters  | 200,000 - 299,999|
/// | foreground  | 300,000 - 399,999|
/// | particles   | 400,000 - 499,999|
/// | ui          | 500,000+         |
///
/// ## Usage
///
/// Use [sortKey] to compute a sort key that places sprites in the correct layer:
///
/// ```dart
/// // Simple layer-only sorting
/// final key = DrawLayer.characters.sortKey();
///
/// // Layer with Y-position sub-sorting (top-down games)
/// final key = DrawLayer.characters.sortKey(subOrder: (y * 1000).toInt());
///
/// // In an ExtractedSprite
/// class ExtractedSprite with ExtractedData, SortableExtractedData {
///   @override
///   final int sortKey;
///
///   ExtractedSprite({required DrawLayer layer, required double y})
///     : sortKey = layer.sortKey(subOrder: (y * 1000).toInt());
/// }
/// ```
///
/// ## Custom Layer Indices
///
/// For tilemaps or systems with many layers, use [DrawLayer.sortKeyFromIndex]:
///
/// ```dart
/// // Tilemap with 5 layers (0-4)
/// final sortKey = DrawLayer.sortKeyFromIndex(
///   layerIndex: tileLayer.index,
///   subOrder: tile.y,
/// );
/// ```
enum DrawLayer {
  /// Background elements (sky, distant scenery).
  /// Sort key range: 0 - 99,999
  background,

  /// Ground-level elements (floors, terrain).
  /// Sort key range: 100,000 - 199,999
  ground,

  /// Characters and interactive objects.
  /// Sort key range: 200,000 - 299,999
  characters,

  /// Foreground elements (overlays, weather effects).
  /// Sort key range: 300,000 - 399,999
  foreground,

  /// Particle effects.
  /// Sort key range: 400,000 - 499,999
  particles,

  /// UI elements (always on top).
  /// Sort key range: 500,000+
  ui,
}

/// Extension providing sort key computation for [DrawLayer].
extension DrawLayerExtension on DrawLayer {
  /// The multiplier used to separate layer ranges.
  ///
  /// Each layer has 100,000 possible sub-order values.
  static const int layerMultiplier = 100000;

  /// Computes a sort key for this layer.
  ///
  /// The [subOrder] parameter allows for sub-sorting within the layer,
  /// typically based on Y-position for top-down games:
  ///
  /// ```dart
  /// // Character at y=150.5
  /// final key = DrawLayer.characters.sortKey(subOrder: (y * 1000).toInt());
  /// ```
  ///
  /// [subOrder] should be in the range 0-99,999 to stay within the layer's
  /// sort key range.
  int sortKey({int subOrder = 0}) => index * layerMultiplier + subOrder;

  /// Computes a sort key from an arbitrary layer index.
  ///
  /// Useful for tilemaps or systems with custom layer counts:
  ///
  /// ```dart
  /// final key = DrawLayer.sortKeyFromIndex(
  ///   layerIndex: layer.index,
  ///   subOrder: tile.y,
  /// );
  /// ```
  ///
  /// The [layerIndex] is the layer number (0, 1, 2, ...).
  /// The [subOrder] allows sub-sorting within the layer (default 0).
  static int sortKeyFromIndex({required int layerIndex, int subOrder = 0}) =>
      layerIndex * layerMultiplier + subOrder;
}
