import 'dart:typed_data';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Camera-aware light rendering regressions from Batch 6 item 23.
///
/// - A directional light must fill the world viewport the camera is
///   showing, not the world rect `(0, 0, size.width, size.height)`
///   under a translated canvas.
/// - A point / spot light at the camera's world position must NOT be
///   culled by the world-viewport reject.
Future<Image> _rasterise(
  void Function(Canvas c) body, {
  int width = 8,
  int height = 8,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  body(canvas);
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

int _pixel(ByteData bytes, int x, int y, int stride) {
  final o = (y * stride + x) * 4;
  return (bytes.getUint8(o + 3) << 24) |
      (bytes.getUint8(o) << 16) |
      (bytes.getUint8(o + 1) << 8) |
      bytes.getUint8(o + 2);
}

void main() {
  test(
    'directional light in a camera-translated canvas fills the world viewport',
    () async {
      final rw = RenderWorld();
      rw.spawn().insert(
        ExtractedLight(
          entity: const Entity(0, 0),
          type: LightType.directional,
          position: Vector2.zero(),
          color: const Color(0xFF00FF00),
          intensity: 1.0,
          radius: 0,
          innerRadius: 0,
          direction: Vector2(0, 0),
          angle: 0,
        ),
      );
      // Camera at (1000, 1000), viewport 8x8. Under the camera wrap
      // the canvas is translated by (4 - 1000, 4 - 1000). Test that
      // the directional light still fills every visible pixel.
      final image = await _rasterise((canvas) {
        canvas.translate(4 - 1000, 4 - 1000);
        renderLightsToCanvas(
          rw,
          canvas,
          const Size(8, 8),
          worldViewport: const Rect.fromLTWH(996, 996, 8, 8),
        );
      });
      final bytes = await image.toByteData();
      // Every pixel should have taken some green from the additive
      // directional pass.
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          final g = (_pixel(bytes!, x, y, 8) >> 8) & 0xff;
          expect(g, greaterThan(0), reason: 'pixel ($x,$y) should be lit');
        }
      }
    },
  );

  test(
    'point light at the camera position is not culled by the world viewport',
    () async {
      final rw = RenderWorld();
      // Point light exactly where the camera is looking. Under the
      // camera wrap it should render at the canvas centre.
      rw.spawn().insert(
        ExtractedLight(
          entity: const Entity(0, 0),
          type: LightType.point,
          position: Vector2(1000, 1000),
          color: const Color(0xFFFFFFFF),
          intensity: 1.0,
          radius: 4,
          innerRadius: 0,
          direction: Vector2(0, 0),
          angle: 0,
        ),
      );
      final image = await _rasterise((canvas) {
        canvas.translate(4 - 1000, 4 - 1000);
        renderLightsToCanvas(
          rw,
          canvas,
          const Size(8, 8),
          worldViewport: const Rect.fromLTWH(996, 996, 8, 8),
        );
      });
      final bytes = await image.toByteData();
      // Centre pixel must be lit (the point light's inner disc). The
      // exact luminance depends on gradient rasterisation but any value
      // well above zero means the light survived culling.
      final centre = _pixel(bytes!, 4, 4, 8);
      expect(centre & 0xff, greaterThan(100));
    },
  );

  test(
    'renderLightsToCanvas without worldViewport keeps the old behaviour',
    () async {
      final rw = RenderWorld();
      rw.spawn().insert(
        ExtractedLight(
          entity: const Entity(0, 0),
          type: LightType.directional,
          position: Vector2.zero(),
          color: const Color(0xFF0000FF),
          intensity: 1.0,
          radius: 0,
          innerRadius: 0,
          direction: Vector2(0, 0),
          angle: 0,
        ),
      );
      // No camera translate, no worldViewport: fill the screen.
      final image = await _rasterise((canvas) {
        renderLightsToCanvas(rw, canvas, const Size(8, 8));
      });
      final bytes = await image.toByteData();
      final b = _pixel(bytes!, 4, 4, 8) & 0xff;
      expect(b, greaterThan(0));
    },
  );
}
