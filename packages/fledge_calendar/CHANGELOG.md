## 0.3.0

 - **FIX**(fledge_calendar): order CalendarSystem after wallTimeUpdate. ([f61ce1e6](https://github.com/fledge-framework/fledge/commit/f61ce1e69778a51f5f4ea3befe0e4b99076ee763))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: adopt CalendarPlugin. ([815b8576](https://github.com/fledge-framework/fledge/commit/815b8576d960004c378f99d379a4d0949dbdf8ef))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Changed

- SDK floor bumped to Dart `>=3.11.0` (was 3.6). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Package renamed from `fledge_time`.

### Changed

- `GameTime` renamed to `Calendar`.
- `GameTimePlugin` renamed to `CalendarPlugin`.

### Deprecated

- Old `GameTime` / `GameTimePlugin` names retained as aliases for one release.


## [0.1.14] - 2026-04-14



## [0.1.13] - 2026-04-14



## [0.1.12] - 2026-04-14



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
