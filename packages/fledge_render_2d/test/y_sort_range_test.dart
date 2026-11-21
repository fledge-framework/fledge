import 'dart:ui' show Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Y-sorting beyond the packed integer key's 0..9,999.9 window.
///
/// `DrawLayer.sortKey` packs `y * ySortScale` clamped to 0..99,999, so
/// every sprite past y = 9,999.9 (or above y = 0) used to share one key
/// and sort arbitrarily. Draw order is now the composite
/// `(sortKey, preciseSubOrder)`.

class _RecordingDrawer implements SpriteDrawer {
  final textures = <int>[];

  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    for (var i = 0; i < batch.length; i++) {
      textures.add(texture.id);
    }
  }
}

/// Spawn one sprite per y (each with its own texture id so the drawer
/// records the order) and return texture ids in draw order.
List<int> _drawOrder(List<({double y, DrawLayer layer})> sprites) {
  final world = World();
  final renderWorld = RenderWorld();
  for (var i = 0; i < sprites.length; i++) {
    final gt = GlobalTransform2D()..translation = Vector2(0, sprites[i].y);
    world.spawn()
      ..insert(
        Sprite(
          texture: TextureHandle(id: i, width: 8, height: 8),
          layer: sprites[i].layer,
        ),
      )
      ..insert(gt);
  }
  SpriteExtractor().extract(world, renderWorld);
  final drawer = _RecordingDrawer();
  renderSpritesToDrawer(renderWorld, drawer);
  return drawer.textures;
}

ExtractedSprite _extracted({
  required int sortKey,
  double? precise,
  int id = 0,
  DrawLayer layer = DrawLayer.characters,
}) => ExtractedSprite(
  entity: Entity(id, 0),
  texture: const TextureHandle(id: 1, width: 8, height: 8),
  sourceRect: const Rect.fromLTWH(0, 0, 8, 8),
  transform: Matrix3.identity(),
  color: const Color(0xFFFFFFFF),
  sortKey: sortKey,
  layer: layer,
  preciseSubOrder: precise,
  anchor: Vector2(0.5, 0.5),
  size: Vector2(8, 8),
);

