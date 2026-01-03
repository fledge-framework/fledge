import 'dart:ui' show Color;

import '../sprite/sprite.dart';
import 'material2d.dart';

/// Standard material for sprite rendering.
///
/// This is the default material used for sprites. It supports:
/// - Texture mapping
/// - Tint color
/// - Blend modes
/// - Alpha testing
///
/// Example:
/// ```dart
/// final material = SpriteMaterial(
///   texture: playerTexture,
///   tint: Color(0xFF00FF00), // Green tint
///   blendMode: BlendMode.additive,
/// );
/// ```
class SpriteMaterial extends Material2D {
  /// The sprite texture.
  final TextureHandle texture;

  /// Tint color applied to the texture.
  ///
  /// White (0xFFFFFFFF) means no tint.
  Color tint;

  /// Alpha threshold for alpha testing.
  ///
  /// Pixels with alpha below this value are discarded.
  /// Set to 0 to disable alpha testing.
  double alphaThreshold;

  @override
  final BlendMode blendMode;

  /// Creates a sprite material.
  SpriteMaterial({
    required this.texture,
    this.tint = const Color(0xFFFFFFFF),
    this.blendMode = BlendMode.normal,
    this.alphaThreshold = 0,
  });

  @override
  Object get id => (SpriteMaterial, texture.id, blendMode);

  @override
  bool canBatchWith(Material2D other) {
    if (other is! SpriteMaterial) return false;
    return texture.id == other.texture.id &&
        blendMode == other.blendMode &&
        alphaThreshold == other.alphaThreshold;
  }

  /// Create a copy with optional overrides.
  SpriteMaterial copyWith({
    TextureHandle? texture,
    Color? tint,
    BlendMode? blendMode,
    double? alphaThreshold,
  }) {
    return SpriteMaterial(
      texture: texture ?? this.texture,
      tint: tint ?? this.tint,
      blendMode: blendMode ?? this.blendMode,
      alphaThreshold: alphaThreshold ?? this.alphaThreshold,
    );
  }

  @override
  String toString() =>
      'SpriteMaterial(texture: $texture, tint: $tint, blend: $blendMode)';
}

/// Material for rendering colored shapes without texture.
///
/// Useful for debug rendering, UI backgrounds, etc.
class ColorMaterial extends Material2D {
  /// The solid color.
  Color color;

  @override
  final BlendMode blendMode;

  /// Creates a color material.
  ColorMaterial({
    required this.color,
    this.blendMode = BlendMode.normal,
  });

  @override
  Object get id => (ColorMaterial, blendMode);

  @override
  bool canBatchWith(Material2D other) {
    if (other is! ColorMaterial) return false;
    return blendMode == other.blendMode;
  }

  /// Create a copy with optional overrides.
  ColorMaterial copyWith({
    Color? color,
    BlendMode? blendMode,
  }) {
    return ColorMaterial(
      color: color ?? this.color,
      blendMode: blendMode ?? this.blendMode,
    );
  }

  @override
  String toString() => 'ColorMaterial(color: $color, blend: $blendMode)';
}
