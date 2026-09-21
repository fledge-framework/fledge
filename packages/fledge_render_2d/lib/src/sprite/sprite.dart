import 'dart:ui' show Color, Rect;

import 'package:vector_math/vector_math.dart';

import '../render/extract/draw_layer.dart';

/// Legacy handle to a texture resource.
///
/// Wraps a texture reference that can be used across the render
/// pipeline. The actual texture data is now managed by
/// `Assets<Texture>` (see `fledge_assets`); this value type is kept
/// so existing sprite APIs (`Sprite.texture`, `Sprite.region`,
/// `ExtractedSprite.texture`, ...) continue to compile.
///
/// **Deprecated in Phase 5.** New code should mint a
/// `Handle<Texture>` via `Assets<Texture>.add` / `Assets<Texture>.load`
/// and pass its `id.id` through this wrapper (see
/// [TextureHandle.fromAsset]). A future release will replace
/// [Sprite.texture] with `Handle<Texture>` outright and remove this
/// class.
///
/// The `@Deprecated` annotation is deliberately elided because
/// `TextureHandle` is still the value type on `Sprite.texture` and
/// `ExtractedSprite.texture`; adding it here would generate hundreds
/// of `deprecated_member_use` warnings across `fledge_tiled` and
/// `fledge_render_2d` itself, drowning out real issues. The
/// annotation lands with the follow-up phase that flips those APIs
/// over to `Handle<Texture>`.
class TextureHandle {
  /// Unique identifier for this texture.
  final int id;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Creates a texture handle.
  const TextureHandle({
    required this.id,
    required this.width,
    required this.height,
  });

  /// Convenience constructor that lifts an `Assets<Texture>` handle
  /// into the legacy `TextureHandle` shape. Uses the handle's id and
  /// the resolved texture's dimensions (must be ready).
  factory TextureHandle.fromAsset(Object handle, int width, int height) {
    // `Object` typed to keep this file free of a hard dependency on
    // fledge_assets in the class signature — the docs above name the
    // intended type. Callers with a `Handle<Texture>` write:
    //   TextureHandle.fromAsset(h, tex.width, tex.height)
    // ignore: avoid_dynamic_calls
    final id = (handle as dynamic).id.id as int;
    return TextureHandle(id: id, width: width, height: height);
  }

  /// The full texture rectangle.
  Rect get fullRect => Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextureHandle && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TextureHandle($id, ${width}x$height)';
}

/// Sprite component for textured quad rendering.
///
/// A sprite renders a rectangular portion of a texture at the entity's
/// position. Use with [Transform2D] to control position, rotation, and scale.
///
/// ## Layer ordering
///
/// Sprites participate in the [DrawLayer] sort scheme via the [layer] field
/// (default [DrawLayer.characters]). Within a layer, sprites are sub-sorted by
/// Y position (top-down painter's algorithm) unless [layerSubOrder] is set
/// explicitly, in which case that value is used instead.
///
/// Example:
/// ```dart
/// // Default: characters layer, Y-sorted
/// world.spawn()
///   ..insert(Sprite(texture: playerTexture))
///   ..insert(Transform2D.from(100, 200));
///
/// // HUD element pinned to the UI layer, always drawn on top
/// world.spawn()
///   ..insert(Sprite(texture: hudTexture, layer: DrawLayer.ui))
///   ..insert(Transform2D.from(20, 20));
///
/// // Explicit sub-order overrides Y-sort within the layer
/// world.spawn()
///   ..insert(Sprite(
///     texture: fxTexture,
///     layer: DrawLayer.particles,
///     layerSubOrder: 500,
///   ));
/// ```
class Sprite {
  /// The texture to render.
  TextureHandle texture;

  /// Source rectangle in texture pixels.
  ///
  /// If null, uses the full texture.
  Rect? sourceRect;

  /// Tint color applied to the sprite.
  ///
  /// White (0xFFFFFFFF) means no tint.
  Color color;

  /// Flip the sprite horizontally.
  bool flipX;

  /// Flip the sprite vertically.
  bool flipY;

  /// Anchor point for rotation and positioning.
  ///
  /// (0, 0) = top-left, (0.5, 0.5) = center, (1, 1) = bottom-right.
  Vector2 anchor;

  /// Custom size override.
  ///
  /// If null, uses the source rect or texture size.
  Vector2? customSize;

  /// Draw layer for sort ordering.
  ///
  /// Places this sprite in a specific [DrawLayer] bucket (background, ground,
  /// characters, foreground, particles, ui). Defaults to
  /// [DrawLayer.characters], which matches typical game-object usage.
  DrawLayer layer;

  /// Explicit sub-order within [layer].
  ///
  /// When non-zero, overrides the default Y-based sub-order used by
  /// `SpriteExtractor` to produce the final sort key. Must be within
  /// `0..DrawLayerExtension.layerMultiplier - 1` (0..99,999) to stay inside
  /// the layer's range.
  int layerSubOrder;

  /// Creates a sprite component.
  Sprite({
    required this.texture,
    this.sourceRect,
    this.color = const Color(0xFFFFFFFF),
    this.flipX = false,
    this.flipY = false,
    Vector2? anchor,
    this.customSize,
    this.layer = DrawLayer.characters,
    this.layerSubOrder = 0,
  }) : anchor = anchor ?? Vector2(0.5, 0.5);

  /// The effective source rectangle.
  Rect get effectiveSourceRect => sourceRect ?? texture.fullRect;

  /// The effective size of the sprite.
  Vector2 get size {
    if (customSize != null) return customSize!;
    final src = effectiveSourceRect;
    return Vector2(src.width, src.height);
  }

  /// Create a sprite that uses a sub-region of the texture.
  factory Sprite.region({
    required TextureHandle texture,
    required Rect region,
    Color color = const Color(0xFFFFFFFF),
    Vector2? anchor,
  }) {
    return Sprite(
      texture: texture,
      sourceRect: region,
      color: color,
      anchor: anchor,
    );
  }

  @override
  String toString() => 'Sprite(texture: $texture, color: $color)';
}

/// Visibility component to hide entities from rendering.
///
/// Entities with this component set to false will not be rendered.
class Visibility {
  /// Whether the entity is visible.
  bool isVisible;

  /// Creates a visibility component.
  Visibility([this.isVisible = true]);

  /// Hide the entity.
  void hide() => isVisible = false;

  /// Show the entity.
  void show() => isVisible = true;

  /// Toggle visibility.
  void toggle() => isVisible = !isVisible;
}
