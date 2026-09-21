import 'dart:ui' show Color;

/// Scene-wide ambient illumination.
///
/// Inserted as an ECS resource by [LightingPlugin] and consumed by
/// [LitFledgeRenderView] as the base fill layer under the sprite pass.
/// A default of white at 0.5 intensity gives "everything is dim by
/// half"; set to [AmbientLight.dark] (or a fully black variant) for a
/// scene where sprites are only visible through the additive light
/// contributions.
class AmbientLight {
  /// Ambient color. The full color is multiplied by [intensity]
  /// before being drawn as a full-screen rect.
  final Color color;

  /// Multiplier on [color] alpha before the ambient rect is filled.
  /// `0` disables ambient (fully dark scene, lights only); `1` uses
  /// the color at its literal alpha.
  final double intensity;

  /// Creates an ambient-light resource.
  const AmbientLight({
    this.color = const Color(0xFFFFFFFF),
    this.intensity = 0.5,
  });

  /// A neutral half-lit ambient — everything visible, just dim.
  static const white = AmbientLight();

  /// Near-dark ambient — sprites are barely visible except where lit.
  static const dark = AmbientLight(color: Color(0xFF000000), intensity: 0.2);
}
