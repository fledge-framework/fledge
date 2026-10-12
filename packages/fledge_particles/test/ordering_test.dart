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
}
