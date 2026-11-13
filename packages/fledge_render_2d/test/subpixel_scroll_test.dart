import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paints a white 2x2-unit square at the world origin through the camera
/// into an 8x4 image and returns each pixel's red value along a row
/// through the square (which sits at screen y 2..4).
Future<List<int>> _paintRow(World world, {double dpr = 1}) async {
  const size = Size(8, 4);
  final recorder = PictureRecorder();
  // Like a painter's canvas: logical units, rastered at the pixel ratio.
  final canvas = Canvas(recorder)..scale(dpr);
  paintActiveCameraView(world, canvas, size, (target) {
    target.drawRect(
      const Rect.fromLTWH(0, 0, 2, 2),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }, devicePixelRatio: dpr);
  final image = await recorder.endRecording().toImage(
    (size.width * dpr).round(),
    (size.height * dpr).round(),
  );
  final bytes = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
  final row = (2.5 * dpr).floor();
  final width = image.width;
  return [
    for (var x = 0; x < width; x++) bytes.getUint8((row * width + x) * 4),
  ];
}

void main() {
  group('paintActiveCameraView', () {
    testWidgets(
      'without sub-pixel scrolling it draws straight onto the canvas, '
      'offset rounded for pixel-perfect cameras',
      (tester) async {
        final world = World()
          ..insertResource(ActiveCameraView(x: 0.4, pixelPerfect: true));
        Canvas? drawnOn;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        paintActiveCameraView(world, canvas, const Size(8, 4), (c) {
          drawnOn = c;
        });
        recorder.endRecording();
        expect(identical(drawnOn, canvas), isTrue);
        expect(activeCameraCanvasOffset(world, const Size(8, 4))!.dx, 4);
      },
    );

    testWidgets('on whole pixels the frame is as crisp as without it', (
      tester,
    ) async {
      final world = World()
        ..insertResource(ActiveCameraView(pixelPerfect: true));
      final plain = (await tester.runAsync(() => _paintRow(world)))!;
      world.getResource<ActiveCameraView>()!.subpixelScroll = true;
      final shifted = (await tester.runAsync(() => _paintRow(world)))!;
      expect(shifted, plain);
      // Camera at 0: the square spans pixels 4 and 5.
      expect(plain, [0, 0, 0, 0, 255, 255, 0, 0]);
    });

    testWidgets('half a pixel off, the frame shifts by half a pixel', (
      tester,
    ) async {
      final world = World()
        ..insertResource(
          ActiveCameraView(x: 0.5, pixelPerfect: true, subpixelScroll: true),
        );
      final row = (await tester.runAsync(() => _paintRow(world)))!;
      // Square at screen 3.5..5.5: pixels 3 and 5 half covered, 4 full.
      expect(row[2], 0);
      expect(row[3], inInclusiveRange(100, 155));
      expect(row[4], 255);
      expect(row[5], inInclusiveRange(100, 155));
      expect(row[6], 0);
      // The offset isn't rounded, so other layers line up with it.
      expect(activeCameraCanvasOffset(world, const Size(8, 4))!.dx, 3.5);
    });

    testWidgets('works in physical pixels', (tester) async {
      final world = World()
        ..insertResource(
          ActiveCameraView(x: 0.25, pixelPerfect: true, subpixelScroll: true),
        );
      // At 2x, 0.25 logical pixels is half a physical pixel.
      final row = (await tester.runAsync(() => _paintRow(world, dpr: 2)))!;
      printOnFailure('row $row');
      expect(row.length, 16);
      // The square lands at physical 7.5..11.5.
      expect(row[6], 0);
      expect(row[7], inInclusiveRange(100, 155));
      expect(row.sublist(8, 11), [255, 255, 255]);
      expect(row[11], inInclusiveRange(100, 155));
      expect(row[12], 0);
    });
  });
}
