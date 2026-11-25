# fledge_calendar

In-game calendar and time-of-day system for [Fledge](https://fledge-framework.dev) games. Day/night cycles, seasons, and configurable time scaling.

[![pub package](https://img.shields.io/pub/v/fledge_calendar.svg)](https://pub.dev/packages/fledge_calendar)

> Previously published as `fledge_time`. Depend on `fledge_calendar` instead; the old class names (`GameTime`, `GameTimePlugin`, `GameTimeSystem`) remain as deprecated aliases of `Calendar`, `CalendarPlugin` and `CalendarSystem`.

## Installation

```yaml
dependencies:
  fledge_calendar: ^0.7.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_calendar/fledge_calendar.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(CalendarPlugin(config: CalendarConfig.farmingSim()));

  await app.tick();

  final calendar = app.world.getResource<Calendar>()!;
  print(calendar.timeString);      // "6:00 AM"
  print(calendar.calendarString);  // "Mon, Spring 1, Year 1"

  await app.run();
}
```

`CalendarPlugin` advances the clock by `WallTime.delta`, so add `WallTimePlugin` too (plugin order doesn't matter). If `WallTime` is missing, `CalendarSystem` throws a `StateError` on its first run rather than leaving the clock frozen.

## Skipping Time

```dart
// e.g. from a sleep or curfew handler, in any schedule
calendar.skipToNextMorning();
```

`skipToNextMorning()`, `skipToHour()` and `setTime()` can be called from any schedule: `CalendarSystem` emits exactly one `DayChangedEvent` / `HourChangedEvent` (and season/year events when crossed) for the change on its next run. The day counter increments at midnight, so skipping at 2 AM stays on the same day and just moves to `dayStartHour`; a pre-midnight curfew does not re-trigger after midnight.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/gameplay/calendar) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
