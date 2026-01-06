import '../config/calendar_config.dart';

/// Resource tracking in-game time with calendar support.
///
/// Provides a configurable calendar system with:
/// - Customizable time scale (real seconds per game minute)
/// - Days, weeks, seasons, years
/// - Edge detection for period changes (hourChangedThisFrame, etc.)
/// - Pause/resume functionality
/// - Serialization support
///
/// ## Usage
///
/// ```dart
/// // In game loop
/// final time = world.getResource<GameTime>()!;
/// time.update(deltaSeconds);
///
/// // Check for period changes
/// if (time.dayChangedThisFrame) {
///   // Handle daily reset
/// }
///
/// // Use for lighting
/// final brightness = calculateBrightness(time.normalizedTimeOfDay);
/// ```
class GameTime {
  /// Calendar configuration.
  final CalendarConfig config;

  /// Current day (starts at 1, increments indefinitely).
  int day;

  /// Current hour (0-23).
  int hour;

  /// Current minute (0-59).
  int minute;

  /// Whether time is currently progressing.
  bool isPaused;

  /// Accumulator for partial minute progress.
  double _accumulator = 0.0;

  // === Edge Detection Flags ===

  /// Whether time changed this frame (any minute boundary).
  bool changedThisFrame = false;

  /// Whether the hour changed this frame.
  bool hourChangedThisFrame = false;

  /// Whether a new day started this frame.
  bool dayChangedThisFrame = false;

  /// Whether the season changed this frame.
  bool seasonChangedThisFrame = false;

  /// Whether the year changed this frame.
  bool yearChangedThisFrame = false;

  /// Whether curfew was triggered this frame (edge-detected transition).
  ///
  /// Only true on the exact frame when time crosses the curfew hour.
  /// Will be false if curfew is disabled (curfewHour is null).
  bool curfewTriggeredThisFrame = false;

  /// Track previous states for edge detection.
  late int _previousSeason;
  late int _previousYear;
  bool _wasPastCurfew = false;

  /// Curfew hour (null = no curfew).
  ///
  /// Uses 24+ hour format relative to dayStartHour:
  /// - 22 = 10 PM same day
  /// - 26 = 2 AM next day (20 hours after 6 AM wake)
  int? _curfewHour;

  /// Creates a GameTime resource with optional configuration.
  GameTime({
    this.config = const CalendarConfig(),
    this.day = 1,
    int? hour,
    this.minute = 0,
    this.isPaused = false,
    int? curfewHour,
  }) : hour = hour ?? config.dayStartHour {
    // Initialize curfew from parameter or config default
    _curfewHour = curfewHour ?? config.defaultCurfewHour;
    // Initialize edge detection state
    _previousSeason = season;
    _previousYear = year;
    _wasPastCurfew = isPastCurfew;
  }

  // === Time Progression ===

  /// Update time based on real delta (in seconds).
  ///
  /// Call this once per frame with the frame's delta time.
  void update(double deltaSeconds) {
    if (isPaused) return;

    _accumulator += deltaSeconds;

    while (_accumulator >= config.realSecondsPerGameMinute) {
      _accumulator -= config.realSecondsPerGameMinute;
      _advanceMinute();
    }
  }

  void _advanceMinute() {
    minute++;
    changedThisFrame = true;

    if (minute >= 60) {
      minute = 0;
      hour++;
      hourChangedThisFrame = true;

      // Edge-detect curfew transition (was NOT past, now IS past)
      if (_curfewHour != null) {
        final nowPastCurfew = isPastCurfew;
        if (nowPastCurfew && !_wasPastCurfew) {
          curfewTriggeredThisFrame = true;
        }
        _wasPastCurfew = nowPastCurfew;
      }

      if (hour >= config.hoursPerDay) {
        hour = 0;
        day++;
        dayChangedThisFrame = true;
        // Reset curfew tracking for new day
        _wasPastCurfew = false;

        // Edge-detect season change
        if (config.useSeasons) {
          final currentSeason = season;
          if (currentSeason != _previousSeason) {
            seasonChangedThisFrame = true;
            _previousSeason = currentSeason;

            // Edge-detect year change
            final currentYear = year;
            if (currentYear != _previousYear) {
              yearChangedThisFrame = true;
              _previousYear = currentYear;
            }
          }
        }
      }
    }
  }

  // === Time Accessors ===

  /// Current hour (alias for schedule lookups).
  int get currentHour => hour;

  /// Total minutes since midnight.
  int get totalMinutes => hour * 60 + minute;

