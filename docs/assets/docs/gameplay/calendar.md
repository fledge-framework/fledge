# Calendar

`fledge_calendar` gives your game an in-world clock and calendar: minutes,
hours, days, weeks, seasons and years, running at a speed you choose, with a
curfew, pause and time skips. It's the clock for farming and life sims, RPG
day/night cycles, and shop opening hours.

It's separate from `WallTime` (real seconds per frame) and the fixed
timestep, which are covered in [Time & Fixed Timestep](/docs/scheduling/time).

## What you need

```yaml
dependencies:
  fledge_calendar: ^0.7.2
```

- **Pure Dart** (Dart `^3.11`), no Flutter dependency; runs on every
  platform, including tests and servers.
- **`WallTimePlugin`**: the calendar advances by `WallTime.delta`.
  `CalendarPlugin` doesn't add it for you (plugin order doesn't matter). If
  there is no `WallTime` resource, `CalendarSystem` throws a `StateError` on
  its first run instead of leaving the clock frozen.

## Quick start

<!-- snippet-setup
void handleDailyReset(World world) {}

class Npc {
  String location = 'home';
}
-->

```dart
import 'package:fledge_calendar/fledge_calendar.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

Future<void> main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(const CalendarPlugin(config: CalendarConfig.farmingSim()));

  await app.tick();

  final calendar = app.world.getResource<Calendar>()!;
  print(calendar.timeString); // 6:00 AM
  print(calendar.calendarString); // Mon, Spring 1, Year 1
}
```

`CalendarPlugin` inserts the `Calendar` resource, registers the calendar
events, and adds `CalendarSystem`. Its options are `config`, `initialDay`
(default 1) and `initialHour` (default `config.dayStartHour`).

## Configuration

```dart
const config = CalendarConfig(
  hoursPerDay: 24,
  daysPerWeek: 7,
  daysPerSeason: 28,
  seasonsPerYear: 4,
  realSecondsPerGameMinute: 7.0, // ~2.8 real hours per game day
  dayStartHour: 6, // wake-up hour and curfew reference
  dayNames: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  seasonNames: ['Spring', 'Summer', 'Fall', 'Winter'],
  useSeasons: true,
  defaultCurfewHour: null, // no curfew
);
```

The values above are the defaults. `realSecondsPerGameMinute` sets the speed:
a game day at 24 hours takes `realSecondsPerGameMinute × 1440` real seconds.
`dayNames` and `seasonNames` default to the lists shown. `daysPerYear` is
`daysPerSeason × seasonsPerYear`.

### Presets

| Preset | Real seconds per game minute | Notes |
|---|---|---|
| `CalendarConfig()` | 7.0 | The defaults above |
| `CalendarConfig.farmingSim()` | 7.0 | Defaults plus a curfew at 26 (2 AM) |
| `CalendarConfig.rpg()` | 4.0 | No seasons; a day is about 1.6 real hours |
| `CalendarConfig.realTime()` | 60.0 | One game hour per real hour |
| `CalendarConfig.fast()` | 0.1 | About 2.4 real minutes per day, for testing |

`dayStartHour` is when the player's day begins: where `skipToNextMorning()`
wakes up, the zero point of `normalizedTimeOfDay`, and what curfew hours are
measured from. It doesn't move the day counter, which always increments at
midnight (hour 0).

## Reading the calendar

```dart
final calendarHud = FunctionSystem(
  'calendarHud',
  resourceReads: {Calendar},
  run: (world) {
    final c = world.getResource<Calendar>()!;
    print('${c.fullCalendarTimeString} (${c.isWeekend ? 'weekend' : 'weekday'})');
  },
);
```

