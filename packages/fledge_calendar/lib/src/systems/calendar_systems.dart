import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/calendar_events.dart';
import '../resources/calendar.dart';

/// System that advances the in-game [Calendar] each frame.
///
/// Reads delta time from `fledge_ecs`'s `WallTime` resource and updates
/// [Calendar]. Emits events when time periods change.
class CalendarSystem implements System {
  /// Creates a calendar-advance system.
  const CalendarSystem();

  @override
  SystemMeta get meta => const SystemMeta(
    name: 'CalendarSystem',
    resourceReads: {WallTime, Calendar},
    resourceWrites: {Calendar},
    eventWrites: {
      HourChangedEvent,
      DayChangedEvent,
      SeasonChangedEvent,
      YearChangedEvent,
      CurfewTriggeredEvent,
    },
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    _runSync(world);
    return Future.value();
  }

  void _runSync(World world) {
    final time = world.getResource<WallTime>();
    final calendar = world.getResource<Calendar>();

    if (time == null || calendar == null) return;

    // Reset frame flags
    calendar.beginFrame();

    // Capture previous state for events
    final prevHour = calendar.hour;
    final prevDay = calendar.day;
    final prevSeason = calendar.season;
    final prevYear = calendar.year;

    // Advance time
    calendar.update(time.delta);

    // Emit events for period changes
    if (calendar.hourChangedThisFrame) {
      world.eventWriter<HourChangedEvent>().send(
        HourChangedEvent(oldHour: prevHour, newHour: calendar.hour),
      );
    }

    if (calendar.dayChangedThisFrame) {
      world.eventWriter<DayChangedEvent>().send(
        DayChangedEvent(
          oldDay: prevDay,
          newDay: calendar.day,
          dayOfWeek: calendar.dayOfWeek,
        ),
      );
    }

    if (calendar.seasonChangedThisFrame) {
      world.eventWriter<SeasonChangedEvent>().send(
        SeasonChangedEvent(oldSeason: prevSeason, newSeason: calendar.season),
      );
    }

    if (calendar.yearChangedThisFrame) {
      world.eventWriter<YearChangedEvent>().send(
        YearChangedEvent(oldYear: prevYear, newYear: calendar.year),
      );
    }

    if (calendar.curfewTriggeredThisFrame && calendar.curfewHour != null) {
      world.eventWriter<CurfewTriggeredEvent>().send(
        CurfewTriggeredEvent(
          hour: calendar.hour,
          curfewHour: calendar.curfewHour!,
        ),
      );
    }
  }
}

/// Deprecated alias for [CalendarSystem].
@Deprecated('Renamed to CalendarSystem in v0.2. Use CalendarSystem instead.')
typedef GameTimeSystem = CalendarSystem;
