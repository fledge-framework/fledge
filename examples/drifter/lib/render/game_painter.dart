import 'package:flutter/material.dart' hide Color;
import 'dart:ui';

import '../extraction.dart';

/// CustomPainter that draws the render-world snapshot for one frame.
///
/// Reads ONLY from `RenderWorld` — the main-world entities are never
/// touched here, so rendering is decoupled from game logic.
class DrifterPainter extends CustomPainter {
  final RenderWorld renderWorld;

  /// Cheap, deterministic hash used to decide whether to repaint. The
  /// painter only redraws when the extracted snapshot actually changes.
  int _lastHash = 0;

  DrifterPainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1A1A2E),
    );

    final paint = Paint()..style = PaintingStyle.fill;

    for (final (_, e) in renderWorld.query1<ExtractedEntity>().iter()) {
      switch (e.kind) {
        case VisualKind.wall:
          paint.color = const Color(0xFF4CAF50);
          canvas.drawRect(e.rect, paint);
        case VisualKind.pickup:
          paint.color = const Color(0xFFFFD700);
          final center = e.rect.center;
          canvas.drawCircle(center, e.rect.width / 2, paint);
          // Shine
          paint.color = const Color(0xFFFFE55C);
          canvas.drawCircle(
            Offset(center.dx - e.rect.width / 6, center.dy - e.rect.width / 6),
            e.rect.width / 8,
            paint,
          );
        case VisualKind.player:
          paint
            ..color = const Color(0xFF00DD00)
            ..style = PaintingStyle.fill;
          final rr = RRect.fromRectAndRadius(e.rect, const Radius.circular(4));
          canvas.drawRRect(rr, paint);
          paint
            ..color = const Color(0xFF00AA00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRRect(rr, paint);
          paint.style = PaintingStyle.fill;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrifterPainter oldDelegate) {
    final h = _computeHash();
    if (h != _lastHash) {
      _lastHash = h;
      return true;
    }
    return false;
  }

  int _computeHash() {
    var h = 0;
    for (final (entity, e) in renderWorld.query1<ExtractedEntity>().iter()) {
      h ^= entity.hashCode;
      h ^= e.rect.left.toInt() << 1;
      h ^= e.rect.top.toInt() << 5;
      h ^= e.kind.index << 9;
    }
    return h;
  }
}