| Member | Meaning |
|---|---|
| `day`, `hour`, `minute` | The current time. `day` starts at 1 and keeps counting. These fields are writable, but prefer `setTime` (below) so events fire |
| `totalMinutes` | Minutes since midnight |
| `totalMinutesPrecise` | Minutes since day 1 midnight, including the partial minute |
| `dayOfWeek`, `dayOfWeekName`, `isWeekend` | 0-based weekday, its name, and whether it's one of the last two days of the week |
| `season`, `seasonName`, `dayOfSeason`, `weekOfSeason` | 0-based season, its name, and the 1-based day and week within it |
| `year`, `dayOfYear` | 1-based |
| `timeString` | `6:30 AM` on a 24-hour day; plain `hour:minute` (e.g. `17:05`) when `hoursPerDay` isn't 24 |
| `fullTimeString` | `Day 3 - 6:30 AM` |
| `calendarString` | `Mon, Spring 1, Year 1` (`Mon, Day 3` without seasons) |
| `fullCalendarTimeString` | Calendar and time together |
| `isDaytime({dayStart = 6, dayEnd = 20})`, `isNighttime(...)` | Hour within (or outside) the range |
| `normalizedTimeOfDay` | 0.0 at `dayStartHour`, rising to 1.0 at the next one; handy for lighting |

With `useSeasons: false`, `season` is always 0, `year` always 1, `dayOfSeason`
and `dayOfYear` equal `day`, and season and year events never fire.

## Reacting to changes

Each frame `CalendarSystem` clears and sets edge flags on the resource:
`changedThisFrame` (any minute), `hourChangedThisFrame`,
`dayChangedThisFrame`, `seasonChangedThisFrame`, `yearChangedThisFrame` and
`curfewTriggeredThisFrame`. They're true only during the frame of the change:

```dart
final dailyReset = FunctionSystem(
  'dailyReset',
  resourceReads: {Calendar},
  run: (world) {
    if (world.getResource<Calendar>()!.dayChangedThisFrame) {
      handleDailyReset(world);
    }
  },
);
```

It also sends events, which `CalendarPlugin` registers for you (don't call
`addEvent` for them again: re-registering drops pending events):

| Event | Fields |
|---|---|
| `HourChangedEvent` | `oldHour`, `newHour` |
| `DayChangedEvent` | `oldDay`, `newDay`, `dayOfWeek` |
| `SeasonChangedEvent` | `oldSeason`, `newSeason` |
| `YearChangedEvent` | `oldYear`, `newYear` |
| `CurfewTriggeredEvent` | `hour`, `curfewHour` |

```dart
final shopHours = FunctionSystem(
  'shopHours',
  writes: {ComponentId.of<Npc>()},
  eventReads: {HourChangedEvent},
  run: (world) {
    for (final e in world.eventReader<HourChangedEvent>().read()) {
      for (final (_, npc) in world.query1<Npc>().iter()) {
        npc.location = (e.newHour >= 9 && e.newHour < 17) ? 'shop' : 'home';
      }
    }
  },
);
```

Events follow the usual [double buffering](/docs/ecs/events): one sent this
frame is readable next frame. The flags are visible this frame, to systems
that run after `CalendarSystem` (any schedule after `first`).

## Changing the time

```dart
final sleep = FunctionSystem(
  'sleep',
  resourceWrites: {Calendar},
  run: (world) {
    final calendar = world.getResource<Calendar>()!;
    calendar.skipToNextMorning(); // to dayStartHour
    // calendar.skipToHour(18);   // next 6 PM, tomorrow if it's past
    // calendar.setTime(newDay: 10, newHour: 12, newMinute: 0);
    // calendar.pause(); calendar.resume(); calendar.isPaused;
  },
);
```

`skipToNextMorning()`, `skipToHour()` and `setTime()` can be called from any
schedule. `CalendarSystem` turns each into exactly one set of hour, day,
season and year events on its next run (several calls before that run
combine into one change). `skipToNextMorning()` advances `day` only when the
current hour is at or after `dayStartHour`: passing out at 2 AM, after the day
already rolled over at midnight, just moves the clock to the morning.
`skipToHour` ignores hours outside `0..hoursPerDay-1`; `setTime` clamps them.

## Curfew

A curfew fires `CurfewTriggeredEvent` (and `curfewTriggeredThisFrame`) once,
when the clock crosses the curfew hour. Curfew hours are written in a 24+
hour form measured from `dayStartHour`, so a curfew after midnight is still
"today":

| Value | With `dayStartHour: 6` |
|---|---|
| `22` | 10 PM |
| `24` | midnight |
| `26` | 2 AM, 20 hours after waking |

