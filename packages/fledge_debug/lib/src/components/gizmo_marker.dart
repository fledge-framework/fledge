/// Marker: draw an axis-aligned bounding box gizmo for this entity.
///
/// Reserved for a future "filter which entities show a gizmo" mode.
/// The v0.2 MVP draws every collider when `DebugConfig.showAabbGizmos`
/// is on, without looking at this marker — but exporting it now lets
/// games place it up-front and avoid an API break later.
class DebugAabbGizmo {
  /// Creates a marker.
  const DebugAabbGizmo();
}

/// Marker: draw the collider shapes for this entity.
///
/// See [DebugAabbGizmo] for the "reserved for filtered gizmos" note.
class DebugColliderGizmo {
  /// Creates a marker.
  const DebugColliderGizmo();
}

/// Marker: draw the camera frustum for this camera entity.
///
/// See [DebugAabbGizmo] for the "reserved for filtered gizmos" note.
class DebugCameraFrustumGizmo {
  /// Creates a marker.
  const DebugCameraFrustumGizmo();
}

/// Marker: this UI entity was spawned by [OverlayPopulateSystem].
///
/// The system keys off this component to look up the retained overlay
/// entities across frames — the overlay text is updated in place
/// rather than respawned every tick. Games shouldn't attach it
/// manually; it's part of the plugin's private contract with itself.
class DebugOverlayEntity {
  /// A stable string identifying which line this UI entity represents
  /// (e.g. `"fps"`, `"entityCount"`, `"ambiguity:0"`). Two overlay
  /// entities with the same key collide, so [OverlayPopulateSystem]
  /// only ever inserts one.
  final String key;

  /// Creates a marker with the given [key].
  const DebugOverlayEntity(this.key);
}
