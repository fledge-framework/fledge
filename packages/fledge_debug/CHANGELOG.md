## 0.2.3

 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

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
