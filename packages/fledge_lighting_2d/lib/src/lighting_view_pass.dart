import 'dart:ui' show BlendMode, Canvas, Color, Paint, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show World;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show RenderWorld, ViewPass;

import 'ambient_light.dart';
import 'lighting_render_node.dart';

/// Draws the [AmbientLight] and every light into each `FledgeRenderView`,
/// in the mode [AmbientLight.blend] picks. Added to the app's `ViewPasses`
/// by `LightingPlugin`; nothing else is needed.
class LightingViewPass extends ViewPass {
  /// Creates the pass.
  const LightingViewPass();

  /// How far past the visible world the lighting reaches, so the sub-pixel
  /// camera's edge pixels are covered too.
  static const margin = 4.0;

  static Color _tint(AmbientLight ambient) => Color.lerp(
    const Color(0xFFFFFFFF),
    ambient.color,
    ambient.intensity.clamp(0.0, 1.0),
  )!;

  @override
  void paintBehind(World world, Canvas canvas, Rect visibleWorld) {
    final ambient = world.getResource<AmbientLight>();
    if (ambient == null || ambient.blend != AmbientBlend.underSprites) return;
    if (ambient.intensity <= 0) return;
    final alpha = (ambient.color.a * ambient.intensity).clamp(0.0, 1.0);
    canvas.drawRect(
      ambient.bounds ?? visibleWorld.inflate(margin),
      Paint()..color = ambient.color.withValues(alpha: alpha),
    );
  }

  @override
  void paintOver(World world, Canvas canvas, Rect visibleWorld) {
    final renderWorld = world.getResource<RenderWorld>();
    if (renderWorld == null) return;
    final ambient = world.getResource<AmbientLight>();
    final area = visibleWorld.inflate(margin);
    switch (ambient?.blend) {
      case AmbientBlend.lightMap:
        // In full daylight the map is white wherever the lights reach or
        // not, so only the glows are left to draw.
        if (ambient!.intensity > 0) {
          renderLightMap(
            renderWorld,
            canvas,
            area,
            _tint(ambient),
            bounds: ambient.bounds,
          );
        }
        renderLightGlows(renderWorld, canvas, area);
      case AmbientBlend.overSprites:
        if (ambient!.intensity > 0) {
          canvas.drawRect(
            ambient.bounds ?? area,
            Paint()
              ..color = _tint(ambient)
              ..blendMode = BlendMode.multiply,
          );
        }
        renderLightsToCanvas(
          renderWorld,
          canvas,
          area.size,
          worldViewport: area,
        );
      case AmbientBlend.underSprites || null:
        renderLightsToCanvas(
          renderWorld,
          canvas,
          area.size,
          worldViewport: area,
        );
    }
  }
}
