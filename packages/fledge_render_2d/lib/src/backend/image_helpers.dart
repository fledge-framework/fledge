import 'dart:async';
import 'dart:ui'
    show Canvas, Color, Image, Paint, Picture, PictureRecorder, Rect;

/// Create a solid-colour [Image] of size [width] x [height].
///
/// Handy for placeholder textures (e.g. Drifter's 1×1 white pixel that
/// [Sprite.color] tints) while a real asset pipeline is not yet
/// wired. The default 1×1 size is intentional — a single pixel
/// draws to any rect through `Canvas.drawRawAtlas`'s scale factor
/// without wasting VRAM.
///
/// This variant returns a `Future<Image>` because `Picture.toImage`
/// is inherently async on Skia. For synchronous use (e.g. inside
/// `initState` / a builder), see [createSolidColorImageSync].
Future<Image> createSolidColorImage(
  Color color, {
  int width = 1,
  int height = 1,
}) async {
  final picture = _recordSolidColor(color, width, height);
  return picture.toImage(width, height);
}

/// Synchronous variant of [createSolidColorImage].
///
/// Uses `Picture.toImageSync`, available since Flutter 3.7. Prefer
/// this when the image is produced during app construction (before
/// the first frame paints) and the caller cannot easily await.
Image createSolidColorImageSync(
  Color color, {
  int width = 1,
  int height = 1,
}) {
  final picture = _recordSolidColor(color, width, height);
  return picture.toImageSync(width, height);
}

Picture _recordSolidColor(Color color, int width, int height) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording();
}
