import 'dart:math' as math;
import 'dart:ui'
    show BlendMode, Canvas, Color, Gradient, Offset, Paint, Path, Rect, Size;

import 'package:fledge_render_2d/fledge_render_2d.dart' show RenderWorld;

import 'extracted_light.dart';
import 'light2d.dart';

/// Draw every [ExtractedLight] in [renderWorld] additively onto
/// [canvas], sized to [size].
///
/// Called by `LitFledgeRenderView` after the sprite pass and before
/// the frame is committed. Exposed as a top-level function so custom
/// paint pipelines can call it directly without going through the
/// widget.
///
/// - `LightType.point` and `LightType.spot`: a radial gradient shader
///   drawn onto a `light.radius`-radius rectangle with
///   `BlendMode.plus`. Spot lights additionally clip to a wedge
///   around `light.direction`.
/// - `LightType.directional`: a full-viewport additive rect in the
///   light's colour × intensity.
///
/// ## Camera-aware rendering
///
/// [worldViewport] tells the culler and the directional-fill which
/// world rect the canvas is currently showing. Under
/// `LitFledgeRenderView`'s camera-aware wrap the canvas has already
/// been translated so world (camera) sits at the centre — pass the
/// same world rect the camera is showing. Without a camera the
/// widget passes `Offset.zero & size`, which keeps the old
/// world = screen behaviour and lets callers that don't run through
/// the camera-aware wrap stay unchanged.
///
/// The Canvas backend does not implement per-pixel normal-map
/// contributions — that's future GPU work. Every gradient here is a
/// pure 2D screen-space effect.
void renderLightsToCanvas(
  RenderWorld renderWorld,
  Canvas canvas,
  Size size, {
  Rect? worldViewport,
}) {
  final viewportRect = worldViewport ?? (Offset.zero & size);
  for (final (_, light) in renderWorld.query1<ExtractedLight>().iter()) {
    switch (light.type) {
      case LightType.directional:
        _drawDirectional(canvas, viewportRect, light);
      case LightType.point:
        _drawRadial(canvas, viewportRect, light);
      case LightType.spot:
        canvas.save();
        try {
          canvas.clipPath(_spotWedge(light));
          _drawRadial(canvas, viewportRect, light);
        } finally {
          canvas.restore();
        }
    }
  }
}

Color _scaleAlpha(Color color, double factor) {
  final scaled = (color.a * factor).clamp(0.0, 1.0);
  return color.withValues(alpha: scaled);
}

void _drawDirectional(Canvas canvas, Rect viewport, ExtractedLight light) {
  final tint = _scaleAlpha(light.color, light.intensity);
  final paint = Paint()
    ..color = tint
    ..blendMode = BlendMode.plus;
  canvas.drawRect(viewport, paint);
}

void _drawRadial(Canvas canvas, Rect viewport, ExtractedLight light) {
  // A zero or negative radius has no visual effect — skip so the
  // gradient constructor never receives a degenerate rect.
  if (light.radius <= 0) return;

  final center = Offset(light.position.x, light.position.y);
  final radius = light.radius;

  // Cheap viewport reject: if the light's bounding box is completely
  // off-screen, drop it. Saves a `drawRect` + shader compile per
  // frame on off-screen sources.
  final lightRect = Rect.fromCircle(center: center, radius: radius);
  if (!lightRect.overlaps(viewport)) return;

  // `innerRadius` is a fraction of the outer radius when translated
  // to a gradient stop: the first stop sits at innerRadius / radius,
  // giving full color from center to innerRadius, then falling off.
  final innerStop = (light.innerRadius / radius).clamp(0.0, 1.0);
  final coreColor = _scaleAlpha(light.color, light.intensity);
  const transparent = Color(0x00000000);

  final shader = Gradient.radial(
    center,
    radius,
    <Color>[coreColor, coreColor, transparent],
    <double>[0.0, innerStop, 1.0],
  );

  final paint = Paint()
    ..shader = shader
    ..blendMode = BlendMode.plus;

  canvas.drawRect(lightRect, paint);
}

/// Build a wedge-shaped clip path centred on the light's world-space
/// position, opening in the direction unit vector by `±angle`.
///
/// Chosen over a per-fragment mask because Canvas cannot sample a
/// shader mask cheaply. `clipPath` is slow-ish in raster mode but
/// perfectly usable for a handful of spot lights per scene.
Path _spotWedge(ExtractedLight light) {
  final center = Offset(light.position.x, light.position.y);
  final direction = light.direction;
  final base = math.atan2(direction.y, direction.x);
  // Slight padding on the radius so the wedge fully contains the
  // gradient rect corners at oblique angles.
  final r = light.radius * 1.5;
  final start = base - light.angle;
  final end = base + light.angle;

  final path = Path()
    ..moveTo(center.dx, center.dy)
    ..lineTo(center.dx + math.cos(start) * r, center.dy + math.sin(start) * r)
    ..arcTo(
      Rect.fromCircle(center: center, radius: r),
      start,
      end - start,
      false,
    )
    ..close();
  return path;
}
