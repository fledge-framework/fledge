# Changelog

## [0.2.2] - 2026-09-21



## [0.2.1] - 2026-09-20

### Added

- `example/example.dart` demonstrating the package's core API (pana requirement).

### Changed

- SDK floor bumped to Dart `>=3.11.0` / Flutter `>=3.41.0` (was 3.6 / 3.38). Matches the workspace-wide floor.


## [0.2.0] - 2026-09-20

### Added

- Initial release.
- FPS + entity count + schedule-ordering-ambiguity overlay rendered through `fledge_ui`.
- `DebugGizmosLayer` for AABB / collider / camera-frustum visualization.


## [0.1.0] - 2026-09-20

### Added

- Initial release. Phase 9 of the Fledge restructure — runtime
  observability MVP.
- `DebugConfig` resource — flags for FPS / entity count / ambiguity /
  timings / gizmos (AABB, collider, camera frustum) plus overlay
  styling.
- `FrameStats` resource — smoothed FPS, avg / p99 / max frame time
  from a ring-buffer of frame samples driven by `WallTime`.
- `SystemStats` resource — schedule counts and per-frame total
  wall-clock (see the README's "Per-system timings" note).
- `FrameStatsSystem` — updates `FrameStats` in `Schedules.first`.
- `SystemStatsSystem` — updates `SystemStats` in `Schedules.last`.
- `OverlayPopulateSystem` — retained-mode overlay: reuses UI entities
  across frames instead of respawning them.
- `DebugOverlayEntity` marker — attaches to overlay-owned UI nodes.
- `DebugAabbGizmo` / `DebugColliderGizmo` / `DebugCameraFrustumGizmo`
  marker components — reserved for future filtered gizmos (MVP draws
  every collider / camera when the config flag is on).
- `DebugGizmosLayer` widget — `CustomPainter` overlay for AABBs,
  collider shapes, and camera frustums.
- `DebugPlugin` — inserts resources and registers systems.

### Deferred

- Reflection-based inspector (editable component fields, entity tree)
  — needs `@reflectable` codegen + `TypeRegistry` restored.
- Per-system timings — needs a `Scheduler` hook that isn't there yet.
