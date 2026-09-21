import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

/// The kind of light source represented by a [Light2D] component.
///
/// - [LightType.point] — omnidirectional; falls off with distance.
/// - [LightType.directional] — parallel rays, treated as an infinite
///   tint across the whole viewport in the Canvas backend.
/// - [LightType.spot] — cone-shaped; falls off with distance and is
///   clipped to a wedge around [Light2D.direction].
enum LightType { point, directional, spot }

/// A dynamic 2D light source.
///
/// Attach to an entity with `Transform2D` + `GlobalTransform2D` and the
/// [LightExtractor] will emit an `ExtractedLight` for the render pass
/// each frame. The Canvas backend draws each extracted light as an
/// additive radial gradient (point/spot) or a full-screen tint
/// (directional).
///
/// ## Example
///
/// ```dart
/// // Torch on the player.
/// world.spawn()
///   ..insert(Transform2D.from(200, 200))
///   ..insert(GlobalTransform2D.identity())
///   ..insert(Light2D.point(
///     color: const Color(0xFFFFDD88),
///     radius: 180,
///     innerRadius: 40,
///   ));
/// ```
///
/// ## Falloff
///
/// Distance-based falloff is linear between [innerRadius] and [radius]
/// (see `linearAttenuation`). Pixels inside `innerRadius` are at full
/// intensity; pixels at or past `radius` are dark. Setting
/// `innerRadius == 0` gives a hard-centered gradient; setting it near
/// `radius` gives a nearly-hard-edged disc.
///
/// ## Shadows
///
/// [castsShadow] is reserved for future SDF shadow tracing. It has no
/// effect in the Phase 6c MVP.
class Light2D {
  /// The kind of light source.
  final LightType type;

  /// Base light color; alpha is honoured (a translucent color dims the
  /// light).
  final Color color;

  /// Multiplier on [color] intensity. Clamped by the drawer to `[0..1]`
  /// where it matters; larger values are allowed and stack when lights
  /// overlap.
  final double intensity;

  /// Outer radius in world units. Ignored for [LightType.directional].
  final double radius;

  /// Inner radius in world units — the region of full intensity before
  /// falloff begins. `0` produces a smooth centered falloff; values
  /// approaching [radius] produce a nearly-hard-edged disc.
  final double innerRadius;

  /// Cone half-angle in radians. Only meaningful for
  /// [LightType.spot]; the emitted wedge spans `direction ± angle`.
  final double angle;

  /// Direction for [LightType.directional] and [LightType.spot].
  /// Should be a unit vector; the factory constructors normalize for
  /// you.
  final Vector2 direction;

  /// Reserved for future SDF shadow tracing. **No effect in v0.1.**
  final bool castsShadow;

  /// Creates a light with all fields explicit. Prefer the [Light2D.point],
  /// [Light2D.directional], and [Light2D.spot] factory constructors
  /// unless you have a reason to bypass their defaulting.
  const Light2D({
    required this.type,
    required this.color,
    this.intensity = 1.0,
    this.radius = 100.0,
    this.innerRadius = 0.0,
    this.angle = 0.5,
    required this.direction,
    this.castsShadow = false,
  });

  /// Convenience for a point light. Direction is unused for point
  /// lights but must be non-null; a placeholder unit vector is used.
  factory Light2D.point({
    required Color color,
    double intensity = 1.0,
    double radius = 100.0,
    double innerRadius = 0.0,
  }) => Light2D(
    type: LightType.point,
    color: color,
    intensity: intensity,
    radius: radius,
    innerRadius: innerRadius,
    direction: Vector2(0, -1),
  );

  /// Convenience for a directional light. [direction] is normalized to
  /// a unit vector.
  factory Light2D.directional({
    required Color color,
    required Vector2 direction,
    double intensity = 1.0,
  }) => Light2D(
    type: LightType.directional,
    color: color,
    intensity: intensity,
    radius: double.infinity,
    direction: direction.normalized(),
  );

  /// Convenience for a spot light. [direction] is normalized to a unit
  /// vector; [angle] is the cone half-angle in radians.
  factory Light2D.spot({
    required Color color,
    required Vector2 direction,
    required double angle,
    double intensity = 1.0,
    double radius = 100.0,
    double innerRadius = 0.0,
  }) => Light2D(
    type: LightType.spot,
    color: color,
    intensity: intensity,
    radius: radius,
    innerRadius: innerRadius,
    angle: angle,
    direction: direction.normalized(),
  );
}
