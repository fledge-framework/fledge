import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('UiPlugin end-to-end: spawn text, tick, paint FledgeUiOverlay',
      (tester) async {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const CameraPlugin())
      ..addPlugin(const UiPlugin());

    // Match the widget size we're about to pump so the viewport
    // resource lines up with the layout pass.
    app.world.getResource<ViewportSize>()!.update(400, 300);

    // Spawn a HUD entity in the top-left.
    app.world.spawn()
      ..insert(const UiNode())
      ..insert(const UiAnchorComponent(UiAnchor.topLeft))
      ..insert(const UiOffset(x: 8, y: 8))
      ..insert(const UiSize(width: 120, height: 24))
      ..insert(UiText(text: 'Score: 0', fontSize: 16));

    await app.tick();

    // The extractor should have populated the render world.
    final renderWorld = app.world.getResource<RenderWorld>()!;
    final extracted =
        renderWorld.query1<ExtractedUiText>().iter().map((r) => r.$2).toList();
    expect(extracted, hasLength(1));
    expect(extracted.single.text, 'Score: 0');

    // Painting the overlay should not throw even without a real
    // texture backend behind it.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 300,
          child: FledgeUiOverlay(
            app: app,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FledgeUiOverlay), findsOneWidget);
  });

  testWidgets('score-style updates are reflected across ticks', (tester) async {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const CameraPlugin())
      ..addPlugin(const UiPlugin());
    app.world.getResource<ViewportSize>()!.update(200, 200);

    final entity = (app.world.spawn()
          ..insert(const UiNode())
          ..insert(const UiAnchorComponent(UiAnchor.topLeft))
          ..insert(const UiSize(width: 80, height: 20))
          ..insert(UiText(text: 'Score: 0')))
        .entity;

    await app.tick();

    // Mutating the same UiText field should surface on the next
    // tick without spawning a new entity — that's the retained-mode
    // contract for HUD updates.
    app.world.get<UiText>(entity)!.text = 'Score: 7';
    await app.tick();

    final renderWorld = app.world.getResource<RenderWorld>()!;
    final result = renderWorld.query1<ExtractedUiText>().iter().single.$2;
    expect(result.text, 'Score: 7');
  });

  test('UiPlugin without RenderPlugin fails loudly', () {
    final app = App();
    expect(() => app.addPlugin(const UiPlugin()), throwsStateError);
  });
}
