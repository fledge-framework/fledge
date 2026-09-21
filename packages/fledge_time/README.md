# fledge_time

**Deprecated — merged into [`fledge_calendar`](https://pub.dev/packages/fledge_calendar).**

[![pub package](https://img.shields.io/pub/v/fledge_time.svg)](https://pub.dev/packages/fledge_time)

This package is now a re-export shim. Everything that used to live here
(the game calendar, day/night cycle, seasons, curfew, etc.) has moved
into `fledge_calendar`, and the resource / plugin have been renamed:

- `GameTime` → `Calendar`
- `GameTimePlugin` → `CalendarPlugin`
- `GameTimeSystem` → `CalendarSystem`

Depending on `fledge_time` for one release remains supported so
existing code compiles unchanged (the shim re-exports the deprecated
typedefs), but new code should depend on `fledge_calendar` directly.

## Migration

```yaml
dependencies:
-  fledge_time: ^0.2.0
+  fledge_calendar: ^0.2.0
```

```dart
- import 'package:fledge_time/fledge_time.dart';
+ import 'package:fledge_calendar/fledge_calendar.dart';

- app.addPlugin(GameTimePlugin(config: CalendarConfig.farmingSim()));
+ app.addPlugin(CalendarPlugin(config: CalendarConfig.farmingSim()));

- final gameTime = world.getResource<GameTime>()!;
+ final calendar = world.getResource<Calendar>()!;
```

## Related Packages

- [fledge_calendar](https://pub.dev/packages/fledge_calendar) - In-game calendar system (successor).

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
