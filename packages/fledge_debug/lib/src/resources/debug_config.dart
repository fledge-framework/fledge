import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show Alignment;

/// Runtime toggles for the debug overlay and gizmos.
///
/// The [DebugPlugin] inserts a [DebugConfig] as a resource on `App`;
/// games flip the fields at runtime (usually by replacing the resource
/// with [copyWith] — nothing caches the object, so this is enough to
/// take effect on the next tick). The overlay populate system reads
/// [showFps] / [showEntityCount] / [showOrderingAmbiguities] /
/// [showSystemTimings] to decide which lines to emit; the gizmos
/// widget reads [showAabbGizmos] / [showColliderGizmos] /
/// [showCameraFrustum] to decide what to paint.
///
/// ```dart
/// final cfg = app.world.getResource<DebugConfig>()!;
/// app.insertResource(cfg.copyWith(showAabbGizmos: true));
/// ```
class DebugConfig {
  /// Show the current smoothed FPS on the overlay.
  final bool showFps;

  /// Show the live entity count on the overlay.
  final bool showEntityCount;

  /// Show `App.checkScheduleOrdering()` output on the overlay whenever
  /// it returns a non-empty list. Cheap enough for every frame — the
  /// scheduler walks its stages, not the world.
  final bool showOrderingAmbiguities;

  /// Show per-schedule system counts and total per-frame wall clock.
  ///
  /// Off by default because it is the most invasive line to add;
  /// full per-system timings are noted as a future enhancement (see
  /// the package README).
  final bool showSystemTimings;

  /// Draw an axis-aligned bounding box around every entity that has a
  /// [Transform2D] and a `Collider`. Magenta stroke.
  final bool showAabbGizmos;

  /// Draw each collider shape (rectangle, ellipse, polygon, polyline,
  /// point) at the entity's world transform. Green stroke. Distinct
  /// from [showAabbGizmos] because a shape's bounding box is a coarser
  /// summary — both together are useful when debugging tight fits.
  final bool showColliderGizmos;

  /// Draw the active `Camera2D`'s visible rectangle in yellow — helpful
  /// for verifying camera follow, letterbox gutters, and parallax
  /// culling.
  final bool showCameraFrustum;

  /// Text colour used for every overlay line.
  final Color overlayTextColor;

  /// Font size (logical pixels) used for every overlay line.
  final double overlayFontSize;

  /// Which corner / edge the overlay anchors to. Only the four corners
  /// and the four edge centres round-trip cleanly onto `UiAnchor`;
  /// arbitrary alignments fall back to [Alignment.topLeft].
  final Alignment overlayAnchor;

  /// Creates a debug configuration.
  const DebugConfig({
    this.showFps = true,
    this.showEntityCount = true,
    this.showOrderingAmbiguities = true,
    this.showSystemTimings = false,
    this.showAabbGizmos = false,
    this.showColliderGizmos = false,
    this.showCameraFrustum = false,
    this.overlayTextColor = const Color(0xFFFFFFFF),
    this.overlayFontSize = 11.0,
    this.overlayAnchor = Alignment.topLeft,
  });

  /// Returns a copy with any subset of fields replaced. Nothing caches
  /// the returned object — insert it back on the app to take effect.
  DebugConfig copyWith({
    bool? showFps,
    bool? showEntityCount,
    bool? showOrderingAmbiguities,
    bool? showSystemTimings,
    bool? showAabbGizmos,
    bool? showColliderGizmos,
    bool? showCameraFrustum,
    Color? overlayTextColor,
    double? overlayFontSize,
    Alignment? overlayAnchor,
  }) {
    return DebugConfig(
      showFps: showFps ?? this.showFps,
      showEntityCount: showEntityCount ?? this.showEntityCount,
      showOrderingAmbiguities:
          showOrderingAmbiguities ?? this.showOrderingAmbiguities,
      showSystemTimings: showSystemTimings ?? this.showSystemTimings,
      showAabbGizmos: showAabbGizmos ?? this.showAabbGizmos,
      showColliderGizmos: showColliderGizmos ?? this.showColliderGizmos,
      showCameraFrustum: showCameraFrustum ?? this.showCameraFrustum,
      overlayTextColor: overlayTextColor ?? this.overlayTextColor,
      overlayFontSize: overlayFontSize ?? this.overlayFontSize,
      overlayAnchor: overlayAnchor ?? this.overlayAnchor,
    );
  }

  /// True if any gizmo class is enabled — the widget skips laying
  /// itself out entirely when everything is off.
  bool get anyGizmoEnabled =>
      showAabbGizmos || showColliderGizmos || showCameraFrustum;
}
