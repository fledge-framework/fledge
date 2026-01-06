# Game Time

The `fledge_time` package provides an in-game calendar and time system. It supports configurable time scales, seasons, day/night cycles, and time-based events.

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
    .addPlugin(TimePlugin())  // Core time (delta time)
    .addPlugin(GameTimePlugin(
      config: CalendarConfig.farmingSim(),  // Use farming sim preset
    ));

  await app.run();
}

// In your systems
@system
void dayNightSystem(World world) {
  final gameTime = world.getResource<GameTime>()!;

  // Check time of day
  if (gameTime.isDaytime()) {
    // Daytime logic
  }

  // React to day changes
  if (gameTime.dayChangedThisFrame) {
    // New day started - reset daily activities
  }
}
```

## CalendarConfig

Configure the calendar system to match your game's needs:

```dart
CalendarConfig(
  hoursPerDay: 24,           // Hours in a day
  daysPerWeek: 7,            // Days in a week
  daysPerSeason: 28,         // Days per season
  seasonsPerYear: 4,         // Seasons per year
  realSecondsPerGameMinute: 0.7,  // Time scale
  dayStartHour: 6,           // When day "starts" (for calculations)
  defaultCurfewHour: 26,     // Curfew at 2 AM (optional)
  dayNames: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  seasonNames: ['Spring', 'Summer', 'Fall', 'Winter'],
)
```

### Presets

Use built-in presets for common game types:

```dart
// Farming simulation (Stardew Valley style)
// - 28 days per season, 4 seasons
// - Fast time (0.7 real seconds = 1 game minute)
// - Includes 2 AM curfew
CalendarConfig.farmingSim()

// RPG style
// - No seasons, day/night focused
// - Moderate time scale
// - No curfew
CalendarConfig.rpg()

// Real-time (1:1 with wall clock)
CalendarConfig.realTime()

// Custom
CalendarConfig(
  hoursPerDay: 24,
  daysPerWeek: 7,
  daysPerSeason: 30,
  seasonsPerYear: 4,
  realSecondsPerGameMinute: 1.0,
  defaultCurfewHour: 24,  // Midnight curfew
)
```

## GameTime Resource

The `GameTime` resource tracks in-game time and provides change detection.

### Current Time

```dart
final time = world.getResource<GameTime>()!;

// Basic time
print('Hour: ${time.hour}');      // 0-23
print('Minute: ${time.minute}');  // 0-59
print('Day: ${time.day}');        // Total days elapsed (1-indexed)

// Calendar
print('Season: ${time.seasonName}');      // "Spring", "Summer", etc.
print('Day of season: ${time.dayOfSeason}');  // 1-28
print('Day of week: ${time.dayOfWeekName}'); // "Mon", "Tue", etc.
print('Year: ${time.year}');

// Formatted strings
print(time.timeString);           // "6:30 AM"
print(time.calendarString);       // "Mon, Spring 1, Year 1"
print(time.fullCalendarTimeString);  // "Mon, Spring 1, Year 1 - 6:30 AM"
```

### Day/Night

```dart
// Check time of day
if (time.isDaytime()) {
  // 6 AM to 8 PM by default
}

if (time.isNighttime()) {
  // 8 PM to 6 AM by default
}

// Custom day/night boundaries
if (time.isDaytime(dayStart: 7, dayEnd: 19)) {
  // 7 AM to 7 PM
}

// For lighting calculations (0.0 = day start, 1.0 = next day start)
final brightness = calculateBrightness(time.normalizedTimeOfDay);
```

### Change Detection

Edge-detect time changes for triggering game events:

```dart
@system
void timeEventSystem(World world) {
  final time = world.getResource<GameTime>()!;

  // Fires once when hour changes (e.g., 6:59 -> 7:00)
  if (time.hourChangedThisFrame) {
    updateNpcSchedules();
  }

  // Fires once when day changes (midnight)
  if (time.dayChangedThisFrame) {
    resetDailyQuests();
    applyDailyIncome();
  }

  // Fires once when season changes
  if (time.seasonChangedThisFrame) {
    updateSeasonalContent();
  }

  // Fires once when year changes
  if (time.yearChangedThisFrame) {
    triggerAnniversaryEvent();
  }
}
```

### Time Control

```dart
// Pause/resume time
time.pause();
time.resume();

