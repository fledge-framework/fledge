import 'dart:ui' show Canvas, Color, Image, Paint, PictureRecorder, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

Future<Image> rasterise(void Function(Canvas canvas) paint, int size) async {
  final recorder = PictureRecorder();
  paint(Canvas(recorder));
  return recorder.endRecording().toImage(size, size);
}

Future<(int, int, int)> rgbAt(Image image, int x, int y) async {
  final bytes = (await image.toByteData())!;
  final o = (y * image.width + x) * 4;
  return (bytes.getUint8(o), bytes.getUint8(o + 1), bytes.getUint8(o + 2));
}

ExtractedLight light({
  required double x,
  required double y,
  Color color = const Color(0xFFFFFFFF),
  double radius = 16,
  double innerRadius = 8,
  int bands = 0,
  double glow = 0,
}) => ExtractedLight(
  entity: Entity.placeholder,
  type: LightType.point,
  position: Vector2(x, y),
  color: color,
  intensity: 1,
  radius: radius,
  innerRadius: innerRadius,
  bands: bands,
  glow: glow,
  angle: 0,
  direction: Vector2(0, -1),
);

void main() {
  const area = Rect.fromLTWH(0, 0, 64, 64);

  test(
    'a light map reveals the true colour under a lamp, dark elsewhere',
    () async {
      final render = RenderWorld()..spawn().insert(light(x: 16, y: 16));
      final image = await rasterise((canvas) {
        // An orange "sprite" everywhere.
        canvas.drawRect(area, Paint()..color = const Color(0xFFE08040));
        renderLightMap(render, canvas, area, const Color(0xFF101830));
      }, 64);
      // Under the lamp: the sprite's own colour, not washed toward white.
      expect(await rgbAt(image, 16, 16), (0xE0, 0x80, 0x40));
      // Far from it: the sprite times the night ambient.
      final (r, g, b) = await rgbAt(image, 56, 56);
      expect(r, lessThan(0x20));
      expect(g, lessThan(0x10));
      expect(b, lessThan(0x10));
    },
  );

  test('a light map never brightens past what is drawn', () async {
    final render = RenderWorld()
      ..spawn().insert(light(x: 16, y: 16))
      ..spawn().insert(light(x: 18, y: 16));
    final image = await rasterise((canvas) {
      canvas.drawRect(area, Paint()..color = const Color(0xFF406080));
      renderLightMap(render, canvas, area, const Color(0xFF000000));
    }, 64);
    expect(await rgbAt(image, 17, 16), (0x40, 0x60, 0x80));
  });

  test('an aspect below 1 squashes the pool into a ground ellipse', () async {
    final render = RenderWorld()
      ..spawn().insert(
        ExtractedLight(
          entity: Entity.placeholder,
          type: LightType.point,
          position: Vector2(32, 32),
          color: const Color(0xFFFFFFFF),
          intensity: 1,
          radius: 24,
          innerRadius: 20,
          aspect: 0.5,
          angle: 0,
          direction: Vector2(0, -1),
        ),
      );
    final image = await rasterise((canvas) {
      canvas.drawRect(area, Paint()..color = const Color(0xFFFFFFFF));
      renderLightMap(render, canvas, area, const Color(0xFF000000));
    }, 64);
    // As wide as the radius, but only half as tall.
    expect(await rgbAt(image, 32 + 18, 32), (0xFF, 0xFF, 0xFF));
    expect(await rgbAt(image, 32, 32 + 18), (0, 0, 0));
  });

  test('bounds limit the darkening to a world rect', () async {
    final image = await rasterise((canvas) {
      canvas.drawRect(area, Paint()..color = const Color(0xFFFFFFFF));
      renderLightMap(
        RenderWorld(),
        canvas,
        area,
        const Color(0xFF000000),
        bounds: const Rect.fromLTWH(0, 0, 32, 64),
      );
    }, 64);
    expect(await rgbAt(image, 8, 8), (0, 0, 0));
    expect(await rgbAt(image, 48, 8), (0xFF, 0xFF, 0xFF));
  });

  group('falloff', () {
    void strictlyRising(List<double> stops) {
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i], greaterThan(stops[i - 1]), reason: 'stop $i');
      }
    }

    test('smooth: full to the inner radius, then fading to nothing', () {
      final (colors, stops) = falloffStops(const Color(0xFFFFFFFF), 0.25, 0);
      strictlyRising(stops);
      expect(stops.first, 0);
      expect(stops.last, 1);
      expect(colors[1].a, 1);
      expect(stops[1], 0.25);
      for (var i = 2; i < colors.length; i++) {
        expect(colors[i].a, lessThanOrEqualTo(colors[i - 1].a));
      }
      expect(colors.last.a, 0);
      // A soft tail: the last sample before the edge is already faint.
      expect(colors[colors.length - 2].a, lessThan(0.05));
    });

    test('bands: flat rings, never a repeated stop', () {
      final (colors, stops) = falloffStops(const Color(0xFFFFFFFF), 0.5, 2);
      strictlyRising(stops);
      expect(colors[2].a, colors[3].a, reason: 'a ring is flat');
      expect(colors[4].a, lessThan(colors[2].a));
      expect(colors.last.a, 0);
    });
  });

  test('nothing past the edge of a light is lit', () async {
    final render = RenderWorld()
      ..spawn().insert(light(x: 32, y: 32, radius: 20, innerRadius: 0))
      ..spawn().insert(light(x: 32, y: 32, radius: 20, bands: 4));
    final image = await rasterise((canvas) {
      canvas.drawRect(area, Paint()..color = const Color(0xFFFFFFFF));
      renderLightMap(render, canvas, area, const Color(0xFF000000));
    }, 64);
    // Inside the light's bounding square, outside its circle: dark.
    expect(await rgbAt(image, 32 + 17, 32 + 17), (0, 0, 0));
    expect(await rgbAt(image, 32 + 19, 32 - 19), (0, 0, 0));
  });

  test('a glow adds light around a bright source', () async {
    final render = RenderWorld()
      ..spawn().insert(light(x: 32, y: 32, radius: 32, glow: 0.5));
    final image = await rasterise((canvas) {
      canvas.drawRect(area, Paint()..color = const Color(0xFF202020));
      renderLightGlows(render, canvas, area);
    }, 64);
    final (r, _, _) = await rgbAt(image, 32, 32);
    expect(r, greaterThan(0x60));
    expect(await rgbAt(image, 2, 2), (0x20, 0x20, 0x20));
  });

  testWidgets('LightingPlugin lights a plain FledgeRenderView', (tester) async {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(
        const LightingPlugin(
          ambient: AmbientLight(
            color: Color(0xFF000000),
            intensity: 1,
            blend: AmbientBlend.lightMap,
          ),
        ),
      );
    expect(
      app.world.getResource<ViewPasses>()!.passes.single,
      isA<LightingViewPass>(),
    );
  });
}
