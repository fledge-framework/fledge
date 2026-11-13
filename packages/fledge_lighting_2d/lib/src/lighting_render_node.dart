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
  final (colors, stops) = falloffStops(coreColor, innerStop, light.bands);
  final shader = Gradient.radial(center, radius, colors, stops);

  final paint = Paint()
    ..shader = shader
    ..blendMode = BlendMode.plus;

  // A circle, not its bounding rect: nothing past the light's edge is
  // touched, whatever a renderer does beyond the gradient's last stop.
  if (light.aspect == 1) {
    canvas.drawCircle(center, radius, paint);
    return;
  }
  // An ellipse: the circle, squashed about its centre.
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..scale(1, light.aspect)
    ..translate(-center.dx, -center.dy)
    ..drawCircle(center, radius, paint)
    ..restore();
}

/// Gradient samples of the smooth falloff, between the inner radius and
/// the edge.
const _smoothSamples = 12;

/// A hair, in gradient units: how close two stops can be for a hard step.
/// Stops are never repeated, since renderers disagree on which colour wins
/// at a repeated stop (and some extend the wrong one past the last stop).
const _step = 1e-3;

/// The gradient for a light of [core] colour that's full strength out to
/// [innerStop] (a fraction of its radius) and gone at the edge.
///
/// With [bands] 0, the light fades as light does: quickly near the source,
/// then a long soft tail that reaches nothing with no visible edge
/// (`(1 - u²)²` of the distance `u` past the inner radius). With [bands]
/// > 0 the same curve is stepped into that many flat rings, for a
/// pixel-art look.
(List<Color>, List<double>) falloffStops(
  Color core,
  double innerStop,
  int bands,
) {
  const transparent = Color(0x00000000);
  final inner = innerStop.clamp(0.0, 1.0 - _step * 4);
  double level(double u) {
    final f = 1 - u * u;
    return f * f;
  }

  final colors = <Color>[core];
  final stops = <double>[0.0];
  if (inner > 0) {
    colors.add(core);
    stops.add(inner);
  }
  if (bands <= 0) {
    for (var i = 1; i < _smoothSamples; i++) {
      final u = i / _smoothSamples;
      colors.add(_scaleAlpha(core, level(u)));
      stops.add(inner + (1 - inner) * u);
    }
  } else {
    for (var k = 0; k < bands; k++) {
      // Ring k: one flat level, the curve at the ring's middle.
      final start = inner + (1 - inner) * k / bands;
      final end = inner + (1 - inner) * (k + 1) / bands;
      final ring = _scaleAlpha(core, level((k + 0.5) / bands));
      colors.addAll([ring, ring]);
      stops.addAll([start + (k == 0 && inner == 0 ? 0 : _step), end - _step]);
    }
  }
  colors.add(transparent);
  stops.add(1.0);
  return (colors, stops);
}

/// Draws the [AmbientBlend.lightMap] model over sprites already on
/// [canvas]: a layer filled with [base] (the light everything gets) with
/// every light added in, multiplied onto the scene. [area] is the world
/// rect to cover (the visible world, a little inflated); [bounds], if
/// given, limits the darkening to that rect (full light outside it).
void renderLightMap(
  RenderWorld renderWorld,
  Canvas canvas,
  Rect area,
  Color base, {
  Rect? bounds,
}) {
  canvas.saveLayer(area, Paint()..blendMode = BlendMode.multiply);
  try {
    final fill = Paint()..color = base.withValues(alpha: 1);
    if (bounds == null) {
      canvas.drawRect(area, fill);
    } else {
      canvas
        ..drawRect(area, Paint()..color = const Color(0xFFFFFFFF))
        ..drawRect(bounds, fill);
    }
    renderLightsToCanvas(renderWorld, canvas, area.size, worldViewport: area);
  } finally {
    canvas.restore();
  }
}

/// Adds every light's `glow` halo over the scene: half the light's radius,
/// full colour at the centre, at `glow` x intensity strength.
void renderLightGlows(RenderWorld renderWorld, Canvas canvas, Rect area) {
  for (final (_, light) in renderWorld.query1<ExtractedLight>().iter()) {
    if (light.glow <= 0 || light.type == LightType.directional) continue;
    final radius = light.radius / 2;
    if (radius <= 0) continue;
    final center = Offset(light.position.x, light.position.y);
    final rect = Rect.fromCircle(center: center, radius: radius);
    if (!rect.overlaps(area)) continue;
    final core = _scaleAlpha(light.color, light.glow * light.intensity);
    final (colors, stops) = falloffStops(core, 0, 0);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(center, radius, colors, stops),
    );
  }
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
