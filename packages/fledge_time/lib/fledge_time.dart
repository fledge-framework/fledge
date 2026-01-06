/// Game time and calendar system for Fledge games.
///
/// Provides a configurable calendar system with day/night cycles,
/// seasons, years, and time scaling for life simulation and RPG games.
///
/// ## Quick Start
///
/// 1. Add the plugin to your app:
/// ```dart
/// app.addPlugin(GameTimePlugin(
///   config: CalendarConfig.farmingSim(),
/// ));
/// ```
///
/// 2. Access time in systems:
/// ```dart
/// final gameTime = world.getResource<GameTime>()!;
///
/// // Check current time
/// print(gameTime.timeString);       // "6:30 AM"
/// print(gameTime.calendarString);   // "Mon, Spring 1, Year 1"
///
/// // Check for period changes
/// if (gameTime.dayChangedThisFrame) {
///   handleDailyReset();
/// }
///
/// // Use for lighting
/// final brightness = calculateBrightness(gameTime.normalizedTimeOfDay);
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
export 'src/resources/game_time.dart';

// Events
export 'src/events/time_events.dart';

// Systems
export 'src/systems/time_systems.dart';
