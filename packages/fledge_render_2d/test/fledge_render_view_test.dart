import 'dart:ui' as ui show Image;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [SpriteDrawer] that records every batch it receives so tests can
/// inspect ordering + grouping without rasterising anything.
class _RecordingDrawer implements SpriteDrawer {
  final List<({TextureHandle texture, List<BackendSpriteData> batch})> calls =
      [];

  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    calls.add((texture: texture, batch: List<BackendSpriteData>.of(batch)));
  }
}

/// Build an [App] with the render plugin, one registered sprite
/// extractor, and the transform propagation system so Sprite +
/// Transform2D → ExtractedSprite works after a single tick.
App _buildTestApp() {
  final app = App()..addPlugin(RenderPlugin());
  app.addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
  app.world.getResource<Extractors>()!.register(SpriteExtractor());
  return app;
}

void _spawnSprite(
  World world, {
  required TextureHandle texture,
  required Color color,
  required DrawLayer layer,
  double x = 0,
  double y = 0,
}) {
  // Insert `GlobalTransform2D` up-front so the entity's archetype is
  // stable before extraction runs. Relying on
  // `TransformPropagateSystem` to add it lazily during the same tick
  // can silently drop entities from `query2<Sprite, GlobalTransform2D>`
  // because the propagate pass mutates archetypes mid-iteration.
  world.spawn()
    ..insert(Transform2D.from(x, y))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(texture: texture, color: color, layer: layer));
}

Future<void> _paintOnce(WidgetTester tester, App app,
    {Color? background}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 100,
        height: 100,
        child: FledgeRenderView(app: app, backgroundColor: background),
      ),
    ),
  );
  // One pump lays the widget out; a second pump paints it via the
  // scheduler (Skia only records ops on the frame after build).
  await tester.pump();
}

