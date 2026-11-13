import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart' hide BlendMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Pixel-level checks that flipX / flipY mirror a sprite in its own
/// local space (about its anchor, along its own axes) before the
/// entity transform. The drawer used to mirror in world axes about the
/// entity position, so a rotated sprite flipped along the wrong axis
/// and an off-centre-anchored one jumped across its pivot.
///
/// Texture: 4x4, left half red, right half blue.

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _handle = TextureHandle(id: 9, width: 4, height: 4);

Future<Image> _redBlueImage() {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 2, 4), Paint()..color = _red);
  canvas.drawRect(const Rect.fromLTWH(2, 0, 2, 4), Paint()..color = _blue);
  return recorder.endRecording().toImage(4, 4);
}

class _Raster {
  final ByteData bytes;
  final int width;
  _Raster(this.bytes, this.width);

  int _argb(int x, int y) {
    final o = (y * width + x) * 4;
    return (bytes.getUint8(o + 3) << 24) |
        (bytes.getUint8(o) << 16) |
        (bytes.getUint8(o + 1) << 8) |
        bytes.getUint8(o + 2);
  }

  bool isColor(int x, int y, Color c) {
    final p = _argb(x, y);
    final want = c.toARGB32();
    for (final shift in const [24, 16, 8, 0]) {
      if ((((p >> shift) & 0xff) - ((want >> shift) & 0xff)).abs() > 8) {
        return false;
      }
    }
    return true;
  }

  bool isEmpty(int x, int y) => (_argb(x, y) >> 24) & 0xff == 0;

  /// Bounding box (left, top, right, bottom) of non-empty pixels,
  /// exclusive right/bottom; null if nothing was drawn.
  (int, int, int, int)? bounds() {
    int? l, t, r, b;
    final height = bytes.lengthInBytes ~/ (4 * width);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (isEmpty(x, y)) continue;
        l = l == null ? x : math.min(l, x);
        t = t == null ? y : math.min(t, y);
        r = r == null ? x + 1 : math.max(r, x + 1);
        b = b == null ? y + 1 : math.max(b, y + 1);
      }
    }
    return l == null ? null : (l, t!, r!, b!);
  }
}

Matrix3 _trs({double x = 0, double y = 0, double rotation = 0}) =>
    Transform2D(translation: Vector2(x, y), rotation: rotation).toMatrix();

/// Local quad for a sprite of [w]x[h] with normalised [anchor], exactly
/// as SpriteBatchSystem / renderSpritesToDrawer build it.
Rect _dest(double w, double h, Offset anchor) => Rect.fromCenter(
  center: Offset((0.5 - anchor.dx) * w, (0.5 - anchor.dy) * h),
  width: w,
  height: h,
);

Future<_Raster> _render({
  required double w,
  required double h,
  required Offset anchor,
  required Matrix3 transform,
  required int flipFlags,
}) async {
  final drawer = CanvasSpriteDrawer();
  drawer.registerTexture(_handle, await _redBlueImage());
  final recorder = PictureRecorder();
  drawer.beginFrame(Canvas(recorder));
  drawer.drawSpriteBatch(_handle, [
    BackendSpriteData(
      sourceRect: const Rect.fromLTWH(0, 0, 4, 4),
      destRect: _dest(w, h, anchor),
      transform: transform,
      color: const Color(0xFFFFFFFF),
      flipFlags: flipFlags,
    ),
  ]);
  drawer.endFrame();
  final image = await recorder.endRecording().toImage(100, 100);
  return _Raster((await image.toByteData())!, 100);
}

