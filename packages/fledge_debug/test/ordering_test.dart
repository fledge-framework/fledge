import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter_test/flutter_test.dart';

App _baseApp(PhysicsConfig physics) => App()
  ..addPlugin(const WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addPlugin(PhysicsPlugin(config: physics))
  ..addPlugin(const UiPlugin());

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. The debug plugins are composed the way
  // examples/drifter does it, with the plugins they order against.
  for (final (label, physics) in [
    ('variable physics', const PhysicsConfig()),
    ('fixed physics', const PhysicsConfig(mode: PhysicsMode.fixed)),
  ]) {
    for (final (pluginLabel, plugin) in <(String, Plugin)>[
      ('DebugPlugin', const DebugPlugin()),
      ('DebugPlugin(overlay: false)', const DebugPlugin(overlay: false)),
      ('DebugStatsPlugin', const DebugStatsPlugin()),
    ]) {
      test('$pluginLabel ($label) has no ordering ambiguities', () {
        final app = _baseApp(physics)..addPlugin(plugin);
        final issues = app.checkScheduleOrdering();
        expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
      });
    }
  }

  for (final (label, plugin) in <(String, Plugin)>[
    ('DebugPlugin', const DebugPlugin()),
    ('DebugStatsPlugin', const DebugStatsPlugin()),
  ]) {
    test('$label alone has no ordering ambiguities', () {
      final app = App()..addPlugin(plugin);
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }

  test('first-schedule debug systems join FirstSets.frameStart', () {
    final scheduler = Scheduler();
    final metas = [
      const FrameStatsSystem().meta,
      SystemStatsStartSystem(scheduler).meta,
      ScheduleOrderingReportSystem(scheduler).meta,
    ];
    for (final meta in metas) {
      expect(meta.sets, [FirstSets.frameStart], reason: meta.name);
      // Phases order them against window / audio / tilemap systems; no
      // string-literal references to other packages' systems remain.
      expect(meta.after, [WallTimeUpdateSystem.systemName], reason: meta.name);
      expect(meta.before, isEmpty, reason: meta.name);
    }
    // The end-of-frame stats system lives in Schedules.last.
    expect(const SystemStatsEndSystem().meta.sets, isEmpty);
  });
}
