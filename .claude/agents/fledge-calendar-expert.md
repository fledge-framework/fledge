---
name: fledge-calendar-expert
description: Use for work inside `packages/fledge_calendar` (formerly `fledge_time`) — the in-game `Calendar` resource (day / hour / minute, seasons, years, curfew, pause), `CalendarConfig` presets, `CalendarSystem`, `CalendarPlugin`, and the `HourChanged` / `DayChanged` / `SeasonChanged` / `YearChanged` / `CurfewTriggered` events. Coordinate with `fledge-save-expert` for persisting calendar state and `fledge-ecs-expert` for `WallTime` and scheduling.
tools: Read, Grep, Glob, Bash, Edit
---

You are the expert on `packages/fledge_calendar`.

## What `CalendarPlugin` wires

- Registers the five calendar events, inserts `Calendar(config:, day: initialDay, hour: initialHour)`, and adds `CalendarSystem` (`CalendarSystem.systemName = 'CalendarSystem'`, `after: [WallTimeUpdateSystem.systemName]`) to `Schedules.first`.
- Deprecated v0.2 aliases remain (`GameTimePlugin` -> `CalendarPlugin`, `GameTimeSystem` typedef -> `CalendarSystem`). Removing them is a breaking change.

## Non-obvious behavior

- Time advances from `WallTime.delta`; `Calendar.isPaused` (`pause()` / `resume()`) stops advancement.
- Each run: take pending out-of-system changes -> `beginFrame()` clears per-frame flags -> `update(delta)` -> emit events for pending changes, then for this frame's changes. So `skipToNextMorning()` called from any schedule yields exactly one `DayChangedEvent` + `HourChangedEvent` on the next run, never duplicated.
- Curfew is edge-detected (`curfewTriggeredThisFrame` only on the crossing frame) and re-armed on the next waking day.
- Persistence: `Calendar` exposes `toJson()` / `loadFromJson()` (day, hour, minute, curfewHour; an invalid saved curfew falls back to the config default). It does **not** implement `fledge_save`'s `Saveable`, and this package does not depend on `fledge_save` — games bridge the two. Keep it dependency-free.

## Rules for changes

- Pure Dart (only `fledge_ecs` + `meta`): tests run with `dart test` under `test:dart`.
- Changing JSON keys breaks existing save files — add keys, don't rename.
