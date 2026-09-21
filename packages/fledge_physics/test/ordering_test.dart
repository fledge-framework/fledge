import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Self-check for `PhysicsPlugin`: a bare `App` with only physics
/// installed should have zero ordering ambiguities. If a future refactor
/// adds a system to the plugin without declaring `before:` / `after:`
/// against its siblings, this test breaks and points at the exact pair.
void main() {
  test('PhysicsPlugin has no ordering ambiguities on its own', () {
    final app = App()..addPlugin(const PhysicsPlugin());
    final issues = app.checkScheduleOrdering();
    expect(
      issues,
      isEmpty,
      reason: 'PhysicsPlugin should declare explicit ordering between all '
          'systems it registers. Ambiguities: ${issues.map((i) => i.toString()).join('\n')}',
    );
  });

  test('PhysicsPlugin without resolution has no ambiguities either', () {
    final app = App()
      ..addPlugin(const PhysicsPlugin(
        config: PhysicsConfig(enableResolution: false),
      ));
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty);
  });
}
