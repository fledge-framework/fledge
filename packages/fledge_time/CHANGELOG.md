# Changelog

## [0.1.11] - 2026-01-21



## [0.1.10] - 2026-01-06

## [0.1.10] - 2026-01-06

### Features

- **fledge_save:** Create fledge_save package



All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.9] - 2026-01-06

### Added

- Initial release of fledge_time
- `CalendarConfig` for configuring calendar system
- `CalendarConfig.farmingSim()` preset for farming/life simulation games (includes 2 AM curfew)
- `CalendarConfig.rpg()` preset for RPG games
- `CalendarConfig.realTime()` preset for real-time games
- `GameTime` resource with hour, minute, day, season, year tracking
- Change detection flags: `hourChangedThisFrame`, `dayChangedThisFrame`, etc.
- Day/night helpers: `isDaytime()`, `isNighttime()`, `normalizedTimeOfDay`
- Time control: `pause()`, `resume()`, `setTime()`, `skipToNextMorning()`
- Time events: `HourChangedEvent`, `DayChangedEvent`, `SeasonChangedEvent`, `YearChangedEvent`
- `GameTimePlugin` for easy integration
- `GameTimeSystem` for automatic time progression
- **Curfew system**: `curfewHour`, `isPastCurfew`, `hoursUntilCurfew`, `curfewTriggeredThisFrame`
- `CurfewTriggeredEvent` for event-based curfew handling
