---
name: fledge-debug-expert
description: Use for work inside `packages/fledge_debug` — `DebugPlugin` (HUD overlay), `DebugStatsPlugin` (headless stats), `DebugConfig`, `FrameStats`, `SystemStats`, the public `ScheduleOrderingReport` resource and `RefreshScheduleOrderingReportRequested` event, and the `DebugGizmosLayer` widget (AABB / collider / camera-frustum gizmos). Coordinate with `fledge-ecs-expert` (`App.checkScheduleOrdering()`), `fledge-ui-expert` (overlay lines are UI entities), `fledge-physics-expert` (collider gizmos), and `fledge-camera-2d-expert` (camera-aware gizmos, frustum).
tools: Read, Grep, Glob, Bash, Edit
---

You are the expert on `packages/fledge_debug`.

## What the plugins wire

- `DebugStatsPlugin`: inserts `FrameStats`, `SystemStats`, `ScheduleOrderingReport` (each only if absent), registers `RefreshScheduleOrderingReportRequested`, adds `FrameStatsSystem` + `SystemStatsStartSystem` + `ScheduleOrderingReportSystem` to `Schedules.first` and `SystemStatsEndSystem` to `Schedules.last`, and snapshots the report at build time.
- `DebugPlugin`: inserts `DebugConfig` **only if absent** (a game's own config wins), adds `DebugStatsPlugin`, and (if `overlay`) `OverlayPopulateSystem` in `Schedules.preUpdate`.

## Non-obvious behavior

- `ScheduleOrderingReport` is a snapshot of `App.checkScheduleOrdering()`. `ScheduleOrderingReportSystem` re-runs it once on the first tick, then only on a refresh event. Plugins added after `DebugPlugin` need `refreshScheduleOrderingReport(app)` / `refreshAmbiguityReport(app)` or a refresh event.
- `Schedules.first` systems (`FrameStatsSystem`, `SystemStatsStartSystem`, `ScheduleOrderingReportSystem`) join `FirstSets.frameStart` and order after `WallTimeUpdateSystem.systemName`. The `FirstSets` phase chain (frameStart → platform → input → content) orders them against window/audio/input/tilemap systems, so no string-literal references to other packages' system names are needed (or wanted).
- `OverlayPopulateSystem` is in `preUpdate` deliberately so it never conflicts with a game's HUD writes in `update`. It is retained-mode: one keyed UI entity per line, text mutated in place, despawned when its key disappears.
- `DebugGizmosLayer` returns `child` unchanged when no gizmo flag is on; otherwise it draws through `withActiveCameraCanvas` so gizmos follow `ActiveCameraView`.

## Rules for changes

- Debug code must not introduce ordering ambiguities itself — assert on `App.checkScheduleOrdering()` in tests after adding a system.
- Flutter package (depends on render_2d, camera_2d, physics, ui): tests run with `flutter test`.