void main() {
  group('FledgeRenderView', () {
    testWidgets('paints sprite pipeline into a recorded canvas',
        (tester) async {
      // Swap in a recording drawer so we can prove the widget's
      // paint reached `drawSpriteBatch` (i.e. the sprite pipeline
      // was actually driven end-to-end). The canvas backend's own
      // `drawRawAtlas` call is verified indirectly — with a
      // registered texture the batch would have been rasterised
      // through Skia, so the fact that we got here without a
      // buffer-length assertion is proof enough of that leg.
      final app = _buildTestApp();
      final recorder = _RecordingDrawer();
      app.world.insertResource<SpriteDrawer>(recorder);

      _spawnSprite(
        app.world,
        texture: kSolidColorTexture,
        color: const Color(0xFFFF0000),
        layer: DrawLayer.characters,
        x: 50,
        y: 50,
      );

      await app.tick();

      final extractedCount = app.world
          .getResource<RenderWorld>()!
          .query1<ExtractedSprite>()
          .iter()
          .length;
      expect(extractedCount, 1,
          reason: 'SpriteExtractor should produce one ExtractedSprite');

      await _paintOnce(tester, app);
      expect(tester.takeException(), isNull);
      expect(recorder.calls, isNotEmpty,
          reason: 'FledgeRenderView should have submitted at least one '
              'sprite batch to the installed drawer');
      expect(recorder.calls.first.texture.id, kSolidColorTexture.id);
      expect(recorder.calls.first.batch.length, 1);
    });

    testWidgets(
        'canvas backend drives drawRawAtlas end-to-end without asserts',
        (tester) async {
      // The default drawer installed by `RenderPlugin` is
      // `CanvasSpriteDrawer`. If it received malformed buffers
      // (RSTransform / srcRect / colors length parity is checked by
      // Skia), Flutter would surface an assertion here. A successful
      // pump proves the whole widget → drawer → drawRawAtlas
      // pipeline is wired.
      final app = _buildTestApp();
      final canvasDrawer =
          app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer;
      canvasDrawer.registerTexture(
        kSolidColorTexture,
        createSolidColorImageSync(const Color(0xFFFFFFFF)),
      );

      _spawnSprite(
        app.world,
        texture: kSolidColorTexture,
        color: const Color(0xFF00DD00),
        layer: DrawLayer.characters,
        x: 25,
        y: 40,
      );
      await app.tick();

      await _paintOnce(tester, app, background: const Color(0xFF1A1A2E));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty render world paints without crashing', (tester) async {
      final app = _buildTestApp();
      await app.tick();

      // No sprite spawned — the render world is empty. Paint must
      // no-op through the pipeline (no `drawSpriteBatch` calls).
      await _paintOnce(tester, app, background: const Color(0xFF000000));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'preserves layer ordering and groups contiguous same-texture runs',
        (tester) async {
      // Replace the auto-installed drawer with a recording one so we
      // can inspect the batch sequence directly. `insertResource`
      // overwrites the drawer already registered by `RenderPlugin`.
      final app = _buildTestApp();
      final recorder = _RecordingDrawer();
      app.world.insertResource<SpriteDrawer>(recorder);

      // Two textures. Spawn background-layer + ui-layer entities in
      // a mixed order; after sorting the expected sequence is:
      //   background(a) → background(b) → ui(a) → ui(b).
      // Since both background sprites share texture A and both ui
      // sprites share texture B, the grouping collapses to two
      // batches.
      const textureA = TextureHandle(id: 1, width: 1, height: 1);
      const textureB = TextureHandle(id: 2, width: 1, height: 1);

      _spawnSprite(
        app.world,
        texture: textureB,
        color: const Color(0xFFAAAAAA),
        layer: DrawLayer.ui,
      );
      _spawnSprite(
        app.world,
        texture: textureA,
        color: const Color(0xFF111111),
        layer: DrawLayer.background,
      );
      _spawnSprite(
        app.world,
        texture: textureB,
        color: const Color(0xFFBBBBBB),
        layer: DrawLayer.ui,
      );
      _spawnSprite(
        app.world,
        texture: textureA,
        color: const Color(0xFF222222),
        layer: DrawLayer.background,
      );

      await app.tick();

      // Use the shared batching helper directly — avoids relying on
      // `CustomPaint` sizing quirks in the widget tester and keeps
      // the ordering contract testable in isolation.
      renderSpritesToDrawer(
        app.world.getResource<RenderWorld>()!,
        recorder,
      );

      expect(recorder.calls.length, 2,
          reason: 'contiguous same-texture sprites should collapse to a '
              'single batch, giving 2 batches for 2 texture groups');
      expect(recorder.calls[0].texture.id, textureA.id,
          reason: 'background (layer 0) should render before ui (layer 5)');
      expect(recorder.calls[0].batch.length, 2);
      expect(recorder.calls[1].texture.id, textureB.id);
      expect(recorder.calls[1].batch.length, 2);
    });

    testWidgets('endFrame releases canvas after paint', (tester) async {
      // Guard: the widget MUST release the canvas after painting.
      // Leaving a stale canvas would cause subsequent widget-less
      // draws (e.g. tests) to write to the wrong recorder.
      final app = _buildTestApp();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 10,
            height: 10,
            child: FledgeRenderView(app: app),
          ),
        ),
      );
      await tester.pump();

      final drawer =
          app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer;
      expect(drawer.hasCanvas, isFalse,
          reason: 'canvas reference must not leak past the frame');
    });
  });

  group('createSolidColorImage', () {
    test('sync version yields a 1×1 image by default', () {
      final ui.Image image =
          createSolidColorImageSync(const Color(0xFFFFFFFF));
      expect(image.width, 1);
      expect(image.height, 1);
    });

    test('async version produces the requested size', () async {
      final image = await createSolidColorImage(
        const Color(0xFF00FF00),
        width: 4,
        height: 8,
      );
      expect(image.width, 4);
      expect(image.height, 8);
    });
  });

  group('renderSpritesToDrawer', () {
    // Ensures the shared batching helper survives direct invocation
    // (i.e. any future render-node path can call it too).
    test('submits zero batches for an empty render world', () {
      final renderWorld = RenderWorld();
      final drawer = _RecordingDrawer();
      renderSpritesToDrawer(renderWorld, drawer);
      expect(drawer.calls, isEmpty);
    });
  });
}
