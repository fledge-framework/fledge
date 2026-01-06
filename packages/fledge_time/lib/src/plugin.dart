import 'package:fledge_ecs/fledge_ecs.dart';

import 'config/calendar_config.dart';
import 'events/time_events.dart';
import 'resources/game_time.dart';
import 'systems/time_systems.dart';

/// Plugin for game time and calendar functionality.
///
/// Registers [GameTime] resource and [GameTimeSystem] to automatically
/// advance time each frame. Also registers time change events.
///
/// ## Usage
///
/// ```dart
/// app.addPlugin(GameTimePlugin(
///   config: CalendarConfig.farmingSim(),
/// ));
///
/// // Access time in systems
/// final gameTime = world.getResource<GameTime>()!;
/// if (gameTime.dayChangedThisFrame) {
///   // Handle daily reset
/// }
///
/// // Or subscribe to events
/// for (final event in world.eventReader<DayChangedEvent>().iter()) {
///   print('New day: ${event.newDay}');
/// }
/// ```
class GameTimePlugin implements Plugin {
  /// Calendar configuration.
  final CalendarConfig config;

  /// Initial day (default: 1).
  final int initialDay;

  /// Initial hour (default: config.dayStartHour).
  final int? initialHour;

  /// Creates a game time plugin with optional configuration.
  const GameTimePlugin({
    this.config = const CalendarConfig(),
    this.initialDay = 1,
    this.initialHour,
  });

  @override
  void build(App app) {
    // Register events
    app.addEvent<HourChangedEvent>();
    app.addEvent<DayChangedEvent>();
    app.addEvent<SeasonChangedEvent>();
    app.addEvent<YearChangedEvent>();
    app.addEvent<CurfewTriggeredEvent>();

    // Insert GameTime resource
    app.insertResource(
      GameTime(config: config, day: initialDay, hour: initialHour),
    );

    // Add time progression system
    app.addSystem(const GameTimeSystem(), stage: CoreStage.first);
  }

  @override
  void cleanup() {
    // Resources are automatically cleaned up by the app
  }
}
