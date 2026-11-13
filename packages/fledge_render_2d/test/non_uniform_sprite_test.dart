import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' hide BlendMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Pixel-level checks for non-uniform sprite scale in
/// [CanvasSpriteDrawer]. `drawRawAtlas` RSTransforms only express
/// rotation + uniform scale, so a 1x1 texture stretched to 4x40 used
/// to render as a 4x4 square (scale read from the width only).

const _white = Color(0xFFFFFFFF);
const _red = Color(0xFFFF0000);
const _green = Color(0xFF00FF00);
const _blue = Color(0xFF0000FF);
const _handle = TextureHandle(id: 7, width: 1, height: 1);

Matrix3 _trs({
  double x = 0,
  double y = 0,
  double rotation = 0,
  double sx = 1,
  double sy = 1,
}) => Transform2D(
  translation: Vector2(x, y),
  rotation: rotation,
  scale: Vector2(sx, sy),
).toMatrix();

BackendSpriteData _sprite({
  required double w,
  required double h,
  required Matrix3 transform,
  Color color = _white,
  int flipFlags = 0,
}) => BackendSpriteData(
  sourceRect: const Rect.fromLTWH(0, 0, 1, 1),
  destRect: Rect.fromCenter(center: Offset.zero, width: w, height: h),
  transform: transform,
  color: color,
  flipFlags: flipFlags,
);

class _Raster {
  final ByteData bytes;
  final int width;
  _Raster(this.bytes, this.width);

  int argb(int x, int y) {
    final o = (y * width + x) * 4;
    return (bytes.getUint8(o + 3) << 24) |
        (bytes.getUint8(o) << 16) |
        (bytes.getUint8(o + 1) << 8) |
        bytes.getUint8(o + 2);
  }

  bool isColor(int x, int y, Color c) {
    final p = argb(x, y);
    final want = c.toARGB32();
    for (final shift in const [24, 16, 8, 0]) {
      if ((((p >> shift) & 0xff) - ((want >> shift) & 0xff)).abs() > 8) {
        return false;
      }
    }
    return true;
  }

  bool isEmpty(int x, int y) => (argb(x, y) >> 24) & 0xff == 0;
}

Future<Image> _whitePixel() {
  final recorder = PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = _white);
  return recorder.endRecording().toImage(1, 1);
}

Future<_Raster> _render(
  List<BackendSpriteData> batch, {
  int width = 100,
  int height = 100,
}) async {
  final drawer = CanvasSpriteDrawer();
  drawer.registerTexture(_handle, await _whitePixel());
  final recorder = PictureRecorder();
  drawer.beginFrame(Canvas(recorder));
  drawer.drawSpriteBatch(_handle, batch);
  drawer.endFrame();
  final image = await recorder.endRecording().toImage(width, height);
  return _Raster((await image.toByteData())!, width);
}

/// Counts drawRawAtlas calls without rasterising.
class _CountingCanvas implements Canvas {
  int atlasCalls = 0;

