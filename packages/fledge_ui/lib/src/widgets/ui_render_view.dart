import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, RRect, Radius, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show App;
import 'package:fledge_render_2d/fledge_render_2d.dart'
    show CanvasSpriteDrawer, RenderWorld, SpriteDrawer;
import 'package:flutter/widgets.dart'
    show
        BuildContext,
        CustomPaint,
        CustomPainter,
        Positioned,
        SizedBox,
        Size,
        Stack,
        StatelessWidget,
        Widget;

import '../extraction/extracted_ui_element.dart';

/// Composes an [App]'s game view with a UI paint pass drawn on top.
///
/// Wrap any Fledge render widget (`FledgeRenderView`,
/// `LitFledgeRenderView`, or a custom one) with this to layer the
/// HUD on top:
///
/// ```dart
/// FledgeUiOverlay(
///   app: app,
///   child: FledgeRenderView(app: app),
/// )
/// ```
///
/// Internally this is a `Stack`: the child is drawn first, then a
/// second `CustomPaint` layer walks the app's [RenderWorld] for
/// [ExtractedUiElement]s and paints them (images through the sprite
/// drawer's atlas path, text and rounded rects directly via
/// `Canvas.drawParagraph` / `Canvas.drawRRect`).
///
/// The widget is stateless and pulls fresh data every paint —
/// callers still drive `App.tick()` themselves and rebuild the
/// widget after each tick.
class FledgeUiOverlay extends StatelessWidget {
  /// The Fledge app whose UI extractions will be painted.
  final App app;

  /// The game render widget drawn underneath the UI pass.
  final Widget child;

  /// Creates a UI overlay.
  const FledgeUiOverlay({super.key, required this.app, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: SizedBox.expand(
            child: CustomPaint(painter: _UiPainter(app: app)),
          ),
        ),
      ],
    );
  }
}

class _UiPainter extends CustomPainter {
  final App app;

  _UiPainter({required this.app});

  @override
  void paint(Canvas canvas, Size size) {
    final renderWorld = app.world.getResource<RenderWorld>();
    if (renderWorld == null) return;

    final drawer = app.world.getResource<SpriteDrawer>();
    final canvasDrawer = drawer is CanvasSpriteDrawer ? drawer : null;

    // Collect + sort so a later-extracted element with a higher sort
    // key always draws on top of an earlier one — mirrors the sprite
    // pipeline's sort semantics.
    final elements = <ExtractedUiElement>[];
    for (final (_, element)
        in renderWorld.query1<ExtractedUiElement>().iter()) {
      elements.add(element);
    }
    if (elements.isEmpty) return;
    elements.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    for (final element in elements) {
      switch (element) {
        case final ExtractedUiImage image:
          _drawImage(canvas, image, canvasDrawer);
        case final ExtractedUiRect r:
          _drawRect(canvas, r);
        case final ExtractedUiText text:
          _drawText(canvas, text);
      }
    }
  }

  void _drawImage(
    Canvas canvas,
    ExtractedUiImage image,
    CanvasSpriteDrawer? drawer,
  ) {
    // Without a canvas-backed drawer we can't resolve the texture
    // handle to a dart:ui.Image. Fall back to a tinted rect so the
    // element is still visible instead of silently missing.
    if (drawer == null) {
      _fillRect(canvas, image.rect, image.tint);
      return;
    }

    final resolved = drawer.resolveImage(image.texture);
    if (resolved == null) {
      _fillRect(canvas, image.rect, image.tint);
      return;
    }

    final srcRect = image.sourceRect ?? image.texture.fullRect;
    final paint = Paint()..color = image.tint;
    canvas.drawImageRect(resolved, srcRect, image.rect, paint);
  }

  void _drawRect(Canvas canvas, ExtractedUiRect r) {
    final paint = Paint()..color = r.color;
    if (r.borderRadius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.rect, Radius.circular(r.borderRadius)),
        paint,
      );
    } else {
      canvas.drawRect(r.rect, paint);
    }
  }

  void _drawText(Canvas canvas, ExtractedUiText text) {
    final style = ui.ParagraphStyle(
      textAlign: text.align,
      fontSize: text.fontSize,
      fontFamily: text.fontFamily,
      fontWeight: text.fontWeight,
    );
    final builder = ui.ParagraphBuilder(style)
      ..pushStyle(
        ui.TextStyle(
          color: text.color,
          fontSize: text.fontSize,
          fontFamily: text.fontFamily,
          fontWeight: text.fontWeight,
        ),
      )
      ..addText(text.text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: text.rect.width));
    canvas.drawParagraph(paragraph, Offset(text.rect.left, text.rect.top));
  }

  void _fillRect(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _UiPainter oldDelegate) => true;
}
