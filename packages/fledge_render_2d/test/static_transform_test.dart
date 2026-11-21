import 'dart:ui' show Color, Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const _texture = TextureHandle(id: 1, width: 16, height: 16);

Set<Entity> _extracted(World world, SpriteExtractor extractor) {
  final renderWorld = RenderWorld();
  extractor.extract(world, renderWorld);
  return {for (final s in renderWorld.extractedSprites) s.entity};
}

void main() {
  group('propagation', () {
    test('a static root and its subtree are computed once, then frozen', () {
      final world = World();
      final root = world.spawn()
        ..insert(Transform2D(translation: Vector2(100, 50)))
        ..insert(const StaticTransform());
      final child = world.spawnChild(root.entity)
        ..insert(Transform2D(translation: Vector2(5, 7)));
      final grandchild = world.spawnChild(child.entity)
        ..insert(Transform2D(translation: Vector2(1, 1)));
      final system = TransformPropagateSystem();
      system.run(world);
      final g = world.get<GlobalTransform2D>(grandchild.entity)!;
      expect((g.matrix.storage[6], g.matrix.storage[7]), (106.0, 58.0));
      for (final e in [root.entity, child.entity, grandchild.entity]) {
        expect(world.has<TransformFrozen>(e), isTrue);
      }
      expect(world.getResource<StaticTransforms>()!.generation, 1);
      // Never visited again: its global keeps the version it was frozen at.
      final version = g.version;
      for (var i = 0; i < 5; i++) {
        system.run(world);
      }
      expect(g.version, version);
      expect(world.getResource<StaticTransforms>()!.generation, 1);
    });

    test('a static root spawned later is computed and frozen too', () {
      final world = World();
      final system = TransformPropagateSystem()..run(world);
      final late = world.spawn()
        ..insert(Transform2D(translation: Vector2(3, 4)))
        ..insert(const StaticTransform());
      system.run(world);
      expect(world.get<GlobalTransform2D>(late.entity)!.matrix.storage[6], 3);
      expect(world.has<TransformFrozen>(late.entity), isTrue);
    });

    test('moving frozen scenery fails the debug check', () {
      final world = World();
      final rock = world.spawn()
        ..insert(Transform2D(translation: Vector2(10, 10)))
        ..insert(const StaticTransform());
      final system = TransformPropagateSystem()..run(world);
      world.get<Transform2D>(rock.entity)!.translation.x = 11;
      expect(() {
        for (var i = 0; i < TransformPropagateSystem.frozenCheckInterval; i++) {
          system.run(world);
        }
      }, throwsStateError);
    });

    test('what moves is still propagated every run', () {
      final world = World();
      final walker = world.spawn()
        ..insert(Transform2D(translation: Vector2(0, 0)));
      final system = TransformPropagateSystem()..run(world);
      world.get<Transform2D>(walker.entity)!.translation.x = 9;
      system.run(world);
      expect(world.get<GlobalTransform2D>(walker.entity)!.matrix.storage[6], 9);
      expect(world.has<TransformFrozen>(walker.entity), isFalse);
    });
  });

  group('extraction', () {
    World scene() => World()
      ..insertResource(
        ActiveCameraView(x: 0, y: 0, zoomFor: (_) => 1)
          ..viewportSize = const Size(400, 300),
      );

    Entity place(World world, double x, double y, {bool frozen = true}) {
      final e = world.spawn()
        ..insert(Sprite(texture: _texture))
        ..insert(Transform2D(translation: Vector2(x, y)));
      if (frozen) e.insert(const StaticTransform());
      return e.entity;
    }

    test('frozen sprites near the view are drawn, far ones are not, and the '
        'result matches a scene with nothing frozen', () {
      List<Entity> build(World world, {required bool frozen}) => [
        place(world, 10, 10, frozen: frozen),
        place(world, -150, 120, frozen: frozen),
        place(world, 5000, 5000, frozen: frozen),
        place(world, -3000, 40, frozen: frozen),
      ];
      final frozenWorld = scene();
      final frozen = build(frozenWorld, frozen: true);
      final plainWorld = scene();
      final plain = build(plainWorld, frozen: false);
      propagateTransforms(frozenWorld);
      propagateTransforms(plainWorld);
      final a = _extracted(frozenWorld, SpriteExtractor());
      final b = _extracted(plainWorld, SpriteExtractor());
      expect(a, {frozen[0], frozen[1]});
      expect(b, {plain[0], plain[1]});
    });

    test('texture and visibility changes on frozen sprites still show; a '
        'despawned one is gone', () {
      final world = scene();
      final a = place(world, 0, 0);
      final b = place(world, 30, 0);
      propagateTransforms(world);
      final extractor = SpriteExtractor();
      expect(_extracted(world, extractor), {a, b});
      world.insert(a, Visibility(false));
      expect(_extracted(world, extractor), {b});
      world.insert(a, Visibility(true));
      world.get<Sprite>(a)!.color = const Color(0x00000000);
      expect(_extracted(world, extractor), {b}, reason: 'transparent');
      world.despawn(b);
      expect(_extracted(world, extractor), isEmpty);
    });

    test('frozen sprites added later (a new map) are found', () {
      final world = scene();
      place(world, 0, 0);
      propagateTransforms(world);
      final extractor = SpriteExtractor();
      expect(_extracted(world, extractor), hasLength(1));
      final later = place(world, 40, 40);
      propagateTransforms(world);
      expect(_extracted(world, extractor), contains(later));
    });
  });
}
