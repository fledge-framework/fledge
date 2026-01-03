import 'dart:ui' show Color, Rect;

import '../sprite/sprite.dart';
import 'atlas_layout.dart';

/// A texture atlas (sprite sheet) for efficient sprite rendering.
///
/// A texture atlas combines multiple sprites into a single texture,
/// reducing draw calls and improving performance.
///
/// Example:
/// ```dart
/// final atlas = TextureAtlas(
///   texture: characterSheet,
///   layout: TextureAtlasLayout.grid(
///     textureWidth: 256,
///     textureHeight: 256,
///     columns: 8,
///     rows: 8,
///   ),
/// );
///
/// // Get sprite at index 5
/// final rect = atlas.getSpriteRect(5);
/// ```
class TextureAtlas {
  /// The texture containing all sprites.
  final TextureHandle texture;

  /// The layout defining sprite positions.
  final TextureAtlasLayout layout;

  /// Optional names for sprites (for named lookup).
  final Map<String, int>? _nameToIndex;

  /// Creates a texture atlas.
  TextureAtlas({
    required this.texture,
    required this.layout,
    Map<String, int>? names,
  }) : _nameToIndex = names;

  /// Creates a texture atlas with a grid layout.
  factory TextureAtlas.grid({
    required TextureHandle texture,
    required int columns,
    required int rows,
    int? tileWidth,
    int? tileHeight,
    int paddingX = 0,
    int paddingY = 0,
    int offsetX = 0,
    int offsetY = 0,
    Map<String, int>? names,
  }) {
    return TextureAtlas(
      texture: texture,
      layout: TextureAtlasLayout.grid(
        textureWidth: texture.width,
        textureHeight: texture.height,
        columns: columns,
        rows: rows,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        paddingX: paddingX,
        paddingY: paddingY,
        offsetX: offsetX,
        offsetY: offsetY,
      ),
      names: names,
    );
  }

  /// Number of sprites in the atlas.
  int get length => layout.length;

  /// Get the source rectangle for a sprite by index.
  Rect getSpriteRect(int index) => layout.getRect(index);

  /// Get the source rectangle for a sprite by name.
  ///
  /// Throws [ArgumentError] if the name is not found.
  Rect getSpriteRectByName(String name) {
    final index = _nameToIndex?[name];
    if (index == null) {
      throw ArgumentError('Sprite name not found: $name');
    }
    return getSpriteRect(index);
  }

  /// Get the sprite index for a name, or null if not found.
  int? getIndexByName(String name) => _nameToIndex?[name];

  /// Whether the atlas has named sprites.
  bool get hasNames => _nameToIndex != null && _nameToIndex.isNotEmpty;

  /// All sprite names (if available).
  Iterable<String>? get names => _nameToIndex?.keys;

  /// Create a [Sprite] component for a specific atlas index.
  Sprite createSprite(int index, {Color color = const Color(0xFFFFFFFF)}) {
    return Sprite(
      texture: texture,
      sourceRect: getSpriteRect(index),
      color: color,
    );
  }

  /// Create a [Sprite] component for a named sprite.
  Sprite createSpriteByName(
    String name, {
    Color color = const Color(0xFFFFFFFF),
  }) {
    return Sprite(
      texture: texture,
      sourceRect: getSpriteRectByName(name),
      color: color,
    );
  }
}

/// A sprite that references an atlas and an index.
///
/// Use this when you need to dynamically change which sprite
/// from an atlas is displayed (e.g., for animations).
class AtlasSprite {
  /// The texture atlas.
  final TextureAtlas atlas;

  /// Current sprite index in the atlas.
  int index;

  /// Tint color.
  Color color;

  /// Flip horizontally.
  bool flipX;

  /// Flip vertically.
  bool flipY;

  /// Creates an atlas sprite.
  AtlasSprite({
    required this.atlas,
    this.index = 0,
    this.color = const Color(0xFFFFFFFF),
    this.flipX = false,
    this.flipY = false,
  });

  /// Get the current source rectangle.
  Rect get sourceRect => atlas.getSpriteRect(index);

  /// The underlying texture.
  TextureHandle get texture => atlas.texture;

  /// Set the sprite by name.
  void setByName(String name) {
    final newIndex = atlas.getIndexByName(name);
    if (newIndex != null) {
      index = newIndex;
    }
  }
}
