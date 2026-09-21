// This package is a deprecated shim. Prefer
// `package:fledge_calendar/fledge_calendar.dart` directly.
// ignore_for_file: deprecated_member_use

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_time/fledge_time.dart';

/// Minimal fledge_time example.
///
/// `fledge_time` has merged into `fledge_calendar`; this shim
/// re-exports the moved symbols. Migration from the old package to
/// the new one is a single import swap — every type used below
/// (`Calendar`, `CalendarPlugin`, `CalendarConfig`) is the same class
/// re-exported through here.
void main() async {
  final app = App()
    ..addPlugin(const WallTimePlugin())
    ..addPlugin(const CalendarPlugin(config: CalendarConfig.rpg()));

  // The re-exported Calendar resource is inserted by the plugin.
  // Games read `timeString`, `calendarString`, and the per-frame
  // `dayChangedThisFrame` / `hourChangedThisFrame` edges.
  final calendar = app.world.getResource<Calendar>()!;
  assert(calendar.timeString.isNotEmpty);

  await app.tick();
}
