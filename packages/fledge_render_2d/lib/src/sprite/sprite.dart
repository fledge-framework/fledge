import 'dart:ui' show Color, Rect;

import 'package:vector_math/vector_math.dart';

/// Handle to a texture resource.
///
/// Wraps a texture reference that can be used across the render pipeline.
/// The actual texture data is managed by the backend.
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
/// Example:
/// ```dart
/// world.spawn()
///   ..insert(Sprite(texture: playerTexture))
///   ..insert(Transform2D.from(100, 200));
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

  /// Creates a sprite component.
  Sprite({
    required this.texture,
    this.sourceRect,
    this.color = const Color(0xFFFFFFFF),
    this.flipX = false,
    this.flipY = false,
    Vector2? anchor,
    this.customSize,
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
