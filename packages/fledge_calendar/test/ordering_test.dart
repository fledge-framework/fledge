import 'package:fledge_calendar/fledge_calendar.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

void main() {
  // Every system's order must be declared, not inherited from
  // registration order. CalendarSystem reads WallTime in
  // `Schedules.first`, so WallTimePlugin (its prerequisite) is included.
  test('CalendarPlugin has no ordering ambiguities', () {
    final app = App()
      ..addPlugin(const WallTimePlugin())
      ..addPlugin(const CalendarPlugin());
    final issues = app.checkScheduleOrdering();
    expect(issues, isEmpty, reason: issues.map((i) => ' - $i').join('\n'));
  });

  test('CalendarSystem joins FirstSets.frameStart after wall time', () {
    final meta = const CalendarSystem().meta;
    expect(meta.sets, [FirstSets.frameStart]);
    expect(meta.after, contains(WallTimeUpdateSystem.systemName));
  });
}
