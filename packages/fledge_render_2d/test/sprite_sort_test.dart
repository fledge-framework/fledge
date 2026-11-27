import 'dart:math' as math;
import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

// The draw-order sort (ExtractedSprite.sortByDrawOrder): a stable merge
// sort, which must order exactly as a stable sort on compareDrawOrder.

ExtractedSprite _sprite(Entity entity, int key, double? precise) =>
    ExtractedSprite(
      entity: entity,
      texture: const TextureHandle(id: 1, width: 8, height: 8),
      sourceRect: const Rect.fromLTWH(0, 0, 8, 8),
      transform: Matrix3.identity(),
      color: const Color(0xFFFFFFFF),
      sortKey: key,
      preciseSubOrder: precise,
      anchor: Vector2(0.5, 0.5),
      size: Vector2(8, 8),
    );

void main() {
  test('orders like a stable sort, ties kept in extraction order', () {
    final world = World();
    final random = math.Random(3);
    final scratch = <ExtractedSprite>[];
    for (final n in [0, 1, 2, 15, 16, 17, 33, 100, 1000, 2500]) {
      final sprites = [
        for (var i = 0; i < n; i++)
          _sprite(
            world.spawn().entity,
            // Few keys, so plenty of full ties.
            random.nextInt(12),
            random.nextBool() ? null : random.nextInt(3).toDouble(),
          ),
      ];
      // The reference: a stable sort by index tie-break.
      final indexed = [for (final (i, s) in sprites.indexed) (i, s)]
        ..sort((a, b) {
          final c = ExtractedSprite.compareDrawOrder(a.$2, b.$2);
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
      final sorted = List.of(sprites);
      ExtractedSprite.sortByDrawOrder(sorted, scratch);
      expect(
        [for (final s in sorted) s.entity],
        [for (final (_, s) in indexed) s.entity],
        reason: 'n=$n',
      );
    }
  });
}
