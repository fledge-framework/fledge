import 'package:fledge_ecs/fledge_ecs.dart';

import '../events/time_events.dart';
import '../resources/game_time.dart';

/// System that advances game time each frame.
///
/// Reads delta time from [Time] resource and updates [GameTime].
/// Emits events when time periods change.
class GameTimeSystem implements System {
  /// Creates a game time system.
  const GameTimeSystem();

  @override
  SystemMeta get meta => const SystemMeta(
    name: 'GameTimeSystem',
    resourceReads: {Time, GameTime},
    resourceWrites: {GameTime},
    eventWrites: {
      HourChangedEvent,
      DayChangedEvent,
      SeasonChangedEvent,
      YearChangedEvent,
      CurfewTriggeredEvent,
    },
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    _runSync(world);
    return Future.value();
  }

  void _runSync(World world) {
    final time = world.getResource<Time>();
    final gameTime = world.getResource<GameTime>();

    if (time == null || gameTime == null) return;

    // Reset frame flags
    gameTime.beginFrame();

    // Capture previous state for events
    final prevHour = gameTime.hour;
    final prevDay = gameTime.day;
    final prevSeason = gameTime.season;
    final prevYear = gameTime.year;

    // Advance time
    gameTime.update(time.delta);

    // Emit events for period changes
    if (gameTime.hourChangedThisFrame) {
      world.eventWriter<HourChangedEvent>().send(
        HourChangedEvent(oldHour: prevHour, newHour: gameTime.hour),
      );
    }

    if (gameTime.dayChangedThisFrame) {
      world.eventWriter<DayChangedEvent>().send(
        DayChangedEvent(
          oldDay: prevDay,
          newDay: gameTime.day,
          dayOfWeek: gameTime.dayOfWeek,
        ),
      );
    }

    if (gameTime.seasonChangedThisFrame) {
      world.eventWriter<SeasonChangedEvent>().send(
        SeasonChangedEvent(oldSeason: prevSeason, newSeason: gameTime.season),
      );
    }

    if (gameTime.yearChangedThisFrame) {
      world.eventWriter<YearChangedEvent>().send(
        YearChangedEvent(oldYear: prevYear, newYear: gameTime.year),
      );
    }

    if (gameTime.curfewTriggeredThisFrame && gameTime.curfewHour != null) {
      world.eventWriter<CurfewTriggeredEvent>().send(
        CurfewTriggeredEvent(
          hour: gameTime.hour,
          curfewHour: gameTime.curfewHour!,
        ),
      );
    }
  }
}
