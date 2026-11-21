import 'dart:ui' show Canvas, Color, Rect;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/widgets.dart' show Directionality, TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// Records what a frame drew, in order.
class _Log implements SpriteDrawer {
  final List<String> events = [];

  @override
  void drawSpriteBatch(TextureHandle texture, List<BackendSpriteData> batch) {
    for (final sprite in batch) {
      events.add('sprite ${sprite.color.toARGB32().toRadixString(16)}');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Pass extends ViewPass {
  _Pass(this.log, this.name);

  final _Log log;
  final String name;
  Rect? seen;

  @override
  void paintBehind(World world, Canvas canvas, Rect visibleWorld) =>
      log.events.add('$name behind');

  @override
  void paintOver(World world, Canvas canvas, Rect visibleWorld) {
    seen = visibleWorld;
    log.events.add('$name over');
  }
}

void main() {
  test('RenderPlugin inserts ViewPasses; adding twice keeps one', () {
    final app = App()..addPlugin(RenderPlugin());
    final passes = app.world.getResource<ViewPasses>()!;
    final pass = _Pass(_Log(), 'a');
    passes
      ..add(pass)
      ..add(pass);
    expect(passes.passes, [pass]);
    expect(passes.remove(pass), isTrue);
    expect(passes.passes, isEmpty);
  });

  test('a sprite is emissive only when asked, and extraction keeps it', () {
    expect(Sprite(texture: kSolidColorTexture).emissive, isFalse);
    final world = World();
    world.spawn()
      ..insert(Transform2D.from(0, 0))
      ..insert(GlobalTransform2D.identity())
      ..insert(Sprite(texture: kSolidColorTexture, emissive: true));
    final render = RenderWorld();
    SpriteExtractor().extract(world, render);
    expect(render.extractedSprites.single.emissive, isTrue);
  });

  testWidgets(
    'passes draw behind and over the sprites; emissive sprites come last',
    (tester) async {
      final app = App()..addPlugin(RenderPlugin());
      final log = _Log();
      app.insertResource<SpriteDrawer>(log);
      final a = _Pass(log, 'a');
      app.world.getResource<ViewPasses>()!
        ..add(a)
        ..add(_Pass(log, 'b'));
      final render = app.world.getResource<RenderWorld>()!;
      ExtractedSprite sprite(int color, {bool emissive = false}) =>
          ExtractedSprite(
            entity: Entity.placeholder,
            texture: kSolidColorTexture,
            sourceRect: const Rect.fromLTWH(0, 0, 1, 1),
            transform: Matrix3.identity(),
            color: Color(color),
            sortKey: 0,
            anchor: Vector2(0.5, 0.5),
            size: Vector2(4, 4),
            emissive: emissive,
          );
      render.spawn().insert(sprite(0xff00ff00, emissive: true));
      render.spawn().insert(sprite(0xffff0000));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FledgeRenderView(app: app),
        ),
      );

      expect(log.events, [
        'a behind',
        'b behind',
        'sprite ffff0000',
        'a over',
        'b over',
        'sprite ff00ff00',
      ]);
      expect(a.seen, isNotNull);
    },
  );

  testWidgets('with no passes, emissive sprites draw in their usual place', (
    tester,
  ) async {
    final app = App()..addPlugin(RenderPlugin());
    final log = _Log();
    app.insertResource<SpriteDrawer>(log);
    final render = app.world.getResource<RenderWorld>()!;
    for (final (color, emissive, order) in [
      (0xff00ff00, true, 0),
      (0xffff0000, false, 1),
    ]) {
      render.spawn().insert(
        ExtractedSprite(
          entity: Entity.placeholder,
          texture: kSolidColorTexture,
          sourceRect: const Rect.fromLTWH(0, 0, 1, 1),
          transform: Matrix3.identity(),
          color: Color(color),
          sortKey: order,
          anchor: Vector2(0.5, 0.5),
          size: Vector2(4, 4),
          emissive: emissive,
        ),
      );
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FledgeRenderView(app: app),
      ),
    );
    expect(log.events, ['sprite ff00ff00', 'sprite ffff0000']);
  });
}
