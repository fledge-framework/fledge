import 'dart:ui' show Color, Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;

/// An image UI node.
///
/// Wraps a [TextureHandle] with UI-space semantics: the image is drawn
/// filling the entity's computed rect, tinted by [tint]. If
/// [sourceRect] is `null`, the full texture is used.
///
/// Rendered through the sprite pipeline at [DrawLayer.ui] so the same
/// backend batching path handles UI images and gameplay sprites.
class UiImage {
  /// The texture to render.
  final TextureHandle texture;

  /// Source rectangle in texture pixels. `null` uses the whole texture.
  final Rect? sourceRect;

  /// Tint colour applied to the sampled texels. White (`0xFFFFFFFF`)
  /// is the identity.
  final Color tint;

  /// Creates a UI image.
  const UiImage({
    required this.texture,
    this.sourceRect,
    this.tint = const Color(0xFFFFFFFF),
  });
}
