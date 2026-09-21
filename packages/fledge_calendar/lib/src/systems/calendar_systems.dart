import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/calendar_events.dart';
import '../resources/calendar.dart';

/// System that advances the in-game [Calendar] each frame.
///
/// Reads delta time from `fledge_ecs`'s `WallTime` resource and updates
/// [Calendar]. Emits events when time periods change.
///
/// Each run:
/// 1. Takes pending out-of-system changes ([Calendar.takePendingChanges]).
/// 2. Clears the frame flags ([Calendar.beginFrame]).
/// 3. Advances time by `WallTime.delta` ([Calendar.update]).
/// 4. Emits events for the pending changes (old value = before the change,
///    new value = value at the start of this frame), if any.
/// 5. Emits events for changes made by this frame's update.
///
/// So calling e.g. [Calendar.skipToNextMorning] from any schedule yields
/// exactly one [DayChangedEvent] and one [HourChangedEvent] on the next
/// run, and none on the run after.
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

    // Changes made outside this system since its last run (skipToNextMorning,
    // skipToHour, setTime). Their edge flags are about to be cleared.
    final pending = calendar.takePendingChanges();

    // Reset frame flags
    calendar.beginFrame();

    // Capture previous state for events
    final prevHour = calendar.hour;
    final prevDay = calendar.day;
    final prevSeason = calendar.season;
    final prevYear = calendar.year;

    // Advance time
    calendar.update(time.delta);

    // Emit events for out-of-system changes first (old = before the change,
    // new = state at the start of this frame).
    if (pending != null) {
      _emitPending(
        world,
        calendar,
        pending,
        prevHour,
        prevDay,
        prevSeason,
        prevYear,
      );
    }

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

  void _emitPending(
    World world,
    Calendar calendar,
    CalendarPendingChanges pending,
    int newHour,
    int newDay,
    int newSeason,
    int newYear,
  ) {
    if (pending.oldHour != newHour) {
      world.eventWriter<HourChangedEvent>().send(
        HourChangedEvent(oldHour: pending.oldHour, newHour: newHour),
      );
    }

    if (pending.oldDay != newDay) {
      world.eventWriter<DayChangedEvent>().send(
        DayChangedEvent(
          oldDay: pending.oldDay,
          newDay: newDay,
          dayOfWeek: (newDay - 1) % calendar.config.daysPerWeek,
        ),
      );
    }

    if (pending.oldSeason != newSeason) {
      world.eventWriter<SeasonChangedEvent>().send(
        SeasonChangedEvent(oldSeason: pending.oldSeason, newSeason: newSeason),
      );
    }

    if (pending.oldYear != newYear) {
      world.eventWriter<YearChangedEvent>().send(
        YearChangedEvent(oldYear: pending.oldYear, newYear: newYear),
      );
    }

    if (pending.curfewTriggered && calendar.curfewHour != null) {
      world.eventWriter<CurfewTriggeredEvent>().send(
        CurfewTriggeredEvent(hour: newHour, curfewHour: calendar.curfewHour!),
      );
    }
  }
}

/// Deprecated alias for [CalendarSystem].
@Deprecated('Renamed to CalendarSystem in v0.2. Use CalendarSystem instead.')
typedef GameTimeSystem = CalendarSystem;