// Set time directly
time.setTime(newHour: 12, newMinute: 0);
time.setTime(newDay: 5);

// Skip to a specific hour (advances to next occurrence)
time.skipToHour(6);  // Skip to next 6 AM

// Skip to next morning
time.skipToNextMorning();  // Next day at dayStartHour
```

## Curfew System

The curfew system helps enforce bedtimes in life simulation games:

```dart
final time = world.getResource<GameTime>()!;

// Check curfew status (if enabled)
if (time.hasCurfew) {
  print('Curfew at: ${time.curfewHour}');

  if (time.isPastCurfew) {
    // Player should be asleep
    triggerPassOutSequence();
  }

  // Get hours until curfew (negative if past)
  final hoursLeft = time.hoursUntilCurfew;
  if (hoursLeft != null && hoursLeft <= 2) {
    showCurfewWarning();
  }
}

// Change curfew at runtime
time.curfewHour = 28;   // 4 AM next day
time.curfewHour = null; // Disable curfew

// Detect when curfew is reached
if (time.curfewTriggeredThisFrame) {
  // This fires exactly once when time crosses the curfew hour
  startFadeToBlack();
  time.skipToNextMorning();
}
```

### Curfew Hour Format

Curfew uses 24+ hour notation relative to `dayStartHour`:

| Value | With default `dayStartHour: 6` |
|-------|-------------------------------|
| 6 | 6 AM (day start) |
| 22 | 10 PM same day |
| 24 | Midnight |
| 26 | 2 AM next day |
| 30 | 6 AM next day (max) |

## Time Events

For decoupled event handling, use time events instead of polling:

```dart
// Listen for events
app.addEvent<HourChangedEvent>();
app.addEvent<DayChangedEvent>();
app.addEvent<SeasonChangedEvent>();
app.addEvent<YearChangedEvent>();
app.addEvent<CurfewTriggeredEvent>();

// In your systems
@system
void handleTimeEvents(World world) {
  // Process hour changes
  for (final event in world.getEvents<HourChangedEvent>()) {
    print('Hour changed: ${event.oldHour} -> ${event.newHour}');
  }

  // Process day changes
  for (final event in world.getEvents<DayChangedEvent>()) {
    print('Day changed: ${event.oldDay} -> ${event.newDay}');
  }

  // Process curfew events
  for (final event in world.getEvents<CurfewTriggeredEvent>()) {
    print('Curfew triggered at hour ${event.hour}');
    triggerPassOutSequence();
  }
}
```

## GameTimeSystem

The `GameTimeSystem` advances game time each frame based on delta time.

```dart
// Automatic with plugin
App().addPlugin(GameTimePlugin());

// Or manual registration
App()
  .insertResource(GameTime(config: CalendarConfig.farmingSim()))
  .addSystem(GameTimeSystem());
```

The system:
1. Resets change flags (`beginFrame()`)
2. Advances time based on `Time.delta` and the time scale
3. Sets change flags when boundaries are crossed
4. Sends time events

## GameTimePlugin

The plugin handles setup automatically:

```dart
GameTimePlugin(
  config: CalendarConfig.farmingSim(),
  initialDay: 1,     // Starting day
  initialHour: 6,    // Starting hour
  paused: false,     // Start paused?
)
```

**Provides:**
- `GameTime` resource
- `GameTimeSystem` in `CoreStage.update`
- Time event registration

## Common Patterns

### NPC Schedules

```dart
class NpcSchedule {
  final Map<int, String> hourlyLocations;

  String getLocationForHour(int hour) {
    return hourlyLocations[hour] ?? 'home';
  }
}

