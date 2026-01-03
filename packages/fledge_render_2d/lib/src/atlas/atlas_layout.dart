import 'dart:ui' show Rect;

/// Layout information for a texture atlas.
///
/// Defines how sprites are organized within an atlas texture.
/// Supports both grid-based and custom rectangle layouts.
abstract class TextureAtlasLayout {
  /// Creates a grid-based layout.
  ///
  /// The texture is divided into a uniform grid of cells.
  ///
  /// Example:
  /// ```dart
  /// final layout = TextureAtlasLayout.grid(
  ///   textureWidth: 256,
  ///   textureHeight: 256,
  ///   columns: 8,
  ///   rows: 8,
  ///   tileWidth: 32,
  ///   tileHeight: 32,
  /// );
  /// ```
  factory TextureAtlasLayout.grid({
    required int textureWidth,
    required int textureHeight,
    required int columns,
    required int rows,
    int? tileWidth,
    int? tileHeight,
    int paddingX = 0,
    int paddingY = 0,
    int offsetX = 0,
    int offsetY = 0,
  }) {
    return GridAtlasLayout(
      textureWidth: textureWidth,
      textureHeight: textureHeight,
      columns: columns,
      rows: rows,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      paddingX: paddingX,
      paddingY: paddingY,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  /// Creates a layout from a list of rectangles.
  ///
  /// Each rectangle defines the bounds of a sprite in the atlas.
  factory TextureAtlasLayout.fromRects(List<Rect> rects) = RectAtlasLayout;

  /// Number of sprites in the atlas.
  int get length;

  /// Get the source rectangle for a sprite by index.
  Rect getRect(int index);

  /// Get all rectangles in the layout.
  List<Rect> get rects;
}

/// Grid-based texture atlas layout.
class GridAtlasLayout implements TextureAtlasLayout {
  /// Total texture width.
  final int textureWidth;

  /// Total texture height.
  final int textureHeight;

  /// Number of columns in the grid.
  final int columns;

  /// Number of rows in the grid.
  final int rows;

  /// Width of each tile.
  final int tileWidth;

  /// Height of each tile.
  final int tileHeight;

  /// Horizontal padding between tiles.
  final int paddingX;

  /// Vertical padding between tiles.
  final int paddingY;

  /// Horizontal offset from texture edge.
  final int offsetX;

  /// Vertical offset from texture edge.
  final int offsetY;

  /// Creates a grid atlas layout.
  GridAtlasLayout({
    required this.textureWidth,
    required this.textureHeight,
    required this.columns,
    required this.rows,
    int? tileWidth,
    int? tileHeight,
    this.paddingX = 0,
    this.paddingY = 0,
    this.offsetX = 0,
    this.offsetY = 0,
  })  : tileWidth = tileWidth ?? ((textureWidth - offsetX) ~/ columns),
        tileHeight = tileHeight ?? ((textureHeight - offsetY) ~/ rows);

  @override
  int get length => columns * rows;

  @override
  Rect getRect(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }

    final col = index % columns;
    final row = index ~/ columns;

    final x = offsetX + col * (tileWidth + paddingX);
    final y = offsetY + row * (tileHeight + paddingY);

    return Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      tileWidth.toDouble(),
      tileHeight.toDouble(),
    );
  }

  @override
  List<Rect> get rects => List.generate(length, getRect);

  /// Get the column for an index.
  int getColumn(int index) => index % columns;

  /// Get the row for an index.
  int getRow(int index) => index ~/ columns;

  /// Get the index for a column and row.
  int getIndex(int column, int row) => row * columns + column;
}

/// Rectangle-based texture atlas layout.
class RectAtlasLayout implements TextureAtlasLayout {
  final List<Rect> _rects;

  /// Creates a rect atlas layout.
  RectAtlasLayout(List<Rect> rects) : _rects = List.unmodifiable(rects);

  @override
  int get length => _rects.length;

  @override
  Rect getRect(int index) {
    if (index < 0 || index >= length) {
      throw RangeError.index(index, this, 'index', null, length);
    }
    return _rects[index];
  }

  @override
  List<Rect> get rects => _rects;
}
