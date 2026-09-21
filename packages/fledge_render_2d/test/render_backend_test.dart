import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RenderPlugin backend selection', () {
    test('defaults to canvas backend', () {
      final app = App()..addPlugin(RenderPlugin());
      final res = app.world.getResource<RenderBackendResource>();
      expect(res, isNotNull);
      expect(res!.backend, equals(RenderBackend.canvas));
    });

    test('canvas backend inserts RenderBackendResource(canvas)', () {
      final app = App()..addPlugin(RenderPlugin(backend: RenderBackend.canvas));
      final res = app.world.getResource<RenderBackendResource>();
      expect(res, isNotNull);
      expect(res!.backend, equals(RenderBackend.canvas));
    });

    test('gpu backend inserts RenderBackendResource(gpu)', () {
      final app = App()..addPlugin(RenderPlugin(backend: RenderBackend.gpu));
      final res = app.world.getResource<RenderBackendResource>();
      expect(res, isNotNull);
      expect(res!.backend, equals(RenderBackend.gpu));
    });
  });

  group('RenderPlugin drawer wiring', () {
    test('canvas backend installs CanvasSpriteDrawer', () {
      final app = App()..addPlugin(RenderPlugin(backend: RenderBackend.canvas));

      final drawer = app.world.getResource<SpriteDrawer>();
      expect(drawer, isNotNull);
      expect(drawer, isA<CanvasSpriteDrawer>());
    });

    test('gpu backend installs GpuSpriteDrawer', () {
      final app = App()..addPlugin(RenderPlugin(backend: RenderBackend.gpu));

      final drawer = app.world.getResource<SpriteDrawer>();
      expect(drawer, isNotNull);
      expect(drawer, isA<GpuSpriteDrawer>());
    });

    test('default backend installs CanvasSpriteDrawer', () {
      final app = App()..addPlugin(RenderPlugin());

      final drawer = app.world.getResource<SpriteDrawer>();
      expect(drawer, isA<CanvasSpriteDrawer>());
    });

    test('gpu drawer throws UnimplementedError on drawSpriteBatch', () {
      final app = App()..addPlugin(RenderPlugin(backend: RenderBackend.gpu));

      final drawer = app.world.getResource<SpriteDrawer>()!;
      expect(
        () => drawer.drawSpriteBatch(
          const TextureHandle(id: 1, width: 32, height: 32),
          const [],
        ),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
