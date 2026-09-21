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

    test('sortKey is preserved on the ExtractedSprite (for stable draw order)', () {
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
    });

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
      final rotation = math.atan2(s.transform.storage[1], s.transform.storage[0]);
      expect(rotation, closeTo(math.pi / 2, 1e-9));
    });
  });
}
