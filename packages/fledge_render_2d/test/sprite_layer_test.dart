import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const _texture = TextureHandle(id: 1, width: 32, height: 32);

/// Spawns an entity with a Sprite + GlobalTransform2D at y, then runs the
/// extractor and returns the resulting ExtractedSprite.
ExtractedSprite _extractAt({
  required DrawLayer layer,
  required double y,
  int layerSubOrder = 0,
}) {
  final world = World();
  final renderWorld = RenderWorld();

  final gt = GlobalTransform2D();
  gt.translation = Vector2(0, y);

  world.spawn()
    ..insert(
      Sprite(texture: _texture, layer: layer, layerSubOrder: layerSubOrder),
    )
    ..insert(gt);

  SpriteExtractor().extract(world, renderWorld);

  final results = <ExtractedSprite>[];
  for (final (_, es) in renderWorld.query1<ExtractedSprite>().iter()) {
    results.add(es);
  }
  expect(results, hasLength(1));
  return results.single;
}

void main() {
  group('Sprite layer defaults', () {
    test('Sprite defaults to DrawLayer.characters and subOrder 0', () {
      final sprite = Sprite(texture: _texture);
      expect(sprite.layer, DrawLayer.characters);
      expect(sprite.layerSubOrder, 0);
    });

    test('Sprite(texture: t) still compiles without specifying layer', () {
      // Compile-time check: the following construction must remain valid.
      final sprite = Sprite(texture: _texture);
      expect(sprite.texture, _texture);
    });
  });

  group('ExtractedSprite.sortKey layer ranges', () {
    test('background layer produces a sort key in the 0-99,999 range', () {
      final extracted = _extractAt(layer: DrawLayer.background, y: 50);
      expect(extracted.sortKey, greaterThanOrEqualTo(0));
      expect(extracted.sortKey, lessThan(DrawLayer.ground.sortKey()));
      // NOT in the characters range.
      expect(extracted.sortKey, lessThan(DrawLayer.characters.sortKey()));
    });

    test('ui layer produces a sort key >= 500,000', () {
      final extracted = _extractAt(layer: DrawLayer.ui, y: 10);
      expect(extracted.sortKey, greaterThanOrEqualTo(500000));
      expect(extracted.layer, DrawLayer.ui);
    });

    test('explicit layerSubOrder overrides the Y-based sub-order', () {
      final extracted = _extractAt(
        layer: DrawLayer.characters,
        y: 999,
        layerSubOrder: 42,
      );
      // With explicit sub-order, the Y position is ignored.
      expect(extracted.sortKey, DrawLayer.characters.sortKey(subOrder: 42));
      expect(extracted.layerSubOrder, 42);
    });

    test('two sprites in the same layer sort by Y (higher Y = later)', () {
      final lower = _extractAt(layer: DrawLayer.characters, y: 10);
      final higher = _extractAt(layer: DrawLayer.characters, y: 100);
      expect(higher.sortKey, greaterThan(lower.sortKey));
    });

    test('huge Y sub-order is clamped inside the layer bucket', () {
      // y=999999 -> sub = 999,999,000 raw; must be clamped to 99,999.
      final extracted = _extractAt(layer: DrawLayer.characters, y: 999999);
      // Sort key must not bleed into the foreground layer.
      expect(extracted.sortKey, lessThan(DrawLayer.foreground.sortKey()));
      // And it must still be inside the characters range.
      expect(
        extracted.sortKey,
        greaterThanOrEqualTo(DrawLayer.characters.sortKey()),
      );
    });
  });
}
