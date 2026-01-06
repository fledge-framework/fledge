# fledge_time

Game calendar and time system for [Fledge](https://fledge-framework.dev) games. Day/night cycles, seasons, and time scaling.

[![pub package](https://img.shields.io/pub/v/fledge_time.svg)](https://pub.dev/packages/fledge_time)

## Features

- **Configurable Calendar**: Hours per day, days per season, seasons per year
- **Time Scaling**: Control how fast game time passes relative to real time
- **Change Detection**: Edge-detect hour, day, season, and year changes
- **Day/Night Helpers**: Built-in methods for checking time of day
- **Presets**: Farming sim, RPG, and real-time configurations
- **Save Integration**: Works with fledge_save via built-in serialization

## Installation

```yaml
dependencies:
  fledge_time: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_time/fledge_time.dart';

void main() async {
  final app = App()
    ..addPlugin(TimePlugin())  // Core time (delta time)
    ..addPlugin(GameTimePlugin(
      config: CalendarConfig.farmingSim(),
    ));

  await app.tick();

  // Access game time
  final gameTime = app.world.getResource<GameTime>()!;
  print(gameTime.timeString);       // "6:00 AM"
  print(gameTime.calendarString);   // "Mon, Spring 1, Year 1"
}
```

## Calendar Presets

```dart
// Farming/life simulation (Stardew Valley style)
// - 28 days per season, 4 seasons
// - 7 real seconds = 1 game minute (~3 hours per day)
CalendarConfig.farmingSim()

// RPG focused on day/night
// - No seasons, faster time
CalendarConfig.rpg()

// Real-time (1:1 with wall clock)
CalendarConfig.realTime()

// Custom configuration
CalendarConfig(
  hoursPerDay: 24,
  daysPerWeek: 7,
  daysPerSeason: 30,
  seasonsPerYear: 4,
  realSecondsPerGameMinute: 1.0,
)
```

## Usage in Systems

```dart
@system
void dayNightSystem(World world) {
  final gameTime = world.getResource<GameTime>()!;

  // Check time of day
  if (gameTime.isDaytime()) {
    // 6 AM to 8 PM by default
  }

  // For lighting calculations
  final brightness = gameTime.normalizedTimeOfDay;

  // React to time changes
  if (gameTime.dayChangedThisFrame) {
    resetDailyQuests();
  }

  if (gameTime.seasonChangedThisFrame) {
    updateSeasonalContent();
  }
}
```

## Time Control

```dart
final gameTime = world.getResource<GameTime>()!;

// Pause/resume
gameTime.pause();
gameTime.resume();

// Set time directly
gameTime.setTime(newHour: 12, newMinute: 0);

// Skip to morning (for sleeping)
gameTime.skipToNextMorning();
```

## Curfew System

Curfew support is built-in for games that need to enforce bedtimes:

```dart
// Farming sim preset includes 2 AM curfew by default
final config = CalendarConfig.farmingSim();  // curfew at hour 26 (2 AM)

// Or configure custom curfew
final config = CalendarConfig(
  defaultCurfewHour: 24,  // Midnight curfew
);

// Check curfew status
final gameTime = world.getResource<GameTime>()!;
if (gameTime.isPastCurfew) {
  // Player should be asleep
}

// Get hours until curfew (null if no curfew)
final hoursLeft = gameTime.hoursUntilCurfew;

// Change curfew at runtime
gameTime.curfewHour = 28;  // 4 AM next day
gameTime.curfewHour = null;  // Disable curfew

// React to curfew edge-trigger
if (gameTime.curfewTriggeredThisFrame) {
  triggerPassOutSequence();
}
```

**Curfew hour format**: Uses 24+ hour notation relative to day start.
- 22 = 10 PM same day
- 26 = 2 AM next day (20 hours after 6 AM wake)
- Set to `null` to disable curfew

## Time Events

Subscribe to time changes via events:

```dart
for (final event in world.eventReader<DayChangedEvent>().iter()) {
  print('Day changed: ${event.oldDay} -> ${event.newDay}');
}

for (final event in world.eventReader<SeasonChangedEvent>().iter()) {
  print('Season changed: ${event.oldSeason} -> ${event.newSeason}');
}

for (final event in world.eventReader<CurfewTriggeredEvent>().iter()) {
  print('Curfew triggered at hour ${event.hour}');
  triggerPassOutSequence();
}
```

## Documentation

See the [Game Time Guide](https://fledge-framework.dev/docs/plugins/time) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_save](https://pub.dev/packages/fledge_save) - Save/load system

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