  @override
  void drawRawAtlas(
    Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    atlasCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('isSimilaritySpriteMap', () {
    const src = Rect.fromLTWH(0, 0, 16, 16);
    const square = Rect.fromLTWH(-8, -8, 16, 16);

    test('uniform scale + rotation is a similarity', () {
      expect(
        isSimilaritySpriteMap(
          transform: _trs(x: 5, rotation: 0.7, sx: 3, sy: 3),
          sourceRect: src,
          destRect: const Rect.fromLTWH(-16, -16, 32, 32),
        ),
        isTrue,
      );
    });

    test('non-square customSize on a square source is not', () {
      expect(
        isSimilaritySpriteMap(
          transform: _trs(),
          sourceRect: src,
          destRect: const Rect.fromLTWH(-2, -20, 4, 40),
        ),
        isFalse,
      );
    });

    test('Transform2D scale x != y is not', () {
      expect(
        isSimilaritySpriteMap(
          transform: _trs(sx: 1, sy: 2),
          sourceRect: src,
          destRect: square,
        ),
        isFalse,
      );
    });

    test('non-uniform customSize cancelled by inverse scale is', () {
      // 4x40 dest on a 1x1 source, scaled (10, 1) gives 40x40 world.
      expect(
        isSimilaritySpriteMap(
          transform: _trs(sx: 10, sy: 1),
          sourceRect: const Rect.fromLTWH(0, 0, 1, 1),
          destRect: const Rect.fromLTWH(-2, -20, 4, 40),
        ),
        isTrue,
      );
    });

    test('mirroring scale is not', () {
      expect(
        isSimilaritySpriteMap(
          transform: _trs(sx: -1, sy: 1),
          sourceRect: src,
          destRect: square,
        ),
        isFalse,
      );
    });
  });

  group('CanvasSpriteDrawer non-uniform scale', () {
    test('1x1 texture stretched to 4x40 covers a 4x40 rect', () async {
      // Centre (10, 50): rect x 8..12, y 30..70.
      final r = await _render([
        _sprite(w: 4, h: 40, transform: _trs(x: 10, y: 50)),
      ]);
      for (final (x, y) in const [(8, 30), (11, 30), (8, 69), (11, 69)]) {
        expect(r.isColor(x, y, _white), isTrue, reason: 'inside $x,$y');
      }
      expect(r.isColor(10, 50, _white), isTrue);
      for (final (x, y) in const [(7, 50), (12, 50), (10, 29), (10, 70)]) {
        expect(r.isEmpty(x, y), isTrue, reason: 'outside $x,$y');
      }
    });

    test('Transform2D scale (4, 40) on a 1x1 sprite covers 4x40', () async {
      final r = await _render([
        _sprite(w: 1, h: 1, transform: _trs(x: 10, y: 50, sx: 4, sy: 40)),
      ]);
      expect(r.isColor(8, 31, _white), isTrue);
      expect(r.isColor(11, 68, _white), isTrue);
      expect(r.isEmpty(13, 50), isTrue);
      expect(r.isEmpty(10, 72), isTrue);
    });

    test('rotated non-uniform sprite (90 deg) lies horizontally', () async {
      // 4x40 strip rotated a quarter turn about (50, 50): x 30..70,
      // y 48..52.
      final r = await _render([
        _sprite(
          w: 4,
          h: 40,
          transform: _trs(x: 50, y: 50, rotation: math.pi / 2),
        ),
      ]);
      expect(r.isColor(31, 49, _white), isTrue);
      expect(r.isColor(68, 50, _white), isTrue);
      expect(r.isEmpty(50, 45), isTrue);
      expect(r.isEmpty(50, 33), isTrue, reason: 'not a vertical strip');
      expect(r.isEmpty(28, 50), isTrue);
      expect(r.isEmpty(72, 50), isTrue);
    });

    test('rotated non-uniform sprite (45 deg) follows the diagonal', () async {
      // 4x40 strip rotated 45 deg clockwise (y down) about (50, 50):
      // its long axis runs from top-right to bottom-left.
      final r = await _render([
        _sprite(
          w: 4,
          h: 40,
          transform: _trs(x: 50, y: 50, rotation: math.pi / 4),
        ),
      ]);
      expect(r.isColor(50, 50, _white), isTrue);
      expect(r.isColor(37, 63, _white), isTrue);
      expect(r.isColor(63, 37, _white), isTrue);
      expect(r.isEmpty(37, 37), isTrue);
      expect(r.isEmpty(63, 63), isTrue);
    });

    test(
      'interleaved uniform and non-uniform sprites keep draw order',
      () async {
        // red square (uniform), green strip (non-uniform), blue square
        // (uniform), green bar (non-uniform); all the same texture.
        final r = await _render([
          _sprite(w: 40, h: 40, transform: _trs(x: 50, y: 50), color: _red),
          _sprite(w: 10, h: 60, transform: _trs(x: 50, y: 50), color: _green),
          _sprite(w: 6, h: 6, transform: _trs(x: 50, y: 50), color: _blue),
          _sprite(w: 60, h: 2, transform: _trs(x: 50, y: 70), color: _green),
        ]);
        expect(r.isColor(50, 50, _blue), isTrue, reason: 'blue drawn last');
        expect(r.isColor(50, 40, _green), isTrue, reason: 'strip over red');
        expect(r.isColor(35, 50, _red), isTrue, reason: 'red outside strip');
        expect(r.isColor(50, 25, _green), isTrue, reason: 'strip beyond red');
        expect(r.isColor(35, 70, _green), isTrue, reason: 'last bar on top');
      },
    );

    test('flipped sprite earlier in the batch stays underneath', () async {
      // Before the fix the drawer bucketed by flip flags, painting
      // every unflipped sprite before every flipped one.
      final r = await _render([
        _sprite(
          w: 20,
          h: 20,
          transform: _trs(x: 50, y: 50),
          color: _red,
          flipFlags: 1,
        ),
        _sprite(w: 10, h: 10, transform: _trs(x: 50, y: 50), color: _blue),
      ]);
      expect(r.isColor(50, 50, _blue), isTrue);
      expect(r.isColor(42, 50, _red), isTrue);
    });

    test('uniform batch is still a single drawRawAtlas call', () async {
      final drawer = CanvasSpriteDrawer();
      drawer.registerTexture(_handle, await _whitePixel());
      final canvas = _CountingCanvas();
      drawer.beginFrame(canvas);
      drawer.drawSpriteBatch(_handle, [
        for (var i = 0; i < 5; i++)
          _sprite(
            w: 8,
            h: 8,
            transform: _trs(x: i * 10.0, rotation: i * 0.3),
          ),
      ]);
      expect(canvas.atlasCalls, 1);

      canvas.atlasCalls = 0;
      drawer.drawSpriteBatch(_handle, [
        _sprite(w: 8, h: 8, transform: _trs()),
        _sprite(w: 8, h: 8, transform: _trs(x: 10)),
        _sprite(w: 4, h: 40, transform: _trs(x: 20)),
        _sprite(w: 8, h: 8, transform: _trs(x: 30)),
        _sprite(w: 8, h: 8, transform: _trs(x: 40)),
      ]);
      // run [0, 1], the strip, run [3, 4].
      expect(canvas.atlasCalls, 3);
      drawer.endFrame();
    });

    test(
      'Sprite.customSize end to end through renderSpritesToDrawer',
      () async {
        final world = World();
        final renderWorld = RenderWorld();
        world.spawn()
          ..insert(GlobalTransform2D(_trs(x: 10, y: 50)))
          ..insert(Sprite(texture: _handle, customSize: Vector2(4, 40)));
        SpriteExtractor().extract(world, renderWorld);

        final drawer = CanvasSpriteDrawer();
        drawer.registerTexture(_handle, await _whitePixel());
        final recorder = PictureRecorder();
        drawer.beginFrame(Canvas(recorder));
        renderSpritesToDrawer(renderWorld, drawer);
        drawer.endFrame();
        final image = await recorder.endRecording().toImage(100, 100);
        final r = _Raster((await image.toByteData())!, 100);
        expect(r.isColor(8, 31, _white), isTrue);
        expect(r.isColor(11, 68, _white), isTrue);
        expect(r.isEmpty(10, 72), isTrue);
        expect(r.isEmpty(13, 50), isTrue);
      },
    );
  });
}
