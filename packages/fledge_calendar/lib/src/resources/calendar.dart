import 'package:meta/meta.dart';

import '../config/calendar_config.dart';

/// Resource tracking in-game calendar time (day/hour/minute, seasons,
/// years, curfew) with edge-detection helpers.
///
/// Distinct from `fledge_ecs`'s `WallTime` resource, which tracks
/// real-world seconds between frames. [Calendar] is the game-world
/// clock: it advances at a configurable scale (see
/// [CalendarConfig.realSecondsPerGameMinute]) and supports pause,
/// skip-to-hour, and daily reset semantics.
///
/// Provides:
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
/// final calendar = world.getResource<Calendar>()!;
/// calendar.update(deltaSeconds);
///
/// // Check for period changes
/// if (calendar.dayChangedThisFrame) {
///   // Handle daily reset
/// }
///
/// // Use for lighting
/// final brightness = calculateBrightness(calendar.normalizedTimeOfDay);
/// ```
class Calendar {
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

  // === Pending out-of-system changes ===
  //
  // Recorded by [skipToNextMorning], [skipToHour] and [setTime] so that
  // [CalendarSystem] can emit the matching events on its next run even
  // though the edge flags set by those calls are cleared by [beginFrame].
  // Each slot holds the value from *before the first* un-consumed change
  // (multiple changes coalesce). Not cleared by [beginFrame].
  int? _pendingOldHour;
  int? _pendingOldDay;
  int? _pendingOldSeason;
  int? _pendingOldYear;
  bool _pendingCurfew = false;

  /// Curfew hour (null = no curfew).
  ///
  /// Uses 24+ hour format relative to dayStartHour:
  /// - 22 = 10 PM same day
  /// - 26 = 2 AM next day (20 hours after 6 AM wake)
  int? _curfewHour;

  /// Creates a Calendar resource with optional configuration.
  Calendar({
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

      if (hour >= config.hoursPerDay) {
        // The day counter increments at midnight. Curfew tracking is NOT
        // reset here: the player's waking day runs from dayStartHour to
        // dayStartHour the next morning, so a curfew that was already
        // passed before midnight stays passed. [isPastCurfew] naturally
        // becomes false again at dayStartHour, which re-arms the trigger.
        hour = 0;
        day++;
        dayChangedThisFrame = true;
        _checkSeasonYearChange();
      }

      // Edge-detect curfew transition (was NOT past, now IS past)
      _updateCurfewEdge();
    }
  }

  /// Returns true if this call detected a curfew crossing.
  bool _updateCurfewEdge() {
    if (_curfewHour == null) return false;
    final nowPastCurfew = isPastCurfew;
    final triggered = nowPastCurfew && !_wasPastCurfew;
    if (triggered) curfewTriggeredThisFrame = true;
    _wasPastCurfew = nowPastCurfew;
    return triggered;
  }

  int _hoursSinceStart(int h) {
    final startHour = config.dayStartHour;
    return (h >= startHour)
        ? h - startHour
        : h + config.hoursPerDay - startHour;
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
    final hoursSinceStart = (hour >= startHour)
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
    final hoursSinceStart = (hour >= startHour)
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
    final hoursSinceStart = (hour >= startHour)
        ? hour - startHour
        : hour + config.hoursPerDay - startHour;
    final curfewHoursSinceStart = _curfewHour! - startHour;
    return curfewHoursSinceStart - hoursSinceStart;
  }

  // === Time Control ===
  //
  // These methods may be called from any schedule. Besides setting the
  // this-frame edge flags, they record the pre-change values so the next
  // [CalendarSystem] run emits exactly one set of Hour/Day/Season/Year
  // (and Curfew) events for the change — see [takePendingChanges].

  /// Set time directly.
  ///
  /// Records pending changes (so [CalendarSystem] emits events for them on
  /// its next run) and re-evaluates season/year state. Does not itself fire
  /// a curfew trigger; curfew is re-evaluated on the next hour tick.
  void setTime({int? newDay, int? newHour, int? newMinute}) {
    _recordPending();
    final oldHour = hour;
    final oldDay = day;
    if (newDay != null) day = newDay;
    if (newHour != null) hour = newHour.clamp(0, config.hoursPerDay - 1);
    if (newMinute != null) minute = newMinute.clamp(0, 59);
    changedThisFrame = true;
    if (hour != oldHour) hourChangedThisFrame = true;
    if (day != oldDay) dayChangedThisFrame = true;
    _checkSeasonYearChange();
  }

  /// Skip to the next occurrence of a specific hour.
  ///
  /// If [targetHour] is not later today, skips to that hour tomorrow
  /// (the day counter increments, as it would passing midnight). Fires a
  /// curfew trigger if the skip lands past curfew and curfew had not
  /// already been passed in the current waking day.
  void skipToHour(int targetHour) {
    if (targetHour < 0 || targetHour >= config.hoursPerDay) return;

    _recordPending();

    // Did the skip pass through dayStartHour (start of a new waking day)?
    var hoursSkipped = (targetHour - hour) % config.hoursPerDay;
    if (hoursSkipped == 0) hoursSkipped = config.hoursPerDay;
    if (_hoursSinceStart(hour) + hoursSkipped >= config.hoursPerDay) {
      _wasPastCurfew = false;
    }

    if (hour < targetHour) {
      hour = targetHour;
    } else {
      hour = targetHour;
      day++;
      dayChangedThisFrame = true;
    }
    minute = 0;
    _accumulator = 0.0;
    hourChangedThisFrame = true;
    changedThisFrame = true;

    // Update curfew edge detection
    if (_updateCurfewEdge()) _pendingCurfew = true;

    _checkSeasonYearChange();
  }

