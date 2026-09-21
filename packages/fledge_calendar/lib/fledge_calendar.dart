/// In-game calendar and time-of-day system for Fledge games.
///
/// Provides a configurable calendar with day/night cycles, seasons,
/// years, curfews, and time scaling for life simulations, RPGs, and
/// other games that need a game-world clock distinct from real (wall)
/// time. Wall-clock delta comes from `fledge_ecs`'s `WallTime`.
///
/// ## Quick Start
///
/// 1. Add the plugin to your app:
/// ```dart
/// app.addPlugin(CalendarPlugin(
///   config: CalendarConfig.farmingSim(),
/// ));
/// ```
///
/// 2. Access the calendar in systems:
/// ```dart
/// final calendar = world.getResource<Calendar>()!;
///
/// // Check current time
/// print(calendar.timeString);       // "6:30 AM"
/// print(calendar.calendarString);   // "Mon, Spring 1, Year 1"
///
/// // Check for period changes
/// if (calendar.dayChangedThisFrame) {
///   handleDailyReset();
/// }
///
/// // Use for lighting
/// final brightness = calculateBrightness(calendar.normalizedTimeOfDay);
/// ```
///
/// 3. Or subscribe to events:
/// ```dart
/// for (final event in world.eventReader<DayChangedEvent>().iter()) {
///   print('New day: ${event.newDay}');
/// }
/// ```
///
/// ## Calendar Presets
///
/// ```dart
/// // Farming/life sim (default)
/// CalendarConfig.farmingSim()
/// // 28-day seasons, 4 seasons, ~3 hours per day
///
/// // RPG focused on day/night
/// CalendarConfig.rpg()
/// // No seasons, faster time
///
/// // Real-time
/// CalendarConfig.realTime()
/// // 1:1 time scale
/// ```
///
/// ## Time Scale
///
/// The [CalendarConfig.realSecondsPerGameMinute] controls time speed:
/// - `7.0` (default) = ~3 hours real time per game day
/// - `1.0` = ~24 minutes per game day
/// - `60.0` = real-time (1 real hour = 1 game hour)
library;

// Plugin
export 'src/plugin.dart';

// Config
export 'src/config/calendar_config.dart';

// Resources
export 'src/resources/calendar.dart';

// Events
export 'src/events/calendar_events.dart';

// Systems
export 'src/systems/calendar_systems.dart';
