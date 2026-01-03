import 'dart:ui' show Color, Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GridAtlasLayout', () {
    test('creates grid with computed tile size', () {
      final layout = TextureAtlasLayout.grid(
        textureWidth: 256,
        textureHeight: 128,
        columns: 8,
        rows: 4,
      );

      expect(layout.length, 32);
      expect(layout is GridAtlasLayout, isTrue);

      final grid = layout as GridAtlasLayout;
      expect(grid.tileWidth, 32); // 256 / 8
      expect(grid.tileHeight, 32); // 128 / 4
    });

    test('creates grid with explicit tile size', () {
      final layout = TextureAtlasLayout.grid(
        textureWidth: 256,
        textureHeight: 256,
        columns: 4,
        rows: 4,
        tileWidth: 48,
        tileHeight: 48,
      );

      final grid = layout as GridAtlasLayout;
      expect(grid.tileWidth, 48);
      expect(grid.tileHeight, 48);
    });

    test('getRect returns correct rectangles', () {
      final layout = TextureAtlasLayout.grid(
        textureWidth: 128,
        textureHeight: 128,
        columns: 4,
        rows: 4,
        tileWidth: 32,
        tileHeight: 32,
      );

      // First tile (top-left)
      final rect0 = layout.getRect(0);
      expect(rect0.left, 0);
      expect(rect0.top, 0);
      expect(rect0.width, 32);
      expect(rect0.height, 32);

      // Second tile
      final rect1 = layout.getRect(1);
      expect(rect1.left, 32);
      expect(rect1.top, 0);

      // First tile of second row
      final rect4 = layout.getRect(4);
      expect(rect4.left, 0);
      expect(rect4.top, 32);

      // Last tile
      final rect15 = layout.getRect(15);
      expect(rect15.left, 96);
      expect(rect15.top, 96);
    });

    test('respects padding', () {
      final layout = TextureAtlasLayout.grid(
        textureWidth: 256,
        textureHeight: 256,
        columns: 4,
        rows: 4,
        tileWidth: 32,
        tileHeight: 32,
        paddingX: 4,
        paddingY: 4,
      );

      final rect0 = layout.getRect(0);
      expect(rect0.left, 0);
      expect(rect0.top, 0);

      // Second tile should account for padding
      final rect1 = layout.getRect(1);
      expect(rect1.left, 36); // 32 + 4 padding
      expect(rect1.top, 0);

      // First of second row
      final rect4 = layout.getRect(4);
      expect(rect4.left, 0);
      expect(rect4.top, 36); // 32 + 4 padding
    });

    test('respects offset', () {
      final layout = TextureAtlasLayout.grid(
        textureWidth: 256,
        textureHeight: 256,
        columns: 4,
        rows: 4,
        tileWidth: 32,
        tileHeight: 32,
        offsetX: 8,
        offsetY: 8,
      );

      final rect0 = layout.getRect(0);
      expect(rect0.left, 8);
      expect(rect0.top, 8);
    });

    test('getColumn and getRow', () {
      final layout = GridAtlasLayout(
        textureWidth: 128,
        textureHeight: 128,
        columns: 4,
        rows: 4,
      );

      expect(layout.getColumn(0), 0);
      expect(layout.getRow(0), 0);

      expect(layout.getColumn(1), 1);
      expect(layout.getRow(1), 0);

      expect(layout.getColumn(4), 0);
      expect(layout.getRow(4), 1);

      expect(layout.getColumn(7), 3);
      expect(layout.getRow(7), 1);
    });

    test('getIndex', () {
      final layout = GridAtlasLayout(
        textureWidth: 128,
        textureHeight: 128,
        columns: 4,
        rows: 4,
      );

      expect(layout.getIndex(0, 0), 0);
      expect(layout.getIndex(1, 0), 1);
      expect(layout.getIndex(0, 1), 4);
      expect(layout.getIndex(3, 3), 15);
    });

    test('throws on invalid index', () {
      final layout = TextureAtlasLayout.grid(
        textureWidth: 128,
        textureHeight: 128,
        columns: 4,
        rows: 4,
      );

      expect(() => layout.getRect(-1), throwsRangeError);
      expect(() => layout.getRect(16), throwsRangeError);
    });
  });

  group('RectAtlasLayout', () {
    test('creates from list of rects', () {
      final rects = [
        const Rect.fromLTWH(0, 0, 32, 32),
        const Rect.fromLTWH(32, 0, 64, 64),
        const Rect.fromLTWH(0, 64, 32, 32),
      ];

      final layout = TextureAtlasLayout.fromRects(rects);

      expect(layout.length, 3);
      expect(layout.getRect(0).width, 32);
      expect(layout.getRect(1).width, 64);
      expect(layout.rects, equals(rects));
    });

    test('throws on invalid index', () {
      final layout = TextureAtlasLayout.fromRects([
        const Rect.fromLTWH(0, 0, 32, 32),
      ]);

      expect(() => layout.getRect(-1), throwsRangeError);
      expect(() => layout.getRect(1), throwsRangeError);
    });
  });

  group('TextureAtlas', () {
    test('creates with layout', () {
      const texture = TextureHandle(id: 1, width: 256, height: 256);
      final layout = TextureAtlasLayout.grid(
        textureWidth: 256,
        textureHeight: 256,
        columns: 8,
        rows: 8,
      );

      final atlas = TextureAtlas(texture: texture, layout: layout);

      expect(atlas.texture, texture);
      expect(atlas.length, 64);
      expect(atlas.hasNames, isFalse);
    });

    test('creates grid atlas with factory', () {
      const texture = TextureHandle(id: 1, width: 256, height: 256);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
      );

      expect(atlas.length, 16);
      expect(atlas.getSpriteRect(0).width, 64);
    });

    test('supports named sprites', () {
      const texture = TextureHandle(id: 1, width: 256, height: 256);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
        names: {
          'idle': 0,
          'walk1': 1,
          'walk2': 2,
          'walk3': 3,
        },
      );

      expect(atlas.hasNames, isTrue);
      expect(atlas.names, containsAll(['idle', 'walk1', 'walk2', 'walk3']));
      expect(atlas.getIndexByName('idle'), 0);
      expect(atlas.getIndexByName('walk2'), 2);
      expect(atlas.getIndexByName('unknown'), isNull);
    });

    test('getSpriteRectByName', () {
      const texture = TextureHandle(id: 1, width: 128, height: 128);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
        names: {'target': 5},
      );

      final rect = atlas.getSpriteRectByName('target');
      expect(rect.left, 32); // Column 1
      expect(rect.top, 32); // Row 1
    });

    test('getSpriteRectByName throws on unknown name', () {
      const texture = TextureHandle(id: 1, width: 128, height: 128);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
        names: {'known': 0},
      );

      expect(
        () => atlas.getSpriteRectByName('unknown'),
        throwsArgumentError,
      );
    });

    test('createSprite creates sprite component', () {
      const texture = TextureHandle(id: 1, width: 128, height: 128);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
      );

      final sprite = atlas.createSprite(5, color: const Color(0xFF0000FF));

      expect(sprite.texture, texture);
      expect(sprite.sourceRect, isNotNull);
      expect(sprite.sourceRect!.left, 32);
      expect(sprite.color.value, 0xFF0000FF);
    });
  });

  group('AtlasSprite', () {
    test('creates with defaults', () {
      const texture = TextureHandle(id: 1, width: 128, height: 128);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
      );

      final atlasSprite = AtlasSprite(atlas: atlas);

      expect(atlasSprite.index, 0);
      expect(atlasSprite.color.value, 0xFFFFFFFF);
      expect(atlasSprite.flipX, isFalse);
      expect(atlasSprite.flipY, isFalse);
    });

    test('sourceRect reflects current index', () {
      const texture = TextureHandle(id: 1, width: 128, height: 128);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
      );

      final atlasSprite = AtlasSprite(atlas: atlas, index: 5);

      expect(atlasSprite.sourceRect.left, 32);
      expect(atlasSprite.sourceRect.top, 32);

      atlasSprite.index = 6;
      expect(atlasSprite.sourceRect.left, 64);
      expect(atlasSprite.sourceRect.top, 32);
    });

    test('setByName updates index', () {
      const texture = TextureHandle(id: 1, width: 128, height: 128);
      final atlas = TextureAtlas.grid(
        texture: texture,
        columns: 4,
        rows: 4,
        names: {'target': 10},
      );

      final atlasSprite = AtlasSprite(atlas: atlas);
      atlasSprite.setByName('target');

      expect(atlasSprite.index, 10);
    });
  });
}
