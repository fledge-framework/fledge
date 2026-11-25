import 'dart:ui' show Color, Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const _texture = TextureHandle(id: 1, width: 32, height: 32);
final _atlas = TextureAtlas.grid(texture: _texture, columns: 2, rows: 2);

/// A world whose camera shows 400 x 300 world units around the origin.
World _scene() => World()
  ..insertResource(
    ActiveCameraView(x: 0, y: 0, zoomFor: (_) => 1)
      ..viewportSize = const Size(400, 300),
  );

Entity _placeAtlas(World world, double x, double y, {bool frozen = false}) {
  final e = world.spawn()
    ..insert(AtlasSprite(atlas: _atlas))
    ..insert(Transform2D(translation: Vector2(x, y)));
  if (frozen) e.insert(const StaticTransform());
  return e.entity;
}

Set<Entity> _extracted(World world, Extractor extractor) {
  final renderWorld = RenderWorld();
  extractor.extract(world, renderWorld);
  return {for (final s in renderWorld.extractedSprites) s.entity};
}

void main() {
  test('atlas sprites far off screen are culled, near ones kept', () {
    final world = _scene();
    final near = _placeAtlas(world, 10, 10);
    final inMargin = _placeAtlas(world, 230, 0); // past 200, within margin
    _placeAtlas(world, 5000, 0);
    _placeAtlas(world, 0, -5000);
    TransformPropagateSystem().run(world);
    expect(_extracted(world, AtlasSpriteExtractor()), {near, inMargin});
  });

  test('with no camera view, no atlas sprite is culled', () {
    final world = World();
    final a = _placeAtlas(world, 0, 0);
    final b = _placeAtlas(world, 5000, 5000);
    TransformPropagateSystem().run(world);
    expect(_extracted(world, AtlasSpriteExtractor()), {a, b});
  });

  test('frozen atlas sprites go through the grid: near drawn, far not, and '
      'new ones found', () {
    final world = _scene();
    final near = _placeAtlas(world, 10, 10, frozen: true);
    _placeAtlas(world, 4000, 4000, frozen: true);
    final propagate = TransformPropagateSystem()..run(world);
    final extractor = AtlasSpriteExtractor();
    expect(_extracted(world, extractor), {near});
    final later = _placeAtlas(world, -100, 50, frozen: true);
    propagate.run(world);
    expect(_extracted(world, extractor), {near, later});
    // Frame changes and hiding still apply to frozen atlas sprites.
    world.get<AtlasSprite>(near)!.index = 3;
    world.insert(later, Visibility(false));
    final renderWorld = RenderWorld();
    extractor.extract(world, renderWorld);
    final sprites = renderWorld.extractedSprites.toList();
    expect(sprites.map((s) => s.entity), [near]);
    expect(sprites.single.sourceRect, _atlas.getSpriteRect(3));
  });

  test('emissive is carried onto the extracted sprite', () {
    final world = World();
    world.spawn()
      ..insert(AtlasSprite(atlas: _atlas, emissive: true))
      ..insert(GlobalTransform2D());
    world.spawn()
      ..insert(AtlasSprite(atlas: _atlas))
      ..insert(GlobalTransform2D());
    final renderWorld = RenderWorld();
    AtlasSpriteExtractor().extract(world, renderWorld);
    expect(
      renderWorld.extractedSprites.map((s) => s.emissive).toList()
        ..sort((a, b) => (a ? 1 : 0) - (b ? 1 : 0)),
      [false, true],
    );
  });

  test('fully transparent atlas sprites are skipped, like sprites', () {
    final world = World();
    world.spawn()
      ..insert(AtlasSprite(atlas: _atlas, color: const Color(0x00FFFFFF)))
      ..insert(GlobalTransform2D());
    expect(_extracted(world, AtlasSpriteExtractor()), isEmpty);
  });

  test('atlas and plain sprites extract the same transform, sort key and '
      'flags, interpolated or not', () {
    for (final alpha in [1.0, 0.25]) {
      final world = World()..insertResource(FixedTimestep());
      final ft = world.getResource<FixedTimestep>()!;
      ft.addAccumulated(ft.stepSeconds * alpha);
      final frame = _atlas.getSpriteRect(0);
      for (final atlas in [true, false]) {
        final e = world.spawn()
          ..insert(Transform2D(translation: Vector2(40, 60)))
          ..insert(PreviousTransform2D(translation: Vector2(0, 20)));
        if (atlas) {
          e.insert(AtlasSprite(atlas: _atlas, flipX: true, emissive: true));
        } else {
          e.insert(
            Sprite(
              texture: _texture,
              sourceRect: frame,
              flipX: true,
              emissive: true,
            ),
          );
        }
      }
      TransformPropagateSystem().run(world);
      final a = RenderWorld();
      AtlasSpriteExtractor().extract(world, a);
      final s = RenderWorld();
      SpriteExtractor().extract(world, s);
      final atlasSprite = a.extractedSprites.single;
      final plainSprite = s.extractedSprites.single;
      expect(atlasSprite.transform.storage, plainSprite.transform.storage);
      expect(atlasSprite.sortKey, plainSprite.sortKey);
      expect(atlasSprite.preciseSubOrder, plainSprite.preciseSubOrder);
      expect(atlasSprite.flipFlags, plainSprite.flipFlags);
      expect(atlasSprite.emissive, plainSprite.emissive);
      expect(atlasSprite.size, plainSprite.size);
      expect(atlasSprite.sourceRect, plainSprite.sourceRect);
      if (alpha < 1) {
        expect(atlasSprite.transform.storage[6], closeTo(10, 1e-9));
      }
    }
  });
}
