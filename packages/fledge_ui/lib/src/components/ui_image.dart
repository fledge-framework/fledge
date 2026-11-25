import 'dart:ui' show Color, Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart' show TextureHandle;

/// An image UI node.
///
/// Wraps a [TextureHandle] with UI-space semantics: the image is drawn
/// filling the entity's computed rect, tinted by [tint]. If
/// [sourceRect] is `null`, the full texture is used.
///
/// Drawn by `FledgeUiOverlay` with `Canvas.drawImageRect`, the texture
/// resolved through the app's `CanvasSpriteDrawer`. If the texture can't
/// be resolved, the rect is filled with [tint] instead so the element
/// stays visible.
class UiImage {
  /// The texture to render.
  final TextureHandle texture;

  /// Source rectangle in texture pixels. `null` uses the whole texture.
  final Rect? sourceRect;

  /// Tint colour multiplied into the sampled texels, alpha included.
  /// White (`0xFFFFFFFF`) is the identity; a translucent white only fades
  /// the image.
  final Color tint;

  /// Creates a UI image.
  const UiImage({
    required this.texture,
    this.sourceRect,
    this.tint = const Color(0xFFFFFFFF),
  });
}
