import 'dart:ui' show Color;

import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:vector_math/vector_math.dart';

import 'light2d.dart';

/// Render-world data extracted from a [Light2D] + `GlobalTransform2D`
/// pair each frame.
///
/// Mirrors `ExtractedSprite`'s shape: the render world sees only this
/// value type, never the main-world component or entity behind it.
/// `LightingRenderNode` / `renderLightsToCanvas` read from these
/// exclusively.
class ExtractedLight {
  /// The main-world entity this light was extracted from (diagnostic).
  final Entity entity;

  /// The light's classification.
  final LightType type;

  /// World-space position of the light (copied off
  /// `GlobalTransform2D`).
  final Vector2 position;

  /// The light's tint colour.
  final Color color;

  /// Multiplier on [color] intensity.
  final double intensity;

  /// Outer radius in world units.
  final double radius;

  /// Inner (full-intensity) radius in world units.
  final double innerRadius;

  /// Cone half-angle in radians (spot lights only).
  final double angle;

  /// Direction unit vector (directional/spot lights).
  final Vector2 direction;

  /// Reserved for future shadow tracing.
  final bool castsShadow;

  /// Creates an extracted light.
  const ExtractedLight({
    required this.entity,
    required this.type,
    required this.position,
    required this.color,
    required this.intensity,
    required this.radius,
    required this.innerRadius,
    required this.angle,
    required this.direction,
    this.castsShadow = false,
  });
}
