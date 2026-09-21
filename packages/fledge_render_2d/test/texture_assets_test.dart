import 'dart:ui' show Canvas, Color, PictureRecorder, Rect;

import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Matrix3;

void main() {
  group('RenderPlugin inserts Assets<Texture>', () {
    test('canvas backend attaches Assets<Texture> to the drawer', () {
      final app = App()..addPlugin(RenderPlugin());
      final assets = app.world.getResource<Assets<Texture>>();
      final drawer =
          app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer;

      expect(assets, isNotNull,
          reason: 'RenderPlugin should install an Assets<Texture> resource');
      expect(drawer.assets, same(assets),
          reason: 'drawer must be bound to the same instance');
    });
  });

  group('CanvasSpriteDrawer resolves Handle<Texture>', () {
    test('a Handle<Texture> drives drawSpriteBatch through the atlas path',
        () async {
      // Fresh app; grab the auto-installed pieces.
      final app = App()..addPlugin(RenderPlugin());
      final assets = app.world.getResource<Assets<Texture>>()!;
      final drawer =
          app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer;

      // Mint a real texture through the asset store — 1x1 white,
      // reused by the drawer via `TextureHandle.fromAsset`.
      final image = createSolidColorImageSync(const Color(0xFFFFFFFF));
      final handle = assets.add(Texture(image, 1, 1));
      expect(handle.get(), isNotNull);

      final legacyHandle = TextureHandle.fromAsset(handle, 1, 1);

      // Bind a canvas so drawSpriteBatch actually runs.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      drawer.beginFrame(canvas);
      drawer.drawSpriteBatch(legacyHandle, [
        BackendSpriteData(
          sourceRect: const Rect.fromLTWH(0, 0, 1, 1),
          destRect: const Rect.fromLTRB(-8, -8, 8, 8),
          transform: Matrix3.identity(),
          color: const Color(0xFFFF0000),
        ),
      ]);
      drawer.endFrame();

      // Rasterise to prove Skia was happy with the buffers.
      final picture = recorder.endRecording();
      final rasterised = await picture.toImage(2, 2);
      expect(rasterised.width, 2);

      handle.drop();
      expect(assets.get(handle.id), isNull,
          reason: 'dropping the last handle should evict the entry');
    });

    test('legacy registerTexture still resolves (backwards compatibility)',
        () async {
      final app = App()..addPlugin(RenderPlugin());
      final drawer =
          app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer;

      const legacy = TextureHandle(id: 999, width: 1, height: 1);
      drawer.registerTexture(
          legacy, createSolidColorImageSync(const Color(0xFF00FF00)));

      // resolveImage must return an Image for the legacy handle.
      final image = drawer.resolveImage(legacy);
      expect(image, isNotNull);
    });

    test('Assets<Texture>.add path takes precedence over legacy map',
        () async {
      final app = App()..addPlugin(RenderPlugin());
      final assets = app.world.getResource<Assets<Texture>>()!;
      final drawer =
          app.world.getResource<SpriteDrawer>()! as CanvasSpriteDrawer;

      // Reserve id 42 in the asset store.
      final texture = Texture(
          createSolidColorImageSync(const Color(0xFFAA0000)), 1, 1);
      assets.addWithId(const HandleId(42), texture);

      // The legacy handle for id 42 resolves through Assets<Texture>.
      const legacy = TextureHandle(id: 42, width: 1, height: 1);
      expect(drawer.resolveImage(legacy), same(texture.image));
    });
  });
}
