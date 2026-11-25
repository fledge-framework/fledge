import 'dart:ui' as ui;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/rendering.dart'
    show RenderCustomPaint, RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [size]×[size] opaque white image.
ui.Image _whiteImage(int size) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(size, size);
  picture.dispose();
  return image;
}

Widget _overlay(App app, {Listenable? repaint}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: RepaintBoundary(
      child: SizedBox(
        width: 40,
        height: 40,
        child: FledgeUiOverlay(
          app: app,
          repaint: repaint,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a repaint listenable repaints the UI pass without a rebuild', (
    tester,
  ) async {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const UiPlugin());
    final frames = ValueNotifier<int>(0);
    await tester.pumpWidget(_overlay(app, repaint: frames));
    await tester.pump();
    final paint = tester.renderObject<RenderCustomPaint>(
      find.descendant(
        of: find.byType(FledgeUiOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint.debugNeedsPaint, isFalse);
    frames.value++;
    expect(paint.debugNeedsPaint, isTrue, reason: 'a tick asks for a paint');
    await tester.pump();
    expect(paint.debugNeedsPaint, isFalse);
  });

  for (final (label, tint, expected) in [
    ('a coloured tint colours', const Color(0xFFFF0000), (255, 0, 0, 255)),
    ('white leaves the image', const Color(0xFFFFFFFF), (255, 255, 255, 255)),
    ('a translucent tint fades', const Color(0x80FFFFFF), (255, 255, 255, 128)),
  ]) {
    testWidgets('UiImage tint: $label', (tester) async {
      final app = App()
        ..addPlugin(RenderPlugin())
        ..addPlugin(const UiPlugin());
      const handle = TextureHandle(id: 4242, width: 4, height: 4);
      (app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer)
          .registerTexture(handle, _whiteImage(4));
      app.world.spawn()
        ..insert(const UiNode())
        ..insert(const UiSize(width: 40, height: 40))
        ..insert(UiImage(texture: handle, tint: tint));
      await app.tick();

      await tester.pumpWidget(_overlay(app));
      await tester.pump();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        image.dispose();
        return data!;
      });
      // The centre pixel.
      const i = (20 * 40 + 20) * 4;
      final pixel = (
        bytes!.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
        bytes.getUint8(i + 3),
      );
      final (r, g, b, a) = expected;
      expect(pixel.$1, closeTo(r, 2));
      expect(pixel.$2, closeTo(g, 2));
      expect(pixel.$3, closeTo(b, 2));
      expect(pixel.$4, closeTo(a, 2));
    });
  }

  testWidgets('UiPlugin without CameraPlugin still lays out', (tester) async {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const UiPlugin());
    final entity =
        (app.world.spawn()
              ..insert(const UiNode())
              ..insert(const UiAnchorComponent(UiAnchor.bottomRight))
              ..insert(const UiSize(width: 100, height: 20))
              ..insert(const UiRect(color: Color(0xFF00FF00))))
            .entity;
    await app.tick();
    final rect = app.world.get<UiComputedRect>(entity);
    expect(rect, isNotNull);
    expect(rect!.rect.right, 1280);
    expect(rect.rect.bottom, 720);
  });
}
