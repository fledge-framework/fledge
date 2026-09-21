import 'dart:ui' show Canvas, Paint, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show App;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show
        CanvasSpriteDrawer,
        RenderWorld,
        SpriteDrawer,
        renderSpritesToDrawer;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        CustomPaint,
        CustomPainter,
        SizedBox,
        Size,
        StatelessWidget,
        Widget;

import 'ambient_light.dart';
import 'lighting_render_node.dart';

/// Lighting-aware drop-in replacement for `FledgeRenderView`.
///
/// Paints, on the same `CustomPaint` canvas, in this order:
///
/// 1. Ambient fill — full-screen rect of
///    `AmbientLight.color × AmbientLight.intensity` at normal blend.
/// 2. Sprites — delegates to `renderSpritesToDrawer`, identical to
///    what `FledgeRenderView` does.
/// 3. Lights — every `ExtractedLight` drawn additively on top through
///    [renderLightsToCanvas].
///
/// Callers still drive the game loop themselves — this widget only
/// paints. Read [AmbientLight] off the app world; if none is
/// registered, ambient is skipped (equivalent to a black background).
///
/// See the package README for the reasoning behind picking a widget
/// wrapper over a render-graph node in v0.1.
class LitFledgeRenderView extends StatelessWidget {
  /// The Fledge app whose render world will be painted.
  final App app;

  /// Creates a lighting-aware render view.
  const LitFledgeRenderView({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    // `SizedBox.expand` mirrors `FledgeRenderView` — a childless
    // `CustomPaint` would otherwise collapse to `Size.zero`.
    return SizedBox.expand(
      child: CustomPaint(painter: _LitFledgeRenderPainter(app: app)),
    );
  }
}

class _LitFledgeRenderPainter extends CustomPainter {
  final App app;

  _LitFledgeRenderPainter({required this.app});

  @override
  void paint(Canvas canvas, Size size) {
    final ambient = app.world.getResource<AmbientLight>();
    if (ambient != null && ambient.intensity > 0) {
      final base = ambient.color;
      final scaledAlpha = (base.a * ambient.intensity).clamp(0.0, 1.0);
      final paint = Paint()..color = base.withValues(alpha: scaledAlpha);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }

    final drawer = app.world.getResource<SpriteDrawer>();
    final renderWorld = app.world.getResource<RenderWorld>();
    if (drawer == null || renderWorld == null) return;

    final canvasDrawer = drawer is CanvasSpriteDrawer ? drawer : null;
    canvasDrawer?.beginFrame(canvas);
    try {
      renderSpritesToDrawer(renderWorld, drawer);
    } finally {
      canvasDrawer?.endFrame();
    }

    // Additive light pass. Runs on the same canvas so the underlying
    // sprite pixels get brightened directly.
    renderLightsToCanvas(renderWorld, canvas, size);
  }

  @override
  bool shouldRepaint(covariant _LitFledgeRenderPainter oldDelegate) => true;
}
