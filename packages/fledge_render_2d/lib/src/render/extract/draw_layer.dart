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
/// ## Y-sorting range
///
/// The packed integer key has room for 100,000 sub-orders per layer, so
/// a Y-derived sub-order (`y * ySortScale`, see
/// [DrawLayerExtension.ySortSubOrder]) is clamped to `0..99,999`. On its
/// own that would make every sprite below y = 0 or beyond y = 9,999.9
/// share a key. The framework sprite path therefore orders by the
/// composite `(sortKey, ExtractedSprite.preciseSubOrder)`:
/// `ExtractedSprite.compareDrawOrder` compares integer sort keys first
/// (so layers always dominate, and everything that ordered differently
/// before still orders the same way) and only breaks ties with the
/// unclamped, full-precision Y sub-order. Y-sorting is therefore
/// unbounded: any finite y, including negative y, orders correctly
/// within a layer (double precision, exact far beyond any practical
/// world size). Equal composite keys keep extraction order.
///
/// Code that sorts *only* by the integer sort key (custom
/// `SortableExtractedData` types, custom render nodes) still sees the
/// clamped 0..9,999.9 Y window; use `ExtractedSprite.sortByDrawOrder`
/// or carry an equivalent tie-breaker to get unbounded Y-sorting.
///
/// ## Custom Layer Indices
///
/// For tilemaps or systems with many layers, use [DrawLayerExtension.sortKeyFromIndex]:
///
/// ```dart
/// // Tilemap with 5 layers (0-4)
/// final sortKey = DrawLayerExtension.sortKeyFromIndex(
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

  /// Scale factor applied to Y-position when deriving sub-order for
  /// Y-sorting.
  ///
  /// With `y * 10` and a `layerMultiplier` of 100,000, entities in
  /// y = 0 .. 9,999.9 land in distinct integer sort-key buckets at 0.1
  /// pixel precision. Outside that window the integer sub-order clamps
  /// (see [ySortSubOrder]); the framework sprite path then breaks ties
  /// with `ExtractedSprite.preciseSubOrder` (`y * ySortScale`,
  /// unclamped), so Y-sorting stays correct for any y. See the
  /// "Y-sorting range" section on [DrawLayer].
  static const int ySortScale = 10;

  /// The integer Y sub-order for an entity at world [y]:
  /// `(y * ySortScale).toInt()` clamped into `0..layerMultiplier - 1` so
  /// it can never bleed into a neighbouring layer.
  ///
  /// This is the value `SpriteExtractor` packs into
  /// `ExtractedSprite.sortKey`. Pass `preciseSubOrder: y * ySortScale`
  /// to the `ExtractedSprite` as well so ties outside the 0..9,999.9
  /// window are broken by the exact position.
  static int ySortSubOrder(double y) =>
      (y * ySortScale).toInt().clamp(0, layerMultiplier - 1);

  /// Computes a sort key for this layer.
  ///
  /// The [subOrder] parameter allows for sub-sorting within the layer,
  /// typically based on Y-position for top-down games:
  ///
  /// ```dart
  /// // Character at y=150.5
  /// final key = DrawLayer.characters.sortKey(
  ///     subOrder: DrawLayerExtension.ySortSubOrder(y));
  /// ```
  ///
  /// [subOrder] should be in the range 0-99,999 to stay within the layer's
  /// sort key range; [ySortSubOrder] clamps for you.
  int sortKey({int subOrder = 0}) => index * layerMultiplier + subOrder;

  /// Computes a sort key from an arbitrary layer index.
  ///
  /// Useful for tilemaps or systems with custom layer counts:
  ///
  /// ```dart
  /// final key = DrawLayerExtension.sortKeyFromIndex(
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
