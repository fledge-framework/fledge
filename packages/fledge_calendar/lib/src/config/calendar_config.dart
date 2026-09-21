/// Configuration for the game calendar system.
///
/// Customize time progression, calendar structure, and display names.
class CalendarConfig {
  /// Hours in a game day. Default: 24.
  final int hoursPerDay;

  /// Days in a game week. Default: 7.
  final int daysPerWeek;

  /// Days in a game season. Default: 28.
  final int daysPerSeason;

  /// Seasons in a game year. Default: 4.
  final int seasonsPerYear;

  /// Real-world seconds per game minute.
  ///
  /// Lower values = faster time. Examples:
  /// - 1.0 = 1 real second per game minute (fast, 24 min = 1 day)
  /// - 7.0 = 7 real seconds per game minute (Stardew-like, ~3 hours = 1 day)
  /// - 60.0 = real-time (1 hour real = 1 hour game)
  final double realSecondsPerGameMinute;

  /// Hour when a new "day" starts (for daily reset events).
  ///
  /// Default: 6 (6 AM). The day counter increments when this hour is reached.
  final int dayStartHour;

  /// Custom names for days of the week.
  ///
  /// If null, uses default: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].
  final List<String>? dayNames;

  /// Custom names for seasons.
  ///
  /// If null, uses default: ['Spring', 'Summer', 'Fall', 'Winter'].
  final List<String>? seasonNames;

  /// Whether to use seasons at all.
  ///
  /// If false, [season] always returns 0 and season events are disabled.
  final bool useSeasons;

  /// Default curfew hour (null = no curfew).
  ///
  /// Uses 24+ hour format to support late-night curfews:
  /// - 22 = 10 PM same day
  /// - 26 = 2 AM next day (20 hours after 6 AM wake)
  ///
  /// Valid range: [dayStartHour] to [dayStartHour + 24] (6 to 30 with default settings).
  final int? defaultCurfewHour;

  /// Creates calendar configuration.
  const CalendarConfig({
    this.hoursPerDay = 24,
    this.daysPerWeek = 7,
    this.daysPerSeason = 28,
    this.seasonsPerYear = 4,
    this.realSecondsPerGameMinute = 7.0,
    this.dayStartHour = 6,
    this.dayNames,
    this.seasonNames,
    this.useSeasons = true,
    this.defaultCurfewHour,
  });

  /// Default configuration for farming/life simulation games.
  ///
  /// - 7 day weeks, 28 day seasons, 4 seasons
  /// - ~3 hours real time per game day
  /// - Day starts at 6 AM
  /// - Curfew at 2 AM (26 = 20 hours after 6 AM)
  const CalendarConfig.farmingSim() : this(defaultCurfewHour: 26);

  /// Configuration for RPGs focused on day/night cycles.
  ///
  /// - No seasons (useSeasons = false)
  /// - Faster time (~1.5 hours per day)
  const CalendarConfig.rpg()
    : this(realSecondsPerGameMinute: 4.0, useSeasons: false);

  /// Real-time configuration (1:1 time scale).
  ///
  /// Use for games where time matches real world.
  const CalendarConfig.realTime() : this(realSecondsPerGameMinute: 60.0);

  /// Fast time for testing.
  ///
  /// ~2 minutes per game day.
  const CalendarConfig.fast() : this(realSecondsPerGameMinute: 0.1);

  /// Total days in a year.
  int get daysPerYear => daysPerSeason * seasonsPerYear;

  /// Get the default day name for a day index (0-6).
  String getDefaultDayName(int dayIndex) {
    const defaults = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final names = dayNames ?? defaults;
    return names[dayIndex % names.length];
  }

  /// Get the default season name for a season index (0-3).
  String getDefaultSeasonName(int seasonIndex) {
    const defaults = ['Spring', 'Summer', 'Fall', 'Winter'];
    final names = seasonNames ?? defaults;
    return names[seasonIndex % names.length];
  }
}