void main() {
  const c = DrawLayer.characters;

  test('sprites at y = 9,000 / 11,000 / 50,000 / -500 sort by y', () {
    // Spawned deliberately out of order.
    final order = _drawOrder([
      (y: 50000, layer: c), // 0
      (y: 11000, layer: c), // 1
      (y: -500, layer: c), // 2
      (y: 9000, layer: c), // 3
      (y: 12000, layer: c), // 4
      (y: -10, layer: c), // 5
    ]);
    expect(order, [2, 5, 3, 1, 4, 0]);
  });

  test('sub-0.1 px separation is ordered too', () {
    final order = _drawOrder([(y: 100.07, layer: c), (y: 100.02, layer: c)]);
    expect(order, [1, 0]);
  });

  test('layers still dominate the y sub-order', () {
    final order = _drawOrder([
      (y: -500, layer: DrawLayer.foreground), // 0
      (y: 50000, layer: DrawLayer.ground), // 1
      (y: -500, layer: c), // 2
      (y: 50000, layer: c), // 3
      (y: 1e9, layer: DrawLayer.background), // 4
    ]);
    expect(order, [4, 1, 2, 3, 0]);
  });

  test('integer sortKey is unchanged (clamped, as before)', () {
    final world = World();
    final renderWorld = RenderWorld();
    for (final y in const [12000.0, -500.0, 123.5]) {
      world.spawn()
        ..insert(
          Sprite(texture: const TextureHandle(id: 1, width: 8, height: 8)),
        )
        ..insert(GlobalTransform2D()..translation = Vector2(0, y));
    }
    SpriteExtractor().extract(world, renderWorld);
    final byPrecise = {
      for (final s in renderWorld.extractedSprites)
        s.preciseSubOrder!: s.sortKey,
    };
    expect(byPrecise[120000], c.sortKey(subOrder: 99999));
    expect(byPrecise[-5000], c.sortKey(subOrder: 0));
    expect(byPrecise[1235], c.sortKey(subOrder: 1235));
    expect(DrawLayerExtension.ySortSubOrder(123.45), 1234);
    expect(DrawLayerExtension.ySortSubOrder(-5), 0);
    expect(DrawLayerExtension.ySortSubOrder(1e9), 99999);
  });

  test('explicit layerSubOrder sprites carry no precise sub-order', () {
    final world = World();
    final renderWorld = RenderWorld();
    world.spawn()
      ..insert(
        Sprite(
          texture: const TextureHandle(id: 1, width: 8, height: 8),
          layerSubOrder: 42,
        ),
      )
      ..insert(GlobalTransform2D()..translation = Vector2(0, 50000));
    SpriteExtractor().extract(world, renderWorld);
    final s = renderWorld.extractedSprites.single;
    expect(s.preciseSubOrder, isNull);
    expect(s.effectiveSubOrder, 42);
    expect(s.sortKey, c.sortKey(subOrder: 42));
  });

  group('compareDrawOrder / sortByDrawOrder', () {
    test('differing sortKeys order exactly as before', () {
      // precise sub-orders deliberately contradict the keys: they are
      // only a tie-breaker.
      final a = _extracted(sortKey: 100, precise: 9e9);
      final b = _extracted(sortKey: 101, precise: -9e9);
      expect(ExtractedSprite.compareDrawOrder(a, b), lessThan(0));
    });

    test('sprites without preciseSubOrder fall back to sortKey', () {
      // e.g. tiles from fledge_tiled (sortKeyFromIndex / sortKey with
      // tile.y * 100 + layerIndex) and hand-built ExtractedSprites.
      final keys = [
        DrawLayerExtension.sortKeyFromIndex(layerIndex: 3, subOrder: 7),
        DrawLayer.ground.sortKey(subOrder: 5 * 100 + 2),
        DrawLayerExtension.sortKeyFromIndex(layerIndex: 0),
        DrawLayer.ground.sortKey(subOrder: 5 * 100 + 1),
        DrawLayer.foreground.sortKey(subOrder: 3),
      ];
      final sprites = [
        for (var i = 0; i < keys.length; i++)
          _extracted(sortKey: keys[i], id: i),
      ];
      ExtractedSprite.sortByDrawOrder(sprites);
      expect(sprites.map((s) => s.sortKey), [...keys]..sort());
      expect(
        DrawLayerExtension.sortKeyFromIndex(layerIndex: 3, subOrder: 7),
        300007,
      );
    });

    test('stable for equal composite keys', () {
      // > 32 elements so Dart's List.sort uses its unstable quicksort.
      final sprites = [
        for (var i = 0; i < 200; i++)
          _extracted(
            sortKey: c.sortKey(subOrder: 99999),
            precise: (i % 3) * 1e5 + 1e6,
            id: i,
          ),
      ];
      ExtractedSprite.sortByDrawOrder(sprites);
      for (var i = 1; i < sprites.length; i++) {
        final prev = sprites[i - 1];
        final cur = sprites[i];
        if (prev.preciseSubOrder == cur.preciseSubOrder) {
          expect(prev.entity.id, lessThan(cur.entity.id));
        } else {
          expect(prev.preciseSubOrder!, lessThan(cur.preciseSubOrder!));
        }
      }
    });
  });

  test('SpriteBatchSystem orders within a texture by precise y', () async {
    final world = World();
    final renderWorld = RenderWorld();
    for (final y in const [50000.0, -500.0, 11000.0]) {
      world.spawn()
        ..insert(
          Sprite(texture: const TextureHandle(id: 1, width: 8, height: 8)),
        )
        ..insert(GlobalTransform2D()..translation = Vector2(0, y));
    }
    SpriteExtractor().extract(world, renderWorld);
    await SpriteBatchSystem().run(world, renderWorld);
    final batch = renderWorld.getResource<SpriteBatches>()!.all.single;
    expect(batch.instances.map((i) => i.transform.storage[7]), [
      -500,
      11000,
      50000,
    ]);
  });
}
