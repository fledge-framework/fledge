import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order.
  test('CameraPlugin has no ordering ambiguities', () {
    final app = App()
      ..addPlugin(RenderPlugin())
      ..addPlugin(const CameraPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  for (final (label, schedule) in [
    ('preUpdate', Schedules.preUpdate),
    ('postUpdate', Schedules.postUpdate),
  ]) {
    test('CameraPlugin + TransformPropagateSystem in $label has no '
        'ordering ambiguities', () {
      final app = App()
        ..addPlugin(const WallTimePlugin())
        ..addPlugin(RenderPlugin())
        ..addPlugin(const CameraPlugin())
        ..addSystem(TransformPropagateSystem(), schedule: schedule);
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }
}
