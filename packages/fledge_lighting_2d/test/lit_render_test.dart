import 'dart:ui' show Color, PictureRecorder;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/rendering.dart' show Canvas, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('LitFledgeRenderView + LightingPlugin', () {
    test('LightingPlugin registers an extractor and inserts ambient', () {
      final app = App();
      app.addPlugin(RenderPlugin());
      app.addPlugin(const LightingPlugin(ambient: AmbientLight.dark));

      final ambient = app.world.getResource<AmbientLight>()!;
      expect(ambient.intensity, AmbientLight.dark.intensity);
      expect(ambient.color, AmbientLight.dark.color);

      // A LightExtractor should now be on the shared registry.
      final extractors = app.world.getResource<Extractors>()!;
      expect(extractors.all.whereType<LightExtractor>().length, 1);
    });

    test(
      'renderLightsToCanvas over a populated render world does not crash',
      () async {
        final app = App();
        app.addPlugin(RenderPlugin());
        app.addPlugin(const LightingPlugin());

        // Spawn a sprite with a solid-colour texture (matches the shape of
        // the Drifter example) so the sprite pass has real data too.
        final gt = GlobalTransform2D.identity();
        gt.matrix.setValues(1, 0, 0, 0, 1, 0, 64, 64, 1);
        app.world.spawn()
          ..insert(Transform2D.from(64, 64))
          ..insert(gt)
          ..insert(
            Sprite(
              texture: kSolidColorTexture,
              customSize: Vector2(32, 32),
              color: const Color(0xFFFF0000),
            ),
          );

        // Point light co-located with the sprite.
        final lightGt = GlobalTransform2D.identity();
        lightGt.matrix.setValues(1, 0, 0, 0, 1, 0, 64, 64, 1);
        app.world.spawn()
          ..insert(Transform2D.from(64, 64))
          ..insert(lightGt)
          ..insert(
            Light2D.point(
              color: const Color(0xFFFFDD88),
              radius: 128,
              innerRadius: 24,
            ),
          );

        // Directional light — tints the whole viewport.
        final dirGt = GlobalTransform2D.identity();
        app.world.spawn()
          ..insert(Transform2D.identity())
          ..insert(dirGt)
          ..insert(
            Light2D.directional(
              color: const Color(0xFF3355FF),
              direction: Vector2(1, 0),
              intensity: 0.3,
            ),
          );

        // Spot light — exercises the wedge-clip path.
        final spotGt = GlobalTransform2D.identity();
        spotGt.matrix.setValues(1, 0, 0, 0, 1, 0, 128, 128, 1);
        app.world.spawn()
          ..insert(Transform2D.from(128, 128))
          ..insert(spotGt)
          ..insert(
            Light2D.spot(
              color: const Color(0xFFFFFFFF),
              direction: Vector2(0, 1),
              angle: 0.4,
              radius: 100,
            ),
          );

        // Drive extraction so the render world holds ExtractedLight /
        // ExtractedSprite entities. Register a SpriteExtractor manually —
        // the RenderPlugin doesn't add it (that's the callers' job).
        app.world.getResource<Extractors>()!.register(SpriteExtractor());
        await RenderExtractionSystem().run(app.world);

        final renderWorld = app.world.getResource<RenderWorld>()!;
        expect(renderWorld.query1<ExtractedLight>().iter().length, 3);

        // Paint into an offscreen picture recorder — this is the whole
        // point of the widget's paint loop; if it throws or asserts
        // we've broken something.
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(256, 256);
        renderLightsToCanvas(renderWorld, canvas, size);
        final picture = recorder.endRecording();
        picture.dispose();
      },
    );

    test('renderLightsToCanvas is a no-op on an empty render world', () {
      final renderWorld = RenderWorld();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      renderLightsToCanvas(renderWorld, canvas, const Size(64, 64));
      recorder.endRecording().dispose();
    });
  });
}
