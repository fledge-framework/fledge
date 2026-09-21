import 'dart:typed_data';
import 'dart:ui';

import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Rasterisation-level regression for Batch 3 item 16: flipX / flipY
/// used to produce a 180° rotation via a negative scale in the
/// RSTransform. The fix sub-batches by flip flags and applies a
/// `canvas.scale(±1, ±1)` around each sub-batch's `drawRawAtlas` call.
///
/// The check pattern: draw a 4×4 image whose left half is red and
/// right half is blue, at various flip states, and confirm the
/// canvas ends up with red / blue in the expected quadrants.
Future<Image> _horizontalGradientImage() async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2, 4),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    const Rect.fromLTWH(2, 0, 2, 4),
    Paint()..color = const Color(0xFF0000FF),
  );
  final picture = recorder.endRecording();
  return picture.toImage(4, 4);
}

int _pixelArgb(ByteData bytes, int x, int y, int width) {
  final offset = (y * width + x) * 4;
  final r = bytes.getUint8(offset);
  final g = bytes.getUint8(offset + 1);
  final b = bytes.getUint8(offset + 2);
  final a = bytes.getUint8(offset + 3);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

Future<Image> _rasterise({
  required Image atlas,
  required TextureHandle handle,
  required int flipFlags,
  required int outputSize,
}) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final drawer = CanvasSpriteDrawer();
  drawer.registerTexture(handle, atlas);
  drawer.beginFrame(canvas);
  drawer.drawSpriteBatch(handle, [
    BackendSpriteData(
      sourceRect: const Rect.fromLTWH(0, 0, 4, 4),
      destRect: Rect.fromCenter(center: Offset.zero, width: 4, height: 4),
      transform: Matrix3.identity()..setValues(1, 0, 0, 0, 1, 0, 2, 2, 1),
      color: const Color(0xFFFFFFFF),
      flipFlags: flipFlags,
    ),
  ]);
  drawer.endFrame();
  final picture = recorder.endRecording();
  return picture.toImage(outputSize, outputSize);
}

bool _isRedish(int argb) {
  final r = (argb >> 16) & 0xff;
  final g = (argb >> 8) & 0xff;
  final b = argb & 0xff;
  return r > 180 && g < 60 && b < 60;
}

bool _isBluish(int argb) {
  final r = (argb >> 16) & 0xff;
  final g = (argb >> 8) & 0xff;
  final b = argb & 0xff;
  return b > 180 && g < 60 && r < 60;
}

void main() {
  const handle = TextureHandle(id: 42, width: 4, height: 4);

  test('no flip: red on the left, blue on the right', () async {
    final atlas = await _horizontalGradientImage();
    final out = await _rasterise(
      atlas: atlas,
      handle: handle,
      flipFlags: 0,
      outputSize: 4,
    );
    final bytes = await out.toByteData();
    expect(
      _isRedish(_pixelArgb(bytes!, 0, 2, 4)),
      isTrue,
      reason: 'left column should be red',
    );
    expect(
      _isBluish(_pixelArgb(bytes, 3, 2, 4)),
      isTrue,
      reason: 'right column should be blue',
    );
  });

  test('flipX: colours swap left/right (regression for Batch 3 #16)', () async {
    final atlas = await _horizontalGradientImage();
    final out = await _rasterise(
      atlas: atlas,
      handle: handle,
      flipFlags: 1, // flipX
      outputSize: 4,
    );
    final bytes = await out.toByteData();
    expect(
      _isBluish(_pixelArgb(bytes!, 0, 2, 4)),
      isTrue,
      reason: 'flipX should put blue on the left',
    );
    expect(
      _isRedish(_pixelArgb(bytes, 3, 2, 4)),
      isTrue,
      reason: 'flipX should put red on the right',
    );
  });

  test('flipY: same-column colours are unchanged (X still ok)', () async {
    // The atlas is uniform along Y, so flipY doesn't change the
    // observable pattern along X. This test asserts the drawer
    // doesn't accidentally *also* mirror X when flipY is set alone —
    // the pre-fix code did.
    final atlas = await _horizontalGradientImage();
    final out = await _rasterise(
      atlas: atlas,
      handle: handle,
      flipFlags: 2, // flipY
      outputSize: 4,
    );
    final bytes = await out.toByteData();
    expect(_isRedish(_pixelArgb(bytes!, 0, 2, 4)), isTrue);
    expect(_isBluish(_pixelArgb(bytes, 3, 2, 4)), isTrue);
  });
}
