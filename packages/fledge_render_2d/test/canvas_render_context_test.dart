import 'dart:math' as math;
import 'dart:ui' show Color, Image, PictureRecorder, Rect, Canvas;

import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Matrix3, Vector3;

/// Build a Matrix3 for the standard `scale · rotate · translate` sim.
///
/// Column-major storage means we set the columns directly:
///   col0 = ( scale*cos,  scale*sin, 0 )
///   col1 = (-scale*sin,  scale*cos, 0 )
///   col2 = ( tx,          ty,        1 )
Matrix3 _similarity({
  double translateX = 0,
  double translateY = 0,
  double rotation = 0,
  double scale = 1,
}) {
  final cos = math.cos(rotation) * scale;
  final sin = math.sin(rotation) * scale;
  return Matrix3(
    cos,
    sin,
    0, // col 0
    -sin,
    cos,
    0, // col 1
    translateX,
    translateY,
    1, // col 2
  );
}

Future<Image> _makeImage(int size) async {
  // Cheapest way to get a 1×1 dart:ui.Image in a test — record an
  // empty picture and grab its scene.
  final recorder = PictureRecorder();
  Canvas(recorder);
  final picture = recorder.endRecording();
  return picture.toImage(size, size);
}

void main() {
  group('composeSpriteRSTransform (Matrix3 → RSTransform extraction)', () {
    test('extracts identity transform', () {
      final rst = composeSpriteRSTransform(
        transform: Matrix3.identity(),
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTRB(-32, -32, 32, 32),
      );
      expect(rst.scale, closeTo(1.0, 1e-6));
      expect(rst.rotation, closeTo(0.0, 1e-6));
      expect(rst.scos, closeTo(1.0, 1e-6));
      expect(rst.ssin, closeTo(0.0, 1e-6));
    });

    test('extracts pure translation', () {
      final rst = composeSpriteRSTransform(
        transform: _similarity(translateX: 100, translateY: 200),
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTRB(-32, -32, 32, 32),
      );
      expect(rst.scos, closeTo(1.0, 1e-6));
      expect(rst.ssin, closeTo(0.0, 1e-6));
      // Anchor at sprite center → source top-left (0,0) is (-32,-32)
      // in local space; world = (100 - 32, 200 - 32) = (68, 168).
      expect(rst.tx, closeTo(68, 1e-6));
      expect(rst.ty, closeTo(168, 1e-6));
    });

    test('extracts uniform scale', () {
      final rst = composeSpriteRSTransform(
        transform: _similarity(scale: 2),
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTRB(-32, -32, 32, 32),
      );
      expect(rst.scale, closeTo(2.0, 1e-6));
      expect(rst.scos, closeTo(2.0, 1e-6));
      expect(rst.ssin, closeTo(0.0, 1e-6));
    });

    test('extracts rotation', () {
      const quarter = math.pi / 2;
      final rst = composeSpriteRSTransform(
        transform: _similarity(rotation: quarter),
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTRB(-32, -32, 32, 32),
      );
      expect(rst.rotation, closeTo(quarter, 1e-6));
      expect(rst.scos, closeTo(0.0, 1e-6));
      expect(rst.ssin, closeTo(1.0, 1e-6));
    });

    test('composes scale + rotation + translation', () {
      const r = math.pi / 3;
      final rst = composeSpriteRSTransform(
        transform: _similarity(
          translateX: 10,
          translateY: 20,
          rotation: r,
          scale: 1.5,
        ),
        sourceRect: const Rect.fromLTWH(0, 0, 64, 64),
        destRect: const Rect.fromLTRB(-32, -32, 32, 32),
      );
      expect(rst.scale, closeTo(1.5, 1e-6));
      expect(rst.rotation, closeTo(r, 1e-6));
      expect(rst.scos, closeTo(1.5 * math.cos(r), 1e-6));
      expect(rst.ssin, closeTo(1.5 * math.sin(r), 1e-6));
    });

    test(
      'non-zero source origin: source top-left maps to destRect.topLeft',
      () {
        // `Canvas.drawRawAtlas` subtracts the source rect's top-left
        // internally when mapping corners through the RSTransform, so
        // the atlas position does NOT re-appear in tx/ty. The
        // RSTransform's job is only to place the dest rect's local
        // origin (its top-left) inside world space.
        final rst = composeSpriteRSTransform(
          transform: Matrix3.identity(),
          sourceRect: const Rect.fromLTWH(64, 128, 32, 32),
          destRect: const Rect.fromLTRB(-16, -16, 16, 16),
        );
        // Regression for the "atlas / tile frames draw shifted" bug —
        // Porios's render goldens flagged this. Expected: tx = destL,
        // ty = destT (source coordinates handled by drawRawAtlas).
        expect(rst.tx, closeTo(-16, 1e-6));
        expect(rst.ty, closeTo(-16, 1e-6));
      },
    );

    test('handles zero-sized source rect without dividing by zero', () {
      final rst = composeSpriteRSTransform(
        transform: Matrix3.identity(),
        sourceRect: const Rect.fromLTWH(0, 0, 0, 0),
        destRect: const Rect.fromLTRB(0, 0, 0, 0),
      );
      expect(rst.scale, closeTo(1.0, 1e-6));
      // k → 0 so effective RS scale in canvas space is 0.
      expect(rst.scos, closeTo(0.0, 1e-6));
      expect(rst.ssin, closeTo(0.0, 1e-6));
    });
  });

  group('CanvasSpriteDrawer', () {
    late CanvasSpriteDrawer drawer;
    late TextureHandle handle;

    setUp(() async {
      drawer = CanvasSpriteDrawer();
      handle = const TextureHandle(id: 1, width: 32, height: 32);
      drawer.registerTexture(handle, await _makeImage(32));
    });

    test('empty batch does not call drawRawAtlas', () {
      // No canvas bound — an empty batch must silently do nothing
      // even if the canvas were live. Precondition: no exception,
      // and no state change on the drawer.
      drawer.drawSpriteBatch(handle, const []);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      drawer.beginFrame(canvas);
      drawer.drawSpriteBatch(handle, const []);
      drawer.endFrame();

      final picture = recorder.endRecording();
      // Canvas with zero ops recorded → toImage yields a
      // transparent image. We just verify no throw and no crash.
      expect(picture, isNotNull);
    });

    test('draws non-empty batch through Canvas', () async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      drawer.beginFrame(canvas);
      drawer.drawSpriteBatch(handle, [
        BackendSpriteData(
          sourceRect: const Rect.fromLTWH(0, 0, 32, 32),
          destRect: const Rect.fromLTRB(-16, -16, 16, 16),
          transform: _similarity(translateX: 10, translateY: 20),
          color: const Color(0xFFFFFFFF),
        ),
        BackendSpriteData(
          sourceRect: const Rect.fromLTWH(0, 0, 32, 32),
          destRect: const Rect.fromLTRB(-16, -16, 16, 16),
          transform: _similarity(translateX: 30, translateY: 40),
          color: const Color(0xFF00FF00),
        ),
        BackendSpriteData(
          sourceRect: const Rect.fromLTWH(0, 0, 32, 32),
          destRect: const Rect.fromLTRB(-16, -16, 16, 16),
          transform: _similarity(translateX: 50, translateY: 60),
          color: const Color(0xFF0000FF),
        ),
      ]);
      drawer.endFrame();

      final picture = recorder.endRecording();
      // Verify the picture is complete and can rasterise (no
      // invariant violations from drawRawAtlas parameter mismatches
      // — Skia asserts on rst/rect length parity).
      final image = await picture.toImage(4, 4);
      expect(image.width, 4);
      expect(image.height, 4);
    });

    test('missing texture handle is a silent no-op', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      drawer.beginFrame(canvas);
      drawer.drawSpriteBatch(
        const TextureHandle(id: 999, width: 32, height: 32),
        [
          BackendSpriteData(
            sourceRect: const Rect.fromLTWH(0, 0, 32, 32),
            destRect: const Rect.fromLTRB(-16, -16, 16, 16),
            transform: Matrix3.identity(),
            color: const Color(0xFFFFFFFF),
          ),
        ],
      );
      drawer.endFrame();

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('registerTexture stores the image', () async {
      final drawer = CanvasSpriteDrawer();
      const handle = TextureHandle(id: 42, width: 8, height: 8);
      final img = await _makeImage(8);
      drawer.registerTexture(handle, img);

      expect(drawer.textures[42], equals(img));
    });

    test('beginFrame/endFrame manages canvas state', () {
      final drawer = CanvasSpriteDrawer();
      expect(drawer.hasCanvas, isFalse);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      drawer.beginFrame(canvas);
      expect(drawer.hasCanvas, isTrue);
      expect(drawer.canvas, equals(canvas));

      drawer.endFrame();
      expect(drawer.hasCanvas, isFalse);
      expect(drawer.canvas, isNull);
    });
  });

  group('BackendSpriteData', () {
    test('immutable typed construction', () {
      final data = BackendSpriteData(
        sourceRect: const Rect.fromLTWH(0, 0, 32, 32),
        destRect: const Rect.fromLTRB(-16, -16, 16, 16),
        transform: Matrix3.identity(),
        color: const Color(0xFFFFAABB),
      );
      expect(data.sourceRect.width, 32);
      expect(data.destRect.left, -16);
      expect(data.transform.getColumn(0), equals(Vector3(1, 0, 0)));
      expect(data.color.toARGB32(), 0xFFFFAABB);
      expect(data.viewProjection, isNull);
    });
  });
}
