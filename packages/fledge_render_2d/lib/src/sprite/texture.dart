import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Image, instantiateImageCodec;

import 'package:fledge_assets/fledge_assets.dart';

/// A loaded 2D texture: a `dart:ui.Image` plus its pixel dimensions.
///
/// This is the concrete asset type stored in `Assets<Texture>`. Sprites
/// still address the atlas through a `TextureHandle` (integer id +
/// dims); the drawer resolves that handle against the [Assets<Texture>]
/// resource to pull the underlying `Image` at draw time.
class Texture {
  /// The decoded image bytes, ready for `Canvas.drawRawAtlas`.
  final ui.Image image;

  /// Width in pixels. Kept as an eagerly-decoded field so callers can
  /// build sprite source rects without a nested `image.width` read.
  final int width;

  /// Height in pixels.
  final int height;

  /// Creates a texture from a decoded image and its dimensions.
  const Texture(this.image, this.width, this.height);

  /// Build a [Texture] from a decoded [image], reading its dimensions
  /// off the image itself.
  Texture.fromImage(ui.Image image)
    : image = image,
      width = image.width,
      height = image.height;
}

/// A [Loader] that reads a texture from a filesystem path.
///
/// Uses `dart:io` + `dart:ui` to decode PNG/JPEG bytes into a
/// `dart:ui.Image`. Lives in `fledge_render_2d` so the pure-Dart
/// `fledge_assets` core does not have to depend on Flutter.
///
/// Not usable on web builds — `dart:io.File` isn't available there. On
/// Flutter web games, load textures through the `rootBundle` and call
/// `Assets<Texture>.add` yourself.
///
/// Named `FileTextureLoader` (not `TextureLoader`) to avoid colliding
/// with `fledge_tiled`'s existing `TextureLoader` typedef, which
/// covers a very different signature.
class FileTextureLoader implements Loader<Texture> {
  const FileTextureLoader();

  @override
  Future<Texture> load(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeTextureBytes(bytes);
  }
}

/// Decode raw PNG/JPEG bytes into a [Texture].
///
/// Exposed as a top-level helper so callers with bytes already in
/// memory (e.g. from `rootBundle.load`) can build a texture without
/// going through a file path.
Future<Texture> decodeTextureBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  // Release the codec's held frames — we only need the decoded image.
  codec.dispose();
  return Texture(image, image.width, image.height);
}
