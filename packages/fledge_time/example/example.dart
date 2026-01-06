// ignore_for_file: avoid_print
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_time/fledge_time.dart';

void main() async {
  // Set up app with game time plugin
  final app =
      App()
        ..addPlugin(TimePlugin()) // Core time (delta time)
        ..addPlugin(
          const GameTimePlugin(
            config: CalendarConfig.farmingSim(),
            initialHour: 6,
            initialDay: 1,
          ),
        );

  // Initialize
  await app.tick();

  // Get the game time resource
  final gameTime = app.world.getResource<GameTime>()!;

  // Display current time
  print('Current time: ${gameTime.timeString}');
  print('Calendar: ${gameTime.calendarString}');
  print('Full: ${gameTime.fullCalendarTimeString}');

  // Check time of day
  print('Is daytime: ${gameTime.isDaytime()}');
  print('Is nighttime: ${gameTime.isNighttime()}');
  print('Normalized time: ${gameTime.normalizedTimeOfDay}');

  // Simulate some time passing
  print('\n--- Simulating time passage ---');
  for (var i = 0; i < 100; i++) {
    await app.tick();

    // Check for period changes
    if (gameTime.hourChangedThisFrame) {
      print('Hour changed to ${gameTime.hour}:00');
    }
    if (gameTime.dayChangedThisFrame) {
      print('New day! Day ${gameTime.dayOfSeason} of ${gameTime.seasonName}');
    }
  }

  // Time control
  print('\n--- Time control ---');

  // Set specific time
  gameTime.setTime(newHour: 12, newMinute: 30);
  print('After setTime: ${gameTime.timeString}');

  // Pause time
  gameTime.pause();
  print('Time paused: ${gameTime.isPaused}');

  // Resume time
  gameTime.resume();
  print('Time resumed: ${gameTime.isPaused}');

  // Skip to morning
  gameTime.skipToNextMorning();
  print('After skipToNextMorning: ${gameTime.fullCalendarTimeString}');

  // Calendar presets
  print('\n--- Calendar presets ---');

  // RPG preset (no seasons, faster time)
  const rpgConfig = CalendarConfig.rpg();
  print(
    'RPG - hours/day: ${rpgConfig.hoursPerDay}, '
    'uses seasons: ${rpgConfig.useSeasons}',
  );

  // Real-time preset
  const realTimeConfig = CalendarConfig.realTime();
  print(
    'Real-time - seconds per game minute: '
    '${realTimeConfig.realSecondsPerGameMinute}',
  );

  // Custom config
  const customConfig = CalendarConfig(
    hoursPerDay: 24,
    daysPerWeek: 5,
    daysPerSeason: 20,
    seasonsPerYear: 2,
    realSecondsPerGameMinute: 0.5,
    dayNames: ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'],
    seasonNames: ['Warm', 'Cold'],
  );
  print(
    'Custom - days/week: ${customConfig.daysPerWeek}, '
    'seasons/year: ${customConfig.seasonsPerYear}',
  );

  print('\nGame time example completed');
}
