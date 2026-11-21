import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

ExtractedSprite _sprite(int texture, int sortKey) => ExtractedSprite(
  entity: Entity.placeholder,
  texture: TextureHandle(id: texture, width: 8, height: 8),
  sourceRect: const Rect.fromLTWH(0, 0, 8, 8),
  transform: Matrix3.identity(),
  color: const Color(0xFFFFFFFF),
  sortKey: sortKey,
  anchor: Vector2(0.5, 0.5),
  size: Vector2(8, 8),
);

/// Records the textures of the batches drawn, in order.
class _Order implements SpriteDrawer {
  final List<int> textures = [];

  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    for (var i = 0; i < batch.length; i++) {
      textures.add(texture.id);
    }
  }
}

void main() {
  test('sprites added to the list and the old way as entities are both '
      'extracted, counted and drawn', () {
    final world = RenderWorld();
    final listed = _sprite(1, 10);
    final old = _sprite(2, 20);
    world.addSprite(listed);
    world.add(old);
    expect(world.extractedSprites, unorderedEquals([listed, old]));
    expect(world.extractedSpriteCount, 2);
    final drawn = _Order();
    renderSpritesToDrawer(world, drawn);
    expect(drawn.textures, [1, 2]);
  });

  test('clear empties the list with the entities', () {
    final world = RenderWorld()
      ..addSprite(_sprite(1, 1))
      ..add(_sprite(2, 2));
    world.clear();
    expect(world.extractedSprites, isEmpty);
    expect(world.extractedSpriteCount, 0);
  });

  test('draw order is the sort order, whichever way a sprite was added', () {
    final mixed = RenderWorld()
      ..addSprite(_sprite(3, 30))
      ..add(_sprite(1, 10))
      ..addSprite(_sprite(2, 20))
      ..add(_sprite(4, 40));
    final listed = RenderWorld()
      ..addSprite(_sprite(1, 10))
      ..addSprite(_sprite(2, 20))
      ..addSprite(_sprite(3, 30))
      ..addSprite(_sprite(4, 40));
    final a = _Order(), b = _Order();
    renderSpritesToDrawer(mixed, a);
    renderSpritesToDrawer(listed, b);
    expect(a.textures, [1, 2, 3, 4]);
    expect(a.textures, b.textures);
    // Full ties keep the order they were added in.
    final tied = RenderWorld()
      ..addSprite(_sprite(5, 7))
      ..addSprite(_sprite(6, 7))
      ..addSprite(_sprite(5, 7));
    final c = _Order();
    renderSpritesToDrawer(tied, c);
    expect(c.textures, [5, 6, 5]);
  });
}
