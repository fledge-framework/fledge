import 'dart:ui' show BlendMode, Canvas, Color, Offset, Paint, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show App;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show
        ActiveCameraView,
        CanvasSpriteDrawer,
        RenderWorld,
        SpriteDrawer,
        renderSpritesToDrawer,
        withActiveCameraCanvas;
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
/// Paint order depends on `AmbientLight.blend`:
///
/// - [AmbientBlend.underSprites] (default, backward-compatible):
///   ambient fill → sprites → additive lights. Sprites always draw at
///   full brightness.
/// - [AmbientBlend.overSprites]: sprites → ambient multiply →
///   additive lights. Ambient darkens the sprite layer too. The
///   pre-sprite fill is skipped in this mode so empty cells are not
///   double-darkened.
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
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final overSprites =
        ambient != null && ambient.blend == AmbientBlend.overSprites;

    // Pre-sprite fill — only in underSprites mode. In overSprites we
    // skip this so empty cells aren't double-darkened by both the
    // fill and the multiply pass (item 18 in the fledge-handoff).
    if (ambient != null && !overSprites && ambient.intensity > 0) {
      final base = ambient.color;
      final scaledAlpha = (base.a * ambient.intensity).clamp(0.0, 1.0);
      final paint = Paint()..color = base.withValues(alpha: scaledAlpha);
      canvas.drawRect(fullRect, paint);
    }

    final drawer = app.world.getResource<SpriteDrawer>();
    final renderWorld = app.world.getResource<RenderWorld>();
    if (drawer == null || renderWorld == null) return;

    final canvasDrawer = drawer is CanvasSpriteDrawer ? drawer : null;
    canvasDrawer?.beginFrame(canvas);
    try {
      // Sprite pass and additive lights follow the active camera
      // (Batch 3 item 15). The ambient-multiply pass stays in screen
      // space — it's a full-viewport rect and shouldn't scroll with
      // the world.
      withActiveCameraCanvas(app.world, canvas, size, () {
        renderSpritesToDrawer(renderWorld, drawer);
      });
    } finally {
      canvasDrawer?.endFrame();
    }

    // Over-sprite multiply pass — darkens the entire sprite layer
    // toward ambient.color at strength ambient.intensity. Sprites
    // whose light source hasn't been drawn yet appear at the ambient
    // level; the additive light pass immediately below then brightens
    // them back up wherever a light shines.
    if (overSprites && ambient.intensity > 0) {
      final tint = Color.lerp(
        const Color(0xFFFFFFFF),
        ambient.color,
        ambient.intensity.clamp(0.0, 1.0),
      )!;
      final paint = Paint()
        ..color = tint.withValues(alpha: 1.0)
        ..blendMode = BlendMode.multiply;
      canvas.drawRect(fullRect, paint);
    }

    // Additive light pass — runs in world space so light discs stay
    // aligned with the sprites they light up. Compute the world-space
    // viewport rect so directional lights fill the visible world and
    // point / spot lights cull against it. Falls back to
    // `Offset.zero & size` (world = screen) when no camera exists.
    final cameraView = app.world.getResource<ActiveCameraView>();
    final worldViewport = cameraView == null
        ? Offset.zero & size
        : Rect.fromLTWH(
            cameraView.x - size.width / 2,
            cameraView.y - size.height / 2,
            size.width,
            size.height,
          );
    withActiveCameraCanvas(app.world, canvas, size, () {
      renderLightsToCanvas(
        renderWorld,
        canvas,
        size,
        worldViewport: worldViewport,
      );
    });
  }

  @override
  bool shouldRepaint(covariant _LitFledgeRenderPainter oldDelegate) => true;
}