void main() {
  // Rotated 90 deg clockwise (local +x -> world +y, local +y -> world
  // -x) about the entity at (50, 50), anchored at the top-left corner.
  final rotated = _trs(x: 50, y: 50, rotation: math.pi / 2);
  const corner = Offset(0, 0);

  group('rotated 90 deg, off-centre anchor', () {
    for (final (label, w, h) in [
      // 20x20 on a 4x4 source: similarity map (batched fast path when
      // unflipped).
      ('uniform', 20.0, 20.0),
      // 20x10 on a 4x4 source: non-similarity (affine path).
      ('non-uniform', 20.0, 10.0),
    ]) {
      final wi = w.toInt();
      final hi = h.toInt();
      group(label, () {
        // Unflipped local quad x in [0, w], y in [0, h] maps to world
        // x in [50 - h, 50], y in [50, 50 + w]: red (local x < w/2)
        // at the top, blue at the bottom.
        test('unflipped footprint', () async {
          final r = await _render(
            w: w,
            h: h,
            anchor: corner,
            transform: rotated,
            flipFlags: 0,
          );
          expect(r.bounds(), (50 - hi, 50, 50, 50 + wi));
          expect(r.isColor(47, 52, _red), isTrue);
          expect(r.isColor(47, 68, _blue), isTrue);
        });

        test('flipX mirrors along the local x axis about the anchor', () async {
          final r = await _render(
            w: w,
            h: h,
            anchor: corner,
            transform: rotated,
            flipFlags: 1,
          );
          // Local x in [-w, 0] -> world y in [50 - w, 50]; world x
          // unchanged. Red stays next to the anchor, blue goes outward.
          expect(r.bounds(), (50 - hi, 50 - wi, 50, 50));
          expect(r.isColor(47, 48, _red), isTrue);
          expect(r.isColor(47, 32, _blue), isTrue);
          // A world-axis mirror about (50, 50) would have left the
          // sprite below the anchor.
          expect(r.isEmpty(47, 60), isTrue);
        });

        test('flipY mirrors along the local y axis about the anchor', () async {
          final r = await _render(
            w: w,
            h: h,
            anchor: corner,
            transform: rotated,
            flipFlags: 2,
          );
          // Local y in [-h, 0] -> world x in [50, 50 + h]; world y
          // unchanged, so are the colours along it.
          expect(r.bounds(), (50, 50, 50 + hi, 50 + wi));
          expect(r.isColor(53, 52, _red), isTrue);
          expect(r.isColor(53, 68, _blue), isTrue);
          expect(r.isEmpty(47, 60), isTrue);
        });

        test('flipX + flipY is a 180 deg turn about the anchor', () async {
          final r = await _render(
            w: w,
            h: h,
            anchor: corner,
            transform: rotated,
            flipFlags: 3,
          );
          expect(r.bounds(), (50, 50 - wi, 50 + hi, 50));
          expect(r.isColor(53, 48, _red), isTrue);
          expect(r.isColor(53, 32, _blue), isTrue);
        });
      });
    }
  });

  group('unrotated sprites (unchanged behaviour)', () {
    test('centred sprite: flipX is a pure in-place mirror', () async {
      final t = _trs(x: 50, y: 50);
      const centre = Offset(0.5, 0.5);
      final plain = await _render(
        w: 20,
        h: 20,
        anchor: centre,
        transform: t,
        flipFlags: 0,
      );
      final flipped = await _render(
        w: 20,
        h: 20,
        anchor: centre,
        transform: t,
        flipFlags: 1,
      );
      expect(plain.bounds(), (40, 40, 60, 60));
      expect(flipped.bounds(), (40, 40, 60, 60));
      expect(plain.isColor(42, 50, _red), isTrue);
      expect(plain.isColor(58, 50, _blue), isTrue);
      expect(flipped.isColor(42, 50, _blue), isTrue);
      expect(flipped.isColor(58, 50, _red), isTrue);
    });

    test('left-anchored sprite: flipX mirrors about the anchor', () async {
      // Same as the old world-axis mirror about the entity position:
      // with no rotation the two coincide.
      final r = await _render(
        w: 20,
        h: 10,
        anchor: const Offset(0, 0.5),
        transform: _trs(x: 50, y: 50),
        flipFlags: 1,
      );
      expect(r.bounds(), (30, 45, 50, 55));
      expect(r.isColor(48, 50, _red), isTrue);
      expect(r.isColor(32, 50, _blue), isTrue);
    });
  });

  test('Sprite.flipX on a rotated entity end to end', () async {
    final world = World();
    final renderWorld = RenderWorld();
    world.spawn()
      ..insert(
        Sprite(
          texture: _handle,
          customSize: Vector2(20, 10),
          anchor: Vector2(0, 0),
          flipX: true,
        ),
      )
      ..insert(GlobalTransform2D(rotated));
    SpriteExtractor().extract(world, renderWorld);

    final drawer = CanvasSpriteDrawer();
    drawer.registerTexture(_handle, await _redBlueImage());
    final recorder = PictureRecorder();
    drawer.beginFrame(Canvas(recorder));
    renderSpritesToDrawer(renderWorld, drawer);
    drawer.endFrame();
    final image = await recorder.endRecording().toImage(100, 100);
    final r = _Raster((await image.toByteData())!, 100);
    expect(r.bounds(), (40, 30, 50, 50));
    expect(r.isColor(47, 48, _red), isTrue);
    expect(r.isColor(47, 32, _blue), isTrue);
  });
}