  /// Skip to the next morning (dayStartHour).
  ///
  /// Used when player goes to sleep or passes out from curfew.
  ///
  /// The day counter only increments if the current hour is at or after
  /// [CalendarConfig.dayStartHour]. Before that (e.g. passing out at 2 AM
  /// after the day already rolled over at midnight) it stays on the same
  /// day and just moves the clock forward to the morning.
  void skipToNextMorning() {
    _recordPending();

    final oldHour = hour;
    final oldDay = day;
    if (hour >= config.dayStartHour) day++;
    hour = config.dayStartHour;
    minute = 0;
    _accumulator = 0.0;
    changedThisFrame = true;
    if (day != oldDay) dayChangedThisFrame = true;
    if (hour != oldHour) hourChangedThisFrame = true;
    // New waking day: re-arm curfew tracking.
    _wasPastCurfew = isPastCurfew;

    _checkSeasonYearChange();
  }

  /// Consume and clear changes made by [skipToNextMorning], [skipToHour]
  /// or [setTime] since the last call.
  ///
  /// Returns null if nothing is pending. [CalendarSystem] calls this at
  /// the start of each run and emits events for the returned changes;
  /// games using [CalendarSystem] should not call it themselves.
  CalendarPendingChanges? takePendingChanges() {
    final oldHour = _pendingOldHour;
    if (oldHour == null) return null;
    final changes = CalendarPendingChanges(
      oldHour: oldHour,
      oldDay: _pendingOldDay!,
      oldSeason: _pendingOldSeason!,
      oldYear: _pendingOldYear!,
      curfewTriggered: _pendingCurfew,
    );
    _clearPending();
    return changes;
  }

  void _recordPending() {
    _pendingOldHour ??= hour;
    _pendingOldDay ??= day;
    _pendingOldSeason ??= season;
    _pendingOldYear ??= year;
  }

  void _clearPending() {
    _pendingOldHour = null;
    _pendingOldDay = null;
    _pendingOldSeason = null;
    _pendingOldYear = null;
    _pendingCurfew = false;
  }

  void _checkSeasonYearChange() {
    if (!config.useSeasons) return;

    final currentSeason = season;
    if (currentSeason != _previousSeason) {
      seasonChangedThisFrame = true;
      _previousSeason = currentSeason;
    }

    final currentYear = year;
    if (currentYear != _previousYear) {
      yearChangedThisFrame = true;
      _previousYear = currentYear;
    }
  }

  /// Pause time progression.
  void pause() => isPaused = true;

  /// Resume time progression.
  void resume() => isPaused = false;

  // === Frame Lifecycle ===

  /// Reset change tracking at frame start.
  ///
  /// Call this at the beginning of each frame before update(). Does not
  /// clear pending out-of-system changes (see [takePendingChanges]).
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
      _curfewHour = (savedCurfew >= minCurfew && savedCurfew <= maxCurfew)
          ? savedCurfew
          : config.defaultCurfewHour;
    } else {
      _curfewHour = config.defaultCurfewHour;
    }
    _accumulator = 0.0;
    _clearPending();
    // Reset edge detection state
    _previousSeason = season;
    _previousYear = year;
    _wasPastCurfew = isPastCurfew;
  }
}

/// Changes made to a [Calendar] outside [CalendarSystem] (via
/// [Calendar.skipToNextMorning], [Calendar.skipToHour] or
/// [Calendar.setTime]) that have not yet been turned into events.
///
/// Returned by [Calendar.takePendingChanges]. Each `old*` value is the
/// calendar's value before the first un-consumed change.
@immutable
class CalendarPendingChanges {
  /// Hour before the change.
  final int oldHour;

  /// Day before the change.
  final int oldDay;

  /// Season index before the change.
  final int oldSeason;

  /// Year before the change.
  final int oldYear;

  /// Whether a change crossed the curfew (e.g. [Calendar.skipToHour]).
  final bool curfewTriggered;

  /// Creates a pending-changes snapshot.
  const CalendarPendingChanges({
    required this.oldHour,
    required this.oldDay,
    required this.oldSeason,
    required this.oldYear,
    this.curfewTriggered = false,
  });
}

/// Deprecated alias for [Calendar].
///
/// Renamed to [Calendar] in v0.2 (the package moved from `fledge_time`
/// to `fledge_calendar`). Update call sites to [Calendar]; this typedef
/// will be removed in a future release.
@Deprecated('Renamed to Calendar in v0.2. Use Calendar instead.')
typedef GameTime = Calendar;
