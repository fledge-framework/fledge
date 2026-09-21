import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  App buildApp({DebugConfig config = const DebugConfig()}) {
    return App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(RenderPlugin())
      ..addPlugin(const CameraPlugin())
      ..addPlugin(const UiPlugin())
      ..addPlugin(DebugPlugin(config: config));
  }

  List<String> overlayTexts(App app) {
    final out = <String>[];
    for (final (entity, _) in app.world.query1<DebugOverlayEntity>().iter()) {
      final text = app.world.get<UiText>(entity);
      if (text != null) out.add(text.text);
    }
    return out;
  }

  testWidgets('DebugPlugin emits FPS and entity-count lines', (tester) async {
    final app = buildApp();
    // Two ticks so FrameStatsSystem has a real delta to consume from
    // WallTime.
    await app.tick();
    await tester.pump(const Duration(milliseconds: 20));
    await app.tick();

    final lines = overlayTexts(app);
    expect(lines.any((l) => l.startsWith('FPS: ')), isTrue,
        reason: 'FPS line missing: $lines');
    expect(lines.any((l) => l.startsWith('Entities: ')), isTrue,
        reason: 'Entity-count line missing: $lines');
  });

  testWidgets('overlay reuses UI entities across ticks (retained mode)',
      (tester) async {
    final app = buildApp();
    await app.tick();
    final firstIds = <Entity>{
      for (final (entity, _) in app.world.query1<DebugOverlayEntity>().iter())
        entity,
    };
    await tester.pump(const Duration(milliseconds: 20));
    await app.tick();
    final secondIds = <Entity>{
      for (final (entity, _) in app.world.query1<DebugOverlayEntity>().iter())
        entity,
    };
    expect(secondIds, equals(firstIds),
        reason: 'Overlay entities were despawned/respawned between ticks');
  });

  testWidgets('toggling showFps despawns the FPS line', (tester) async {
    final app = buildApp();
    await app.tick();
    expect(overlayTexts(app).any((l) => l.startsWith('FPS: ')), isTrue);

    // Turn FPS off — the next tick should drop that line and keep the
    // other lines untouched.
    app.insertResource(
      app.world.getResource<DebugConfig>()!.copyWith(showFps: false),
    );
    await app.tick();

    final texts = overlayTexts(app);
    expect(texts.any((l) => l.startsWith('FPS: ')), isFalse,
        reason: 'FPS line lingered after toggle: $texts');
    expect(texts.any((l) => l.startsWith('Entities: ')), isTrue);
  });

  testWidgets('checkScheduleOrdering ambiguities show on the overlay',
      (tester) async {
    // Two systems in the same schedule that write the same resource
    // with no ordering declared — the classic ambiguity pattern.
    final app = buildApp();
    app.addSystem(_TouchResourceSystemA(), schedule: Schedules.update);
    app.addSystem(_TouchResourceSystemB(), schedule: Schedules.update);
    refreshAmbiguityReport(app);
    await app.tick();

    final texts = overlayTexts(app);
    expect(texts.any((l) => l.startsWith('Ambiguities: ')), isTrue,
        reason: 'Ambiguity block missing: $texts');
  });
}

class _SharedResource {
  int value = 0;
}

class _TouchResourceSystemA implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'touch_a',
        resourceWrites: {_SharedResource},
      );
  @override
  RunCondition? get runCondition => null;
  @override
  bool shouldRun(World world) => true;
  @override
  Future<void> run(World world) => Future.value();
}

class _TouchResourceSystemB implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'touch_b',
        resourceWrites: {_SharedResource},
      );
  @override
  RunCondition? get runCondition => null;
  @override
  bool shouldRun(World world) => true;
  @override
  Future<void> run(World world) => Future.value();
}
