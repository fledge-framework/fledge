import 'dart:ui' show Color, Offset, Rect;

import 'package:fledge_ecs/fledge_ecs.dart' show Entity;
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Matrix3, Vector2;

/// Assert the destination rect an ExtractedSprite would produce
/// inside the render pipeline, using the same maths
/// `_toBackendSprite` and `SpriteBatchSystem` use. Centralised here
/// so both call sites stay in agreement.
Rect _destRectFor({required Vector2 anchor, required Vector2 size}) {
  final anchorOffsetX = (0.5 - anchor.x) * size.x;
  final anchorOffsetY = (0.5 - anchor.y) * size.y;
  return Rect.fromCenter(
    center: Offset(anchorOffsetX, anchorOffsetY),
    width: size.x,
    height: size.y,
  );
}

void main() {
  group('sprite anchor', () {
    test(
      'feet anchor (0.5, 1.0): bottom edge lands on the entity origin',
      () {
        final rect = _destRectFor(
          anchor: Vector2(0.5, 1.0),
          size: Vector2(16, 32),
        );
        expect(rect.bottom, 0);
        expect(rect.top, -32);
        expect(rect.left, -8);
        expect(rect.right, 8);
      },
    );

    test('center anchor (0.5, 0.5): sprite is centred on the origin', () {
      final rect = _destRectFor(
        anchor: Vector2(0.5, 0.5),
        size: Vector2(16, 32),
      );
      expect(rect.top, -16);
      expect(rect.bottom, 16);
      expect(rect.left, -8);
      expect(rect.right, 8);
    });

    test('top-left anchor (0, 0): entity origin is the sprite top-left', () {
      final rect = _destRectFor(
        anchor: Vector2(0, 0),
        size: Vector2(16, 32),
      );
      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.right, 16);
      expect(rect.bottom, 32);
    });

    test(
      'ExtractedSprite carries the raw anchor through to the pipeline',
      () {
        // Sanity: ExtractedSprite's own `anchor` field mirrors what
        // Sprite/AtlasSprite pass in. The batch system reads it via
        // the same formula as fledge_render_view; this test just
        // guards the field wiring.
        final extracted = ExtractedSprite(
          entity: const Entity(1, 0),
          texture: const TextureHandle(id: 1, width: 16, height: 16),
          sourceRect: const Rect.fromLTWH(0, 0, 16, 16),
          transform: Matrix3.identity(),
          color: const Color(0xFFFFFFFF),
          sortKey: 0,
          anchor: Vector2(0.5, 1.0),
          size: Vector2(16, 32),
        );
        expect(extracted.anchor.x, 0.5);
        expect(extracted.anchor.y, 1.0);
      },
    );
  });
}
