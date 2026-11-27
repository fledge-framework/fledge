import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every exported system names itself by its systemName constant', () {
    final scheduler = Scheduler();
    expect(const FrameStatsSystem().meta.name, FrameStatsSystem.systemName);
    expect(
      const OverlayPopulateSystem().meta.name,
      OverlayPopulateSystem.systemName,
    );
    expect(
      ScheduleOrderingReportSystem(scheduler).meta.name,
      ScheduleOrderingReportSystem.systemName,
    );
    expect(
      SystemStatsStartSystem(scheduler).meta.name,
      SystemStatsStartSystem.systemName,
    );
    expect(
      const SystemStatsEndSystem().meta.name,
      SystemStatsEndSystem.systemName,
    );
  });
}