  /// Total minutes since day 1 midnight (including fractional progress).
  double get totalMinutesPrecise =>
      (day - 1) * config.hoursPerDay * 60 +
      hour * 60 +
      minute +
      (_accumulator / config.realSecondsPerGameMinute);

  // === Calendar Getters ===

  /// Current year (1-indexed).
  int get year {
    if (!config.useSeasons) return 1;
    return ((day - 1) ~/ config.daysPerYear) + 1;
  }

  /// Current season index (0 to seasonsPerYear-1).
  int get season {
    if (!config.useSeasons) return 0;
    final dayOfYear = (day - 1) % config.daysPerYear;
    return dayOfYear ~/ config.daysPerSeason;
  }

  /// Season display name.
  String get seasonName => config.getDefaultSeasonName(season);

  /// Day within the current season (1-based).
  int get dayOfSeason {
    if (!config.useSeasons) return day;
    return ((day - 1) % config.daysPerSeason) + 1;
  }

  /// Day of the week index (0 = first day).
  int get dayOfWeek => (day - 1) % config.daysPerWeek;

  /// Day of week display name.
  String get dayOfWeekName => config.getDefaultDayName(dayOfWeek);

  /// Week number within the current season (1-based).
  int get weekOfSeason => ((dayOfSeason - 1) ~/ config.daysPerWeek) + 1;

  /// Day within the current year (1-based).
  int get dayOfYear {
    if (!config.useSeasons) return day;
    return ((day - 1) % config.daysPerYear) + 1;
  }

  /// Whether today is a weekend (last 2 days of week).
  bool get isWeekend {
    final daysFromEnd = config.daysPerWeek - 1 - dayOfWeek;
    return daysFromEnd < 2;
  }

  // === Time Display ===

  /// Format time for display (e.g., "6:30 AM").
  String get timeString {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final ampm = hour < 12 ? 'AM' : 'PM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $ampm';
  }

  /// Format time with day (e.g., "Day 1 - 6:30 AM").
  String get fullTimeString => 'Day $day - $timeString';

  /// Full calendar string (e.g., "Mon, Spring 1, Year 1").
  String get calendarString {
    if (config.useSeasons) {
      return '$dayOfWeekName, $seasonName $dayOfSeason, Year $year';
    }
    return '$dayOfWeekName, Day $day';
  }

  /// Complete date/time string.
  String get fullCalendarTimeString => '$calendarString - $timeString';

  // === Day/Night ===

  /// Whether it's currently daytime.
  ///
  /// By default, daytime is 6 AM to 8 PM.
  bool isDaytime({int dayStart = 6, int dayEnd = 20}) =>
      hour >= dayStart && hour < dayEnd;

  /// Whether it's currently nighttime.
  bool isNighttime({int dayStart = 6, int dayEnd = 20}) =>
      !isDaytime(dayStart: dayStart, dayEnd: dayEnd);

  /// Normalized time of day (0.0 = dayStartHour, 1.0 = dayStartHour next day).
  ///
  /// Useful for lighting calculations and day/night transitions.
  double get normalizedTimeOfDay {
    final startHour = config.dayStartHour;
    final hoursSinceStart =
        (hour >= startHour)
            ? hour - startHour
            : hour + config.hoursPerDay - startHour;
    return (hoursSinceStart + minute / 60.0) / config.hoursPerDay;
  }

  // === Curfew ===

  /// Get the curfew hour (null = no curfew).
  int? get curfewHour => _curfewHour;

  /// Set the curfew hour with validation.
  ///
  /// Set to null to disable curfew.
  /// Valid range: [dayStartHour] to [dayStartHour + 24].
  set curfewHour(int? value) {
    if (value != null) {
      final minCurfew = config.dayStartHour;
      final maxCurfew = config.dayStartHour + config.hoursPerDay;
      if (value < minCurfew || value > maxCurfew) {
        throw ArgumentError(
          'Curfew hour must be $minCurfew-$maxCurfew, got $value',
        );
      }
    }
    _curfewHour = value;
    _wasPastCurfew = isPastCurfew;
  }

  /// Whether curfew is enabled.
  bool get hasCurfew => _curfewHour != null;

