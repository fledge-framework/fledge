## 0.3.1

 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_debug): auto-refresh ScheduleOrderingReport on first tick. ([0e152b9e](https://github.com/fledge-framework/fledge/commit/0e152b9e6eaf00f9f30096d9f61c1f2c7a0c777a))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
 - **FEAT**: upgrade tiled version. ([306fdb67](https://github.com/fledge-framework/fledge/commit/306fdb6708c06ff8c29a1a745a9899677bf9ce27))
 - **FEAT**: add additional examples. ([dccbc356](https://github.com/fledge-framework/fledge/commit/dccbc356dc6b7b21b04fdcc4cd2faec1f258dd8b))
 - **FEAT**: v0.2 engine restructure — 2D/2.5D desktop game engine. ([bf7c2b6c](https://github.com/fledge-framework/fledge/commit/bf7c2b6cc47837c998786f25bc87997f474c5b1d))

## 0.3.0

 - **FIX**(fledge_debug): keep an existing DebugConfig instead of overwriting it. ([8c5b3725](https://github.com/fledge-framework/fledge/commit/8c5b3725bbfd84a86f4f0d87d6a77840ab12f242))
 - **FIX**: bump versions to stable. ([13c9aa7f](https://github.com/fledge-framework/fledge/commit/13c9aa7f0d2702dabaa7088a8679c2113f8d295d))
 - **FEAT**(fledge_debug): optional overlay and a standalone stats plugin. ([aef458b1](https://github.com/fledge-framework/fledge/commit/aef458b1ff7ceb251fbb46c7d9fbe244f43939f0))
 - **FEAT**: camera-aware widget render path. ([6b8ff1b7](https://github.com/fledge-framework/fledge/commit/6b8ff1b7f1eaf6a930a73d7a4c5a0c4e26f12385))
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
