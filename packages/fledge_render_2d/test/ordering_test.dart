import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order.
  test('RenderPlugin has no ordering ambiguities', () {
    final app = App()..addPlugin(RenderPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('RenderPlugin + standalone render_2d systems in their documented '
      'schedules have no ordering ambiguities', () {
    final app = App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(RenderPlugin())
      ..addSystem(
        const SnapshotPreviousTransformSystem(),
        schedule: Schedules.fixedFirst,
      )
      ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate)
      ..addSystem(AnimateSystemWithResource(), schedule: Schedules.update)
      ..addSystem(const TransitionFadeSystem(), schedule: Schedules.update);
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });
}
