# fledge_calendar

In-game calendar and time-of-day system for [Fledge](https://fledge-framework.dev) games. Day/night cycles, seasons, and configurable time scaling.

[![pub package](https://img.shields.io/pub/v/fledge_calendar.svg)](https://pub.dev/packages/fledge_calendar)

> Previously published as `fledge_time`. The old package name still resolves via a re-export shim for one release — new code should depend on `fledge_calendar` directly.

## Installation

```yaml
dependencies:
  fledge_calendar: ^0.2.1
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

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/calendar) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
