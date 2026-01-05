// ignore_for_file: avoid_print, deprecated_member_use_from_same_package

// DEPRECATED: This package has been merged into fledge_render.
// Use package:fledge_render/fledge_render.dart instead.

import 'package:fledge_render/fledge_render.dart';
import 'package:flutter/material.dart';

// Example showing migration to fledge_render

/// A simple render layer that paints a colored rectangle.
class ExampleLayer extends RenderLayer {
  final Color color;

  ExampleLayer({required this.color});

  @override
  void paint(Canvas canvas, Size size, RenderWorld renderWorld) {
    final paint = Paint()..color = color;
    canvas.drawRect(const Rect.fromLTWH(10, 10, 100, 100), paint);
  }
}

void main() {
  print('fledge_render_flutter is deprecated.');
  print('Use package:fledge_render/fledge_render.dart instead.');
  print('');
  print('RenderLayer and related classes are now in fledge_render:');
  print('- RenderLayer');
  print('- CompositeRenderLayer');
  print('- ClippedRenderLayer');
  print('- TransformedRenderLayer');
  print('- ConditionalRenderLayer');
}