@system
void npcScheduleSystem(World world) {
  final time = world.getResource<GameTime>()!;

  // Only update when hour changes
  if (!time.hourChangedThisFrame) return;

  for (final (_, npc, schedule) in world.query2<Npc, NpcSchedule>().iter()) {
    final location = schedule.getLocationForHour(time.hour);
    moveNpcToLocation(npc, location);
  }
}
```

### Sleeping/Time Skip

```dart
void goToSleep(World world) {
  final time = world.getResource<GameTime>()!;

  // Skip to morning
  time.skipToNextMorning();

  // Save the game
  final saveManager = world.getResource<SaveManager>();
  saveManager?.requestSave();
}
```

### Day/Night Lighting

```dart
Color calculateAmbientLight(GameTime time) {
  final t = time.normalizedTimeOfDay;

  // Sunrise at 0.0, sunset at ~0.58 (14 hours of day)
  if (t < 0.04) {
    // Dawn (6-7 AM)
    return Color.lerp(nightColor, dayColor, t / 0.04)!;
  } else if (t < 0.58) {
    // Daytime (7 AM - 8 PM)
    return dayColor;
  } else if (t < 0.67) {
    // Dusk (8-10 PM)
    return Color.lerp(dayColor, nightColor, (t - 0.58) / 0.09)!;
  } else {
    // Night (10 PM - 6 AM)
    return nightColor;
  }
}
```

### Seasonal Content

```dart
@system
void seasonalContentSystem(World world) {
  final time = world.getResource<GameTime>()!;

  if (!time.seasonChangedThisFrame) return;

  switch (time.season) {
    case 0:  // Spring
      spawnSpringCrops(world);
      break;
    case 1:  // Summer
      enableSwimming(world);
      break;
    case 2:  // Fall
      spawnFallFoliage(world);
      break;
    case 3:  // Winter
      addSnowEffects(world);
      break;
  }
}
```

### Save/Load Integration

`GameTime` works with `fledge_save`:

```dart
// GameTime has built-in serialization
final time = world.getResource<GameTime>()!;

// Save
final json = time.toJson();
// {"day": 15, "hour": 14, "minute": 30}

// Load
time.loadFromJson(json);
```

## API Reference

### CalendarConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `hoursPerDay` | `int` | 24 | Hours in a game day |
| `daysPerWeek` | `int` | 7 | Days in a week |
| `daysPerSeason` | `int` | 28 | Days per season |
| `seasonsPerYear` | `int` | 4 | Seasons per year |
| `realSecondsPerGameMinute` | `double` | 0.7 | Time scale |
| `dayStartHour` | `int` | 6 | Hour when "day" begins |
| `defaultCurfewHour` | `int?` | null | Default curfew hour (null = disabled) |
| `dayNames` | `List<String>?` | null | Custom day names |
| `seasonNames` | `List<String>?` | null | Custom season names |
| `useSeasons` | `bool` | true | Enable seasonal calendar |

### GameTime

| Property | Type | Description |
|----------|------|-------------|
| `hour` | `int` | Current hour (0-23) |
| `minute` | `int` | Current minute (0-59) |
| `day` | `int` | Total days elapsed (1-indexed) |
| `season` | `int` | Current season index (0-3) |
| `year` | `int` | Current year (1-indexed) |
| `isPaused` | `bool` | Whether time is paused |
| `curfewHour` | `int?` | Curfew hour (null = disabled) |
| `hasCurfew` | `bool` | Whether curfew is enabled |
| `isPastCurfew` | `bool` | Whether current time is past curfew |
| `hoursUntilCurfew` | `int?` | Hours until curfew (null if disabled) |

| Method | Description |
|--------|-------------|
| `update(deltaSeconds)` | Advance time by delta |
| `pause()` | Pause time progression |
| `resume()` | Resume time progression |
| `setTime({day, hour, minute})` | Set time directly |
| `skipToHour(hour)` | Skip to next occurrence of hour |
| `skipToNextMorning()` | Skip to next day's start |
| `isDaytime({dayStart, dayEnd})` | Check if daytime |
| `isNighttime({dayStart, dayEnd})` | Check if nighttime |

| Change Flag | Fires When |
|-------------|------------|
| `changedThisFrame` | Any minute boundary crossed |
| `hourChangedThisFrame` | Hour changed |
| `dayChangedThisFrame` | Day changed |
| `seasonChangedThisFrame` | Season changed |
| `yearChangedThisFrame` | Year changed |
| `curfewTriggeredThisFrame` | Time crossed curfew hour |

### Time Events

| Event | Properties |
|-------|------------|
| `HourChangedEvent` | `oldHour`, `newHour` |
| `DayChangedEvent` | `oldDay`, `newDay` |
| `SeasonChangedEvent` | `oldSeason`, `newSeason` |
| `YearChangedEvent` | `oldYear`, `newYear` |
| `CurfewTriggeredEvent` | `hour`, `curfewHour` |

## See Also

- [Save System](/docs/plugins/save) - Persisting game time with saves
- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
