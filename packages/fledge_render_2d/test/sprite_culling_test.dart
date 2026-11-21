import 'dart:ui' show Canvas, Offset, PictureRecorder, Rect, Size;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

const _texture = TextureHandle(id: 1, width: 16, height: 16);

World _world(List<(double, double)> at) {
  final world = World();
  for (final (x, y) in at) {
    world.spawn()
      ..insert(Sprite(texture: _texture))
      ..insert(
        GlobalTransform2D()..matrix.setValues(1, 0, 0, 0, 1, 0, x, y, 1),
      );
  }
  return world;
}

int _extracted(World world) {
  final renderWorld = RenderWorld();
  SpriteExtractor().extract(world, renderWorld);
  return renderWorld.extractedSpriteCount;
}

void main() {
  test('the view is centred on the camera and sized by the zoom', () {
    final view = ActiveCameraView(x: 100, y: 50, zoomFor: (_) => 2)
      ..viewportSize = const Size(400, 300);
    expect(
      view.visibleWorldRect,
      Rect.fromCenter(center: const Offset(100, 50), width: 200, height: 150),
    );
    expect(ActiveCameraView().visibleWorldRect, isNull);
  });

  test('drawing through the camera records the widget size', () {
    final world = World()..insertResource(ActiveCameraView());
    withActiveCameraCanvas(
      world,
      Canvas(PictureRecorder()),
      const Size(640, 360),
      () {},
    );
    expect(
      world.getResource<ActiveCameraView>()!.viewportSize,
      const Size(640, 360),
    );
  });

  test('sprites far off screen are skipped, and near ones kept', () {
    final world = _world([(0, 0), (150, 0), (5000, 0), (0, -5000)])
      ..insertResource(ActiveCameraView()..viewportSize = const Size(200, 200));
    // (150, 0) is outside the view but within the margin.
    expect(_extracted(world), 2);
  });

  test('with no known view, nothing is skipped', () {
    final world = _world([(0, 0), (5000, 0)]);
    expect(_extracted(world), 2);
  });
}
