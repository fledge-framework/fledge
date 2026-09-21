import 'package:fledge_ecs/fledge_ecs.dart';

import 'config/calendar_config.dart';
import 'events/calendar_events.dart';
import 'resources/calendar.dart';
import 'systems/calendar_systems.dart';

/// Plugin for in-game calendar functionality.
///
/// Registers the [Calendar] resource and [CalendarSystem] to
/// automatically advance the in-game clock each frame, plus the
/// calendar change events.
///
/// ## Usage
///
/// ```dart
/// app.addPlugin(CalendarPlugin(
///   config: CalendarConfig.farmingSim(),
/// ));
///
/// // Access the calendar in systems
/// final calendar = world.getResource<Calendar>()!;
/// if (calendar.dayChangedThisFrame) {
///   // Handle daily reset
/// }
///
/// // Or subscribe to events
/// for (final event in world.eventReader<DayChangedEvent>().iter()) {
///   print('New day: ${event.newDay}');
/// }
/// ```
class CalendarPlugin implements Plugin {
  /// Calendar configuration.
  final CalendarConfig config;

  /// Initial day (default: 1).
  final int initialDay;

  /// Initial hour (default: config.dayStartHour).
  final int? initialHour;

  /// Creates a calendar plugin with optional configuration.
  const CalendarPlugin({
    this.config = const CalendarConfig(),
    this.initialDay = 1,
    this.initialHour,
  });

  @override
  void build(App app) {
    // Register events
    app.addEvent<HourChangedEvent>();
    app.addEvent<DayChangedEvent>();
    app.addEvent<SeasonChangedEvent>();
    app.addEvent<YearChangedEvent>();
    app.addEvent<CurfewTriggeredEvent>();

    // Insert Calendar resource
    app.insertResource(
      Calendar(config: config, day: initialDay, hour: initialHour),
    );

    // Add calendar-advance system
    app.addSystem(const CalendarSystem(), schedule: Schedules.first);
  }

  @override
  void cleanup() {
    // Resources are automatically cleaned up by the app
  }
}

/// Deprecated alias for [CalendarPlugin].
///
/// Renamed to [CalendarPlugin] in v0.2 (the package moved from
/// `fledge_time` to `fledge_calendar`). Update call sites to
/// [CalendarPlugin]; this class will be removed in a future release.
@Deprecated('Renamed to CalendarPlugin in v0.2. Use CalendarPlugin instead.')
class GameTimePlugin extends CalendarPlugin {
  /// Creates a deprecated GameTimePlugin (forwards to [CalendarPlugin]).
  const GameTimePlugin({
    super.config = const CalendarConfig(),
    super.initialDay = 1,
    super.initialHour,
  });
}
