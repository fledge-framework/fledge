import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const texture = TextureHandle(id: 1, width: 16, height: 16);
  const src = Rect.fromLTWH(0, 0, 16, 16);

  group('tileToSprite', () {
    test('emits an ExtractedSprite with the tile\'s centre as translation', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: const Offset(32, 48),
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: 0,
      );
      // Centre = topLeft + size/2 → (32+8, 48+8) = (40, 56)
      expect(s.transform.storage[6], 40);
      expect(s.transform.storage[7], 56);
      expect(s.size.x, 16);
      expect(s.size.y, 16);
      expect(s.anchor.x, 0.5);
      expect(s.anchor.y, 0.5);
    });

    test('no flip → zero rotation', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: 0,
      );
      // Rotation = 0 → cos = 1, sin = 0 → storage[0]=1, storage[1]=0.
      expect(s.transform.storage[0], closeTo(1, 1e-9));
      expect(s.transform.storage[1], closeTo(0, 1e-9));
    });

    test('H + V flips → 180° rotation', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: TileFlipFlags.horizontal | TileFlipFlags.vertical,
      );
      // 180° → cos = -1, sin = 0.
      expect(s.transform.storage[0], closeTo(-1, 1e-9));
      expect(s.transform.storage[1], closeTo(0, 1e-9));
    });

    test('D + H flips → 90° clockwise rotation', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: TileFlipFlags.diagonal | TileFlipFlags.horizontal,
      );
      // 90° cw → cos(π/2)=0, sin(π/2)=1.
      expect(s.transform.storage[0], closeTo(0, 1e-9));
      expect(s.transform.storage[1], closeTo(1, 1e-9));
    });

    test('D + V flips → 90° counter-clockwise rotation', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: TileFlipFlags.diagonal | TileFlipFlags.vertical,
      );
      // -90° → cos(-π/2)=0, sin(-π/2)=-1.
      expect(s.transform.storage[0], closeTo(0, 1e-9));
      expect(s.transform.storage[1], closeTo(-1, 1e-9));
    });

    test("every one of Tiled's eight orientations draws as Tiled shows it", () {
      const h = TileFlipFlags.horizontal;
      const v = TileFlipFlags.vertical;
      const d = TileFlipFlags.diagonal;
      for (final flags in [0, h, v, d, h | v, h | d, v | d, h | v | d]) {
        // What Tiled does to the tile's local x and y axes: D swaps them,
        // then H negates x and V negates y.
        var (ax, ay, bx, by) = flags & d != 0 ? (0, 1, 1, 0) : (1, 0, 0, 1);
        if (flags & h != 0) (ax, bx) = (-ax, -bx);
        if (flags & v != 0) (ay, by) = (-ay, -by);
        final s = tileToSprite(
          texture: texture,
          sourceRect: src,
          tileTopLeft: Offset.zero,
          tileWidth: 16,
          tileHeight: 16,
          color: const Color(0xFFFFFFFF),
          sortKey: 0,
          flipFlags: flags,
        );
        // The renderer mirrors x in the tile's own space, then transforms.
        final m = s.transform.storage;
        final sx = s.flipX ? -1.0 : 1.0;
        expect(s.flipY, isFalse);
        expect(m[0] * sx, closeTo(ax.toDouble(), 1e-9), reason: '$flags');
        expect(m[1] * sx, closeTo(ay.toDouble(), 1e-9), reason: '$flags');
        expect(m[3], closeTo(bx.toDouble(), 1e-9), reason: '$flags');
        expect(m[4], closeTo(by.toDouble(), 1e-9), reason: '$flags');
      }
    });

    test('layer derived from sortKey', () {
      // ground = index 1, characters = index 2, foreground = index 3.
      final key = DrawLayer.foreground.sortKey(subOrder: 500);
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: key,
        flipFlags: 0,
      );
      expect(s.layer, DrawLayer.foreground);
      expect(s.layerSubOrder, 500);
      expect(s.sortKey, key);
    });

    test(
      'sortKey is preserved on the ExtractedSprite (for stable draw order)',
      () {
        final s = tileToSprite(
          texture: texture,
          sourceRect: src,
          tileTopLeft: Offset.zero,
          tileWidth: 16,
          tileHeight: 16,
          color: const Color(0xFFFFFFFF),
          sortKey: 12345,
          flipFlags: 0,
        );
        expect(s.sortKey, 12345);
      },
    );

    // Sanity — the rotation matches math.atan2 result.
    test('sanity: rotation of D+H equals π/2', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: src,
        tileTopLeft: Offset.zero,
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: TileFlipFlags.diagonal | TileFlipFlags.horizontal,
      );
      final rotation = math.atan2(
        s.transform.storage[1],
        s.transform.storage[0],
      );
      expect(rotation, closeTo(math.pi / 2, 1e-9));
    });
  });

  group('tileToSprite, tiles not the size of the grid', () {
    ExtractedSprite tall({int flipFlags = 0, Offset offset = Offset.zero}) =>
        tileToSprite(
          texture: texture,
          // A 32x48 tile on a 16x16 grid, in the cell at (0, 0).
          sourceRect: const Rect.fromLTWH(0, 0, 32, 48),
          tileTopLeft: Offset.zero,
          tileWidth: 16,
          tileHeight: 16,
          color: const Color(0xFFFFFFFF),
          sortKey: 0,
          flipFlags: flipFlags,
          drawOffset: offset,
        );

    test('is drawn at its own size, its bottom-left on the cell\'s', () {
      final s = tall();
      expect((s.size.x, s.size.y), (32.0, 48.0));
      // Box from (0, 16 - 48) to (32, 16): centre (16, -8).
      expect((s.transform.storage[6], s.transform.storage[7]), (16.0, -8.0));
    });

    test('moves by the tileset\'s tile offset', () {
      final s = tall(offset: const Offset(2, 3));
      expect((s.transform.storage[6], s.transform.storage[7]), (18.0, -5.0));
    });

    test('a diagonal flip swaps the box, still on the bottom-left', () {
      final s = tall(flipFlags: TileFlipFlags.diagonal);
      expect((s.size.x, s.size.y), (32.0, 48.0));
      // Box 48 wide, 32 tall: from (0, -16) to (48, 16).
      expect((s.transform.storage[6], s.transform.storage[7]), (24.0, 0.0));
    });

    test('an empty source rect falls back to the cell', () {
      final s = tileToSprite(
        texture: texture,
        sourceRect: Rect.zero,
        tileTopLeft: const Offset(32, 48),
        tileWidth: 16,
        tileHeight: 16,
        color: const Color(0xFFFFFFFF),
        sortKey: 0,
        flipFlags: 0,
      );
      expect((s.size.x, s.size.y), (16.0, 16.0));
      expect((s.transform.storage[6], s.transform.storage[7]), (40.0, 56.0));
    });
  });
}
