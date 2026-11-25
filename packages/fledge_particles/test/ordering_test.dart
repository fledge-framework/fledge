import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_particles/fledge_particles.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order.
  test('ParticlePlugin has no ordering ambiguities', () {
    final app = App()..addPlugin(const ParticlePlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('RenderPlugin + ParticlePlugin + TransformPropagateSystem has no '
      'ordering ambiguities', () {
    final app = App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(RenderPlugin())
      ..addPlugin(const ParticlePlugin())
      ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('ParticlePlugin before RenderPlugin has no ordering ambiguities', () {
    final app = App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(const ParticlePlugin())
      ..addPlugin(RenderPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  group('extractor registration', () {
    int particleExtractors(App app) => app.world
        .getResource<Extractors>()!
        .all
        .whereType<ParticleExtractor>()
        .length;

    test('after RenderPlugin, registers at build', () {
      final app = App()
        ..addPlugin(RenderPlugin())
        ..addPlugin(const ParticlePlugin());
      expect(particleExtractors(app), 1);
    });

    test('before RenderPlugin, registers on the first tick', () async {
      final app = App()
        ..addPlugin(const ParticlePlugin())
        ..addPlugin(RenderPlugin());
      await app.tick();
      expect(particleExtractors(app), 1);
      await app.tick();
      expect(particleExtractors(app), 1);
    });

    test('without RenderPlugin, ticks headless', () async {
      final app = App()..addPlugin(const ParticlePlugin());
      await app.tick();
      expect(app.world.getResource<Extractors>(), isNull);
    });
  });
}