```dart
final curfew = FunctionSystem(
  'curfew',
  resourceWrites: {Calendar},
  eventReads: {CurfewTriggeredEvent},
  run: (world) {
    if (world.eventReader<CurfewTriggeredEvent>().isNotEmpty) {
      world.getResource<Calendar>()!.skipToNextMorning(); // pass out
    }
  },
);
```

Set it with `defaultCurfewHour` in the config, or at runtime with
`calendar.curfewHour = 24` (null turns it off). Values outside
`dayStartHour..dayStartHour + hoursPerDay` throw an `ArgumentError`.
`hasCurfew`, `isPastCurfew` and `hoursUntilCurfew` (negative once past, null
without a curfew) query it. A curfew passed before midnight doesn't fire
again after midnight; it re-arms at `dayStartHour`. `setTime` doesn't fire a
curfew itself (the next hour tick re-checks); `skipToHour` does when it lands
past curfew.

## Ordering and manual registration

`CalendarSystem` runs in `Schedules.first`, in the `FirstSets.frameStart`
phase, after `WallTimeUpdateSystem.systemName`. Its name is
`CalendarSystem.systemName`. To order your own system in `first` against it:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(const CalendarPlugin())
  ..addSystem(
    FunctionSystem(
      'clockAudio',
      after: [CalendarSystem.systemName],
      resourceReads: {Calendar},
      run: (world) {},
    ),
    schedule: Schedules.first,
  );
```

Systems in `preUpdate`, `update` and later run after it anyway.

Without the plugin, insert the resource, register the five events and add
the system yourself. `CalendarSystem` declares its own set and ordering:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..insertResource(Calendar(config: const CalendarConfig.rpg()))
  ..addEvent<HourChangedEvent>()
  ..addEvent<DayChangedEvent>()
  ..addEvent<SeasonChangedEvent>()
  ..addEvent<YearChangedEvent>()
  ..addEvent<CurfewTriggeredEvent>()
  ..addSystem(const CalendarSystem(), schedule: Schedules.first);
```

If you drive the clock without `CalendarSystem`, call `beginFrame()` then
`update(deltaSeconds)` once per frame. No events are sent in that case.

## Saving the calendar

`Calendar` has `toJson()` and `loadFromJson(json)`, but doesn't mix in
`Saveable`. To save it with [fledge_save](/docs/gameplay/save), wrap it in a
small saveable resource:

```dart
class CalendarSave with Saveable {
  CalendarSave(this.calendar);
  final Calendar calendar;

  @override
  String get saveKey => 'calendar';

  @override
  Map<String, dynamic> toSaveJson() => calendar.toJson();

  @override
  void loadFromSaveJson(Map<String, dynamic> json) =>
      calendar.loadFromJson(json);
}

App buildApp() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(const CalendarPlugin(config: CalendarConfig.farmingSim()))
    ..addPlugin(SavePlugin());
  // The plugin built the Calendar already; the save manager finds the wrapper.
  return app..insertResource(CalendarSave(app.world.getResource<Calendar>()!));
}
```

The JSON holds `day`, `hour`, `minute` and, when set, `curfewHour`. Pause
state and the partial minute aren't saved. `loadFromJson` falls back to the
config's curfew when the saved one is missing or out of range, and resets the
edge tracking, so loading doesn't fire day, season or curfew events.

## Migrating from `GameTime`

The package was previously `fledge_time`, with different names. The old
class names still compile, with deprecation warnings, and will be removed:

| Deprecated | Use |
|---|---|
| `GameTime` | `Calendar` |
| `GameTimePlugin` | `CalendarPlugin` |
| `GameTimeSystem` | `CalendarSystem` |

Depend on `fledge_calendar` and import
`package:fledge_calendar/fledge_calendar.dart`.

## See also

- [Time & Fixed Timestep](/docs/scheduling/time)
- [Save & Load](/docs/gameplay/save)
- [Lighting](/docs/rendering/lighting): drive ambient light from
  `normalizedTimeOfDay`
- [API reference](https://pub.dev/documentation/fledge_calendar/latest/)
