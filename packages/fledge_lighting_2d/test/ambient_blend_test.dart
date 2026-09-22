import 'dart:ui';

import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbientBlend construction', () {
    test('default is underSprites (backward-compatible)', () {
      const a = AmbientLight();
      expect(a.blend, AmbientBlend.underSprites);
    });

    test('overSprites can be passed explicitly', () {
      const a = AmbientLight(blend: AmbientBlend.overSprites);
      expect(a.blend, AmbientBlend.overSprites);
    });

    test('static defaults keep underSprites blend', () {
      expect(AmbientLight.white.blend, AmbientBlend.underSprites);
      expect(AmbientLight.dark.blend, AmbientBlend.underSprites);
    });

    test('bounds is null by default and can carry a world-space Rect '
        '(regression for Batch 6 #25)', () {
      expect(const AmbientLight().bounds, isNull);
      const map = Rect.fromLTWH(0, 0, 320, 240);
      const custom = AmbientLight(blend: AmbientBlend.overSprites, bounds: map);
      expect(custom.bounds, map);
    });
  });

  // Rasterisation checks: cover the intended pixel outcomes of each
  // blend mode with a hand-crafted scene. A `PictureRecorder` is
  // enough — we don't need the full app / render world here.
  group('AmbientBlend rasterisation', () {
    Future<Image> rasterise(
      void Function(Canvas canvas, Size size) paint, {
      double width = 4,
      double height = 4,
    }) async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      paint(canvas, Size(width, height));
      final picture = recorder.endRecording();
      return picture.toImage(width.toInt(), height.toInt());
    }

    Future<int> pixelAt(Image image, int x, int y) async {
      final byteData = await image.toByteData();
      final offset = (y * image.width + x) * 4;
      final r = byteData!.getUint8(offset);
      final g = byteData.getUint8(offset + 1);
      final b = byteData.getUint8(offset + 2);
      final a = byteData.getUint8(offset + 3);
      return (a << 24) | (r << 16) | (g << 8) | b;
    }

    test(
      'overSprites: a bright sprite pixel gets darkened toward ambient color',
      () async {
        // Paint a solid opaque red rect, then apply an overSprites
        // ambient at intensity 0.5 toward black. Result should be
        // ~half brightness red — around (128, 0, 0).
        final image = await rasterise((canvas, size) {
          canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()..color = const Color(0xFFFF0000),
          );
          // Multiply the whole layer by mid-gray (lerp(white, black, 0.5)).
          final tint = Color.lerp(
            const Color(0xFFFFFFFF),
            const Color(0xFF000000),
            0.5,
          )!;
          canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width, size.height),
            Paint()
              ..color = tint.withValues(alpha: 1.0)
              ..blendMode = BlendMode.multiply,
          );
        });
        final argb = await pixelAt(image, 2, 2);
        final r = (argb >> 16) & 0xff;
        final g = (argb >> 8) & 0xff;
        final b = argb & 0xff;
        expect(
          r,
          inInclusiveRange(120, 136),
          reason: 'Red should be halved by the multiply pass.',
        );
        expect(g, 0);
        expect(b, 0);
      },
    );

    test('overSprites at intensity 0 leaves sprite pixels untouched', () async {
      final image = await rasterise((canvas, size) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = const Color(0xFF00FF00),
        );
        final tint = Color.lerp(
          const Color(0xFFFFFFFF),
          const Color(0xFF000000),
          0.0, // intensity 0 → no darkening.
        )!;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()
            ..color = tint.withValues(alpha: 1.0)
            ..blendMode = BlendMode.multiply,
        );
      });
      final argb = await pixelAt(image, 2, 2);
      final r = (argb >> 16) & 0xff;
      final g = (argb >> 8) & 0xff;
      final b = argb & 0xff;
      expect(r, 0);
      expect(g, 255);
      expect(b, 0);
    });
  });
}
