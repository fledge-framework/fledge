import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_tween/fledge_tween.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. WallTimePlugin is the documented prerequisite.
  for (final schedule in TweenSchedule.values) {
    test('TweenPlugin (${schedule.name}) has no ordering ambiguities', () {
      final app = App()
        ..addPlugin(const WallTimePlugin())
        ..addPlugin(TweenPlugin(schedule: schedule));
      final issues = app.checkScheduleOrdering();
      expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
    });
  }
}