  /// Whether current time is past curfew.
  ///
  /// Returns false if curfew is disabled.
  /// Curfew is checked as hours since dayStartHour.
  bool get isPastCurfew {
    if (_curfewHour == null) return false;
    final startHour = config.dayStartHour;
    final hoursSinceStart =
        (hour >= startHour)
            ? hour - startHour
            : hour + config.hoursPerDay - startHour;
    final curfewHoursSinceStart = _curfewHour! - startHour;
    return hoursSinceStart >= curfewHoursSinceStart;
  }

  /// Hours until curfew (negative if past curfew).
  ///
  /// Returns null if curfew is disabled.
  int? get hoursUntilCurfew {
    if (_curfewHour == null) return null;
    final startHour = config.dayStartHour;
    final hoursSinceStart =
        (hour >= startHour)
            ? hour - startHour
            : hour + config.hoursPerDay - startHour;
    final curfewHoursSinceStart = _curfewHour! - startHour;
    return curfewHoursSinceStart - hoursSinceStart;
  }

  // === Time Control ===

  /// Set time directly.
  void setTime({int? newDay, int? newHour, int? newMinute}) {
    if (newDay != null) day = newDay;
    if (newHour != null) hour = newHour.clamp(0, config.hoursPerDay - 1);
    if (newMinute != null) minute = newMinute.clamp(0, 59);
    changedThisFrame = true;
  }

  /// Skip to the next occurrence of a specific hour.
  void skipToHour(int targetHour) {
    if (targetHour < 0 || targetHour >= config.hoursPerDay) return;

    if (hour < targetHour) {
      hour = targetHour;
    } else {
      hour = targetHour;
      day++;
      dayChangedThisFrame = true;
      // Reset curfew tracking for new day
      _wasPastCurfew = false;
    }
    minute = 0;
    _accumulator = 0.0;
    hourChangedThisFrame = true;
    changedThisFrame = true;

    // Update curfew edge detection
    if (_curfewHour != null) {
      final nowPastCurfew = isPastCurfew;
      if (nowPastCurfew && !_wasPastCurfew) {
        curfewTriggeredThisFrame = true;
      }
      _wasPastCurfew = nowPastCurfew;
    }

    _checkSeasonYearChange();
  }

  /// Skip to the next morning (dayStartHour).
  ///
  /// Used when player goes to sleep or passes out from curfew.
  void skipToNextMorning() {
    day++;
    hour = config.dayStartHour;
    minute = 0;
    _accumulator = 0.0;
    dayChangedThisFrame = true;
    hourChangedThisFrame = true;
    changedThisFrame = true;
    // Reset curfew tracking for new day
    _wasPastCurfew = false;

    _checkSeasonYearChange();
  }

  void _checkSeasonYearChange() {
    if (!config.useSeasons) return;

    final currentSeason = season;
    if (currentSeason != _previousSeason) {
      seasonChangedThisFrame = true;
      _previousSeason = currentSeason;

      final currentYear = year;
      if (currentYear != _previousYear) {
        yearChangedThisFrame = true;
        _previousYear = currentYear;
      }
    }
  }

  /// Pause time progression.
  void pause() => isPaused = true;

  /// Resume time progression.
  void resume() => isPaused = false;

  // === Frame Lifecycle ===

  /// Reset change tracking at frame start.
  ///
  /// Call this at the beginning of each frame before update().
  void beginFrame() {
    changedThisFrame = false;
    hourChangedThisFrame = false;
    dayChangedThisFrame = false;
    seasonChangedThisFrame = false;
    yearChangedThisFrame = false;
    curfewTriggeredThisFrame = false;
  }

  // === Serialization ===

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'day': day,
    'hour': hour,
    'minute': minute,
    if (_curfewHour != null) 'curfewHour': _curfewHour,
  };

  /// Load from JSON.
  void loadFromJson(Map<String, dynamic> json) {
    day = json['day'] as int? ?? 1;
    hour = json['hour'] as int? ?? config.dayStartHour;
    minute = json['minute'] as int? ?? 0;
    // Validate curfew hour from save data, fallback to config default if invalid
    final savedCurfew = json['curfewHour'] as int?;
    if (savedCurfew != null) {
      final minCurfew = config.dayStartHour;
      final maxCurfew = config.dayStartHour + config.hoursPerDay;
      _curfewHour =
          (savedCurfew >= minCurfew && savedCurfew <= maxCurfew)
              ? savedCurfew
              : config.defaultCurfewHour;
    } else {
      _curfewHour = config.defaultCurfewHour;
    }
    _accumulator = 0.0;
    // Reset edge detection state
    _previousSeason = season;
    _previousYear = year;
    _wasPastCurfew = isPastCurfew;
  }
}
