import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FrameStats.history lists the window oldest first, read-only', () {
    final stats = FrameStats(historyCap: 3)
      ..recordFrame(0.01)
      ..recordFrame(0.02)
      ..recordFrame(0.03)
      ..recordFrame(0.04);
    expect(stats.history, [0.02, 0.03, 0.04]);
    expect(() => stats.history.add(1), throwsUnsupportedError);
  });

  testWidgets('the panel shows FPS, frame times, tick and counts', (
    tester,
  ) async {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const DebugStatsPlugin());
    final frames = app.world.getResource<FrameStats>()!;
    for (var i = 0; i < 10; i++) {
      frames.recordFrame(1 / 60);
    }
    app.world.getResource<SystemStats>()!
      ..frameStartMicros = 1000
      ..frameEndMicros = 3500;
    app.world.spawn();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: DebugPerfPanel(app: app),
        ),
      ),
    );

    expect(find.text('FPS 60'), findsOneWidget);
    expect(find.textContaining('frame 16.7 ms'), findsOneWidget);
    expect(find.text('tick 2.5 ms'), findsOneWidget);
    expect(find.textContaining('sprites 0'), findsOneWidget);

    // Text refreshes on its interval, not every frame.
    frames.reset();
    for (var i = 0; i < 10; i++) {
      frames.recordFrame(1 / 30);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('FPS 60'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FPS 30'), findsOneWidget);

    // Disposing removes the ticker and the timings callback cleanly.
    await tester.pumpWidget(const SizedBox());
  });
}
