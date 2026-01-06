/// Mixin for resources that participate in save/load operations.
///
/// Implement this mixin on any resource that should be persisted.
/// The [SaveManager] will automatically discover and serialize all
/// resources implementing [Saveable] when saving the game.
///
/// Example:
/// ```dart
/// class Inventory with Saveable {
///   final List<Item> items = [];
///
///   @override
///   String get saveKey => 'inventory';
///
///   @override
///   Map<String, dynamic> toSaveJson() => {
///     'items': items.map((i) => i.toJson()).toList(),
///   };
///
///   @override
///   void loadFromSaveJson(Map<String, dynamic> json) {
///     items.clear();
///     final itemsJson = json['items'] as List<dynamic>? ?? [];
///     items.addAll(itemsJson.map((j) => Item.fromJson(j)));
///   }
/// }
/// ```
mixin Saveable {
  /// Unique key identifying this resource in save files.
  ///
  /// Should be a stable identifier that doesn't change between versions.
  /// Common examples: 'inventory', 'progress', 'settings', 'relationships'.
  String get saveKey;

  /// Serialize the resource state to JSON.
  ///
  /// Called by [SaveManager] when creating a save file.
  /// Return a map containing all state that should be persisted.
  Map<String, dynamic> toSaveJson();

  /// Restore the resource state from JSON.
  ///
  /// Called by [SaveManager] when loading a save file.
  /// The [json] parameter contains the data previously returned
  /// by [toSaveJson]. Handle missing keys gracefully for
  /// backwards compatibility with older save files.
  void loadFromSaveJson(Map<String, dynamic> json);
}
