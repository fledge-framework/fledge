import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_lighting_2d/fledge_lighting_2d.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. LightingPlugin adds no systems of its own
  // today; this guards against one being added without ordering.
  test('LightingPlugin has no ordering ambiguities', () {
    final app = App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(RenderPlugin())
      ..addPlugin(const LightingPlugin(ambient: AmbientLight.dark))
      ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });
}
