/// Event fired when the game hour changes.
class HourChangedEvent {
  /// Previous hour value.
  final int oldHour;

  /// New hour value.
  final int newHour;

  const HourChangedEvent({required this.oldHour, required this.newHour});
}

/// Event fired when a new game day starts.
///
/// Fired when the hour reaches [CalendarConfig.dayStartHour].
class DayChangedEvent {
  /// Previous day value.
  final int oldDay;

  /// New day value.
  final int newDay;

  /// The new day of the week (0 = Monday).
  final int dayOfWeek;

  const DayChangedEvent({
    required this.oldDay,
    required this.newDay,
    required this.dayOfWeek,
  });
}

/// Event fired when a new season starts.
class SeasonChangedEvent {
  /// Previous season index (0-3).
  final int oldSeason;

  /// New season index (0-3).
  final int newSeason;

  const SeasonChangedEvent({required this.oldSeason, required this.newSeason});
}

/// Event fired when a new year starts.
class YearChangedEvent {
  /// Previous year value.
  final int oldYear;

  /// New year value.
  final int newYear;

  const YearChangedEvent({required this.oldYear, required this.newYear});
}

/// Event fired when curfew time is reached.
///
/// Only fired when curfew is enabled ([GameTime.hasCurfew] is true).
/// Games can respond to this event by triggering sleep sequences,
/// penalties, or other consequences.
class CurfewTriggeredEvent {
  /// The current hour when curfew was triggered.
  final int hour;

  /// The configured curfew hour.
  final int curfewHour;

  const CurfewTriggeredEvent({required this.hour, required this.curfewHour});
}
