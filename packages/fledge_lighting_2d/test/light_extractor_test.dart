import 'dart:ui' show Color, Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('LightExtractor', () {
    late World mainWorld;
    late RenderWorld renderWorld;

    setUp(() {
      mainWorld = World();
      renderWorld = RenderWorld();
    });

    test('extracts a point light with world-space position', () {
      final light = Light2D.point(
        color: const Color(0xFFFFAA00),
        radius: 150,
        innerRadius: 30,
      );
      final gt = GlobalTransform2D.identity();
      gt.matrix.setValues(1, 0, 0, 0, 1, 0, 120, 240, 1);

      mainWorld.spawn()
        ..insert(Transform2D.from(120, 240))
        ..insert(gt)
        ..insert(light);

      LightExtractor().extract(mainWorld, renderWorld);

      final extracted = <ExtractedLight>[];
      for (final (_, l) in renderWorld.query1<ExtractedLight>().iter()) {
        extracted.add(l);
      }

      expect(extracted, hasLength(1));
      final e = extracted.single;
      expect(e.type, LightType.point);
      expect(e.color, const Color(0xFFFFAA00));
      expect(e.radius, 150);
      expect(e.innerRadius, 30);
      expect(e.position.x, closeTo(120, 1e-9));
      expect(e.position.y, closeTo(240, 1e-9));
    });

    test('culls lights whose pool misses the view, keeps those reaching '
        'into it and directional ones', () {
      // A 400x300 view centred on the origin: x -200..200, y -150..150.
      mainWorld.insertResource(
        ActiveCameraView(x: 0, y: 0, zoomFor: (_) => 1)
          ..viewportSize = const Size(400, 300),
      );
      Entity place(Light2D light, double x, double y) {
        final gt = GlobalTransform2D.identity();
        gt.matrix.setValues(1, 0, 0, 0, 1, 0, x, y, 1);
        return (mainWorld.spawn()
              ..insert(Transform2D.from(x, y))
              ..insert(gt)
              ..insert(light))
            .entity;
      }

      final near = place(
        Light2D.point(color: const Color(0xFFFFFFFF), radius: 20),
        50,
        50,
      );
      // Centre well off screen, but its 400 px pool reaches in.
      final reaching = place(
        Light2D.point(color: const Color(0xFFFFFFFF), radius: 400),
        500,
        0,
      );
      place(
        Light2D.point(color: const Color(0xFFFFFFFF), radius: 50),
        3000,
        3000,
      );
      final sun = place(
        Light2D.directional(
          color: const Color(0xFFFFFFFF),
          direction: Vector2(0, 1),
        ),
        5000,
        5000,
      );
      LightExtractor().extract(mainWorld, renderWorld);
      expect(
        {
          for (final (_, l) in renderWorld.query1<ExtractedLight>().iter())
            l.entity,
        },
        {near, reaching, sun},
      );
    });

    test('skips entities without GlobalTransform2D', () {
      mainWorld.spawn().insert(Light2D.point(color: const Color(0xFFFFFFFF)));

      LightExtractor().extract(mainWorld, renderWorld);

      expect(renderWorld.query1<ExtractedLight>().iter().isEmpty, isTrue);
    });

    test('carries directional light direction through unchanged', () {
      final gt = GlobalTransform2D.identity();
      mainWorld.spawn()
        ..insert(Transform2D.identity())
        ..insert(gt)
        ..insert(
          Light2D.directional(
            color: const Color(0xFFFFFFFF),
            direction: Vector2(3, 4),
          ),
        );

      LightExtractor().extract(mainWorld, renderWorld);

      final extracted = renderWorld
          .query1<ExtractedLight>()
          .iter()
          .map((r) => r.$2)
          .toList();
      expect(extracted, hasLength(1));
      expect(extracted.single.type, LightType.directional);
      expect(extracted.single.direction.length, closeTo(1.0, 1e-6));
    });

    test('re-extracts fresh data after clear (mirrors render loop)', () {
      final gt = GlobalTransform2D.identity();
      final entity = mainWorld.spawn()
        ..insert(Transform2D.identity())
        ..insert(gt)
        ..insert(Light2D.point(color: const Color(0xFFFFFFFF)));

      final extractor = LightExtractor();
      extractor.extract(mainWorld, renderWorld);
      expect(renderWorld.entityCount, 1);

      renderWorld.clear();
      extractor.extract(mainWorld, renderWorld);
      expect(renderWorld.entityCount, 1);

      // Removing the source should stop future extractions.
      mainWorld.despawn(entity.entity);
      renderWorld.clear();
      extractor.extract(mainWorld, renderWorld);
      expect(renderWorld.entityCount, 0);
    });
  });
}
