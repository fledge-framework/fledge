# Debug

The `fledge_debug` package provides runtime observability for Fledge — an FPS / entity-count / ordering-ambiguity overlay drawn through `fledge_ui`, plus optional AABB / collider / camera-frustum gizmos painted on top of the game.

Reflection-based inspection (editable component fields, entity-tree drilling) is **not** in the v0.2 release — that needs `@reflectable` codegen and a full `TypeRegistry`, which is bigger than a docs phase. `fledge_debug` today is runtime observability only.

## Installation

```yaml
dependencies:
  fledge_debug: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/material.dart';

void main() {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addPlugin(const UiPlugin())
    ..addPlugin(const DebugPlugin());

  runApp(DebugGizmosLayer(
    app: app,
    child: FledgeUiOverlay(app: app, child: FledgeRenderView(app: app)),
  ));
}
```

Wrap the render view with `FledgeUiOverlay` **first**, then `DebugGizmosLayer` on the outside so gizmos paint on top of the HUD too.

## DebugPlugin

`DebugPlugin` inserts three resources — `DebugConfig`, `FrameStats`, `SystemStats` — and four systems:

| System | Schedule | Purpose |
|--------|----------|---------|
| `FrameStatsSystem` | `first` | Updates FPS and frame-time history from `WallTime`. |
| `SystemStatsStartSystem` | `first` | Snapshots start-of-frame monotonic time; refreshes per-schedule counts. |
| `SystemStatsEndSystem` | `last` | Snapshots end-of-frame monotonic time. |
| `OverlayPopulateSystem` | `preUpdate` | Mutates the retained UI entities that back the overlay. |

The plugin also captures `App.checkScheduleOrdering()` output at build time and stores it as an internal resource, so the overlay's ambiguity block reflects the current schedule graph on the first paint. Games that add plugins after `DebugPlugin` can call `refreshAmbiguityReport(app)` to update it.

## DebugConfig

Every subsystem is gated by a flag on the `DebugConfig` resource. Flip fields at runtime by reinserting an updated copy:

```dart
final cfg = app.world.getResource<DebugConfig>()!;
app.insertResource(cfg.copyWith(showAabbGizmos: true, showColliderGizmos: true));
```

Flags:

| Field | Default | Description |
|-------|---------|-------------|
| `showFps` | `true` | Smoothed FPS on the overlay. |
| `showEntityCount` | `true` | Live entity count on the overlay. |
| `showOrderingAmbiguities` | `true` | `App.checkScheduleOrdering()` output when non-empty. |
| `showSystemTimings` | `false` | Per-schedule system counts + total per-frame wall clock. |
| `showAabbGizmos` | `false` | Magenta AABB stroke around every entity with `Transform2D` + `Collider`. |
| `showColliderGizmos` | `false` | Green stroke for each collider shape (rect, ellipse, polygon, ...). |
| `showCameraFrustum` | `false` | Yellow rect for the active `Camera2D`'s visible bounds. |
| `overlayTextColor` | `white` | Text colour for every overlay line. |
| `overlayFontSize` | `11.0` | Font size for every overlay line. |
| `overlayAnchor` | `Alignment.topLeft` | Corner / edge the overlay anchors to. |

## FrameStats

Smoothed FPS, avg / p99 / max frame time from a rolling window of frame samples driven by `WallTime`. Read it directly for custom HUD widgets:

```dart
final stats = world.getResource<FrameStats>()!;
print('fps: ${stats.fps.toStringAsFixed(0)}');
print('p99: ${stats.p99FrameTimeMs.toStringAsFixed(1)}ms');
```

## SystemStats

Per-schedule system counts plus total per-frame wall clock. Per-system timings are noted as a follow-up — the scheduler doesn't yet expose the hook to wrap each system's `run` in a stopwatch. Today `SystemStats` reports:

- `totalFrameMicros` — the wall clock from `Schedules.first` start to `Schedules.last` end.
- `perSchedule[schedule].systemCount` — how many systems are registered in each schedule.

When the hook lands, `SystemStats.timings` is designed to accept `(schedule, systemName, durationMicros)` triples without an API break.

## DebugGizmosLayer

A `CustomPainter` overlay for AABBs, colliders, and the active camera's visible rect. Off by default — flip the corresponding `DebugConfig` flag to enable each one. Because it's a widget rather than a render node, it composites naturally on top of both the sprite pass and the UI overlay.

## OverlayPopulateSystem

The overlay is retained-mode. `OverlayPopulateSystem` reuses UI entities across frames, so games see stable text with no archetype churn.

It runs in `Schedules.preUpdate` so it sits before any game's HUD writes in `update` — the two never claim the same `UiText` component in the same schedule, which is a common false-positive-ambiguity source. `LayoutSystem` from `fledge_ui` still runs later in `postUpdate`, so both this frame's debug text and the game's HUD text are laid out together.

## Common patterns

### Toggle gizmos with a key

```dart
class DebugToggleSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(name: 'debug_toggle');

  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>()!;
    if (actions.justPressed(ActionId('toggleDebug'))) {
      final cfg = world.getResource<DebugConfig>()!;
      world.insertResource(cfg.copyWith(
        showAabbGizmos: !cfg.showAabbGizmos,
        showColliderGizmos: !cfg.showColliderGizmos,
        showCameraFrustum: !cfg.showCameraFrustum,
      ));
    }
  }
}
```

### Refresh the ordering-ambiguity report

After adding plugins post-`DebugPlugin`:

```dart
app.addPlugin(SomeLatePlugin());
refreshAmbiguityReport(app);
```

## See also

- [UI](/docs/plugins/ui) — the overlay is retained-mode HUD on top of `UiPlugin`.
- [System Ordering](/docs/guides/system-ordering) — what the ambiguity report is telling you.
- [Plugins Overview](/docs/plugins/overview)
