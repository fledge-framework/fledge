// ignore_for_file: avoid_print
import 'package:fledge_calendar/fledge_calendar.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

void main() async {
  // Set up app with calendar plugin
  final app =
      App()
        ..addPlugin(const WallTimePlugin()) // Real-time delta (wall clock)
        ..addPlugin(
          const CalendarPlugin(
            config: CalendarConfig.farmingSim(),
            initialHour: 6,
            initialDay: 1,
          ),
        );

  // Initialize
  await app.tick();

  // Get the calendar resource
  final calendar = app.world.getResource<Calendar>()!;

  // Display current time
  print('Current time: ${calendar.timeString}');
  print('Calendar: ${calendar.calendarString}');
  print('Full: ${calendar.fullCalendarTimeString}');

  // Check time of day
  print('Is daytime: ${calendar.isDaytime()}');
  print('Is nighttime: ${calendar.isNighttime()}');
  print('Normalized time: ${calendar.normalizedTimeOfDay}');

  // Simulate some time passing
  print('\n--- Simulating time passage ---');
  for (var i = 0; i < 100; i++) {
    await app.tick();

    // Check for period changes
    if (calendar.hourChangedThisFrame) {
      print('Hour changed to ${calendar.hour}:00');
    }
    if (calendar.dayChangedThisFrame) {
      print('New day! Day ${calendar.dayOfSeason} of ${calendar.seasonName}');
    }
  }

  // Time control
  print('\n--- Time control ---');

  // Set specific time
  calendar.setTime(newHour: 12, newMinute: 30);
  print('After setTime: ${calendar.timeString}');

  // Pause time
  calendar.pause();
  print('Time paused: ${calendar.isPaused}');

  // Resume time
  calendar.resume();
  print('Time resumed: ${calendar.isPaused}');

  // Skip to morning
  calendar.skipToNextMorning();
  print('After skipToNextMorning: ${calendar.fullCalendarTimeString}');

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

  print('\nCalendar example completed');
}
