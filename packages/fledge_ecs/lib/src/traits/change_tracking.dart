/// Mixin for resources that need frame-level change tracking.
///
/// Provides a simple pattern for tracking whether a resource
/// changed during the current frame. Useful for UI updates
/// and optimization.
///
/// ## Usage
///
/// ```dart
/// class Inventory with ChangeTracking {
///   final List<Item> items = [];
///
///   void addItem(Item item) {
///     items.add(item);
///     markChanged();
///   }
///
///   void removeItem(Item item) {
///     items.remove(item);
///     markChanged();
///   }
/// }
///
/// // In your game loop (start of frame):
/// inventory.resetChangeTracking();
///
/// // In your UI:
/// if (inventory.changedThisFrame) {
///   rebuildInventoryUI();
/// }
/// ```
mixin ChangeTracking {
  bool _changed = false;

  /// Whether this resource was modified this frame.
  bool get changedThisFrame => _changed;

  /// Mark this resource as modified.
  ///
  /// Call this whenever state changes that should trigger updates.
  void markChanged() => _changed = true;

  /// Reset the change flag at the start of each frame.
  ///
  /// Call this at the beginning of your game loop.
  void resetChangeTracking() => _changed = false;
}
