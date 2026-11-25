# Debug Tools

`fledge_debug` shows what a running game is doing: frame rate and frame
times, entity and sprite counts, system-ordering ambiguities, and gizmos for
colliders and the camera view.

```yaml
dependencies:
  fledge_debug: ^0.7.0
```

Flutter 3.50+ (Dart 3.14+); desktop first, web and mobile best-effort. It
depends on `fledge_render_2d`, `fledge_camera_2d`, `fledge_physics` and
`fledge_ui`. Add `WallTimePlugin`: frame stats come from `WallTime.delta`.

There are two entry points:

- **`DebugPlugin`**: stats, an on-screen text overlay drawn with `fledge_ui`,
  and the gizmo settings for `DebugGizmosLayer`.
- **`DebugStatsPlugin`**: stats only, for games whose HUD is Flutter widgets.
  Pair it with the `DebugPerfPanel` widget.

## A performance panel in Flutter

```dart
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/widgets.dart';

void addStats(App app) => app.addPlugin(const DebugStatsPlugin());

Widget gameWithPerf(App app, {required bool showPerf}) => Stack(
  children: [
    FledgeRenderView(app: app),
    if (showPerf)
      Positioned(top: 8, left: 8, child: DebugPerfPanel(app: app)),
  ],
);
```

`DebugPerfPanel` shows FPS and frame times (average, p99, worst), the app's
tick time (from the start of `first` to the end of `last`), Flutter's build
and raster times with a count of recent frames that missed their refresh,
entity and extracted-sprite counts, and a graph of recent frame times
against the display's refresh interval. The text refreshes every
`refreshInterval` (250 ms by default); `textStyle` restyles it.

## DebugPlugin

```dart
import 'package:fledge_camera_2d/fledge_camera_2d.dart';
import 'package:fledge_debug/fledge_debug.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_ui/fledge_ui.dart';
import 'package:flutter/widgets.dart';

App buildApp() => App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(RenderPlugin())
  ..addPlugin(const CameraPlugin())
  ..addPlugin(const UiPlugin())
  ..addPlugin(const DebugPlugin(config: DebugConfig(showColliderGizmos: true)));

/// Gizmos outermost, then the UI overlay, then the game view.
Widget gameView(App app) => DebugGizmosLayer(
  app: app,
  child: FledgeUiOverlay(app: app, child: FledgeRenderView(app: app)),
);
```

`DebugPlugin(config:, overlay:)`:

- `config` is inserted as the `DebugConfig` resource, **unless one is
  already there**: a game can insert its own (say, everything off) before
  adding the plugin, and the plugin keeps it.
- `overlay` (default `true`) adds `OverlayPopulateSystem`, which keeps a few
  `fledge_ui` text entities up to date with the stats. Without `UiPlugin`
  they are never drawn, so pass `overlay: false` if you don't use
  `fledge_ui`.

It composes `DebugStatsPlugin`, so it inserts the same resources and systems,
plus `OverlayPopulateSystem` in `Schedules.preUpdate`.

## Resources

`DebugStatsPlugin` (and so `DebugPlugin`) inserts these resources, keeping
any that already exist:

| Resource | Holds |
|---|---|
| `FrameStats` | `smoothedFps`, `lastFrameSeconds`, and over a rolling window (`history`, 120 frames by default) `avgFrameSeconds`, `p99FrameSeconds`, `maxFrameSeconds`. |
| `SystemStats` | `totalFrameMicros` / `totalFrameMilliseconds` (start of `first` to end of `last`), `scheduleSystemCounts` (systems per schedule), and a `timings` map for your own measurements. |
| `ScheduleOrderingReport` | `items` (one line per ambiguity, `"<schedule>: <a> <-> <b>"`) and `count`. |

`DebugPlugin` adds the fourth, `DebugConfig`. Reading them for a custom
panel:

```dart
String perfLine(World world) {
  final frames = world.getResource<FrameStats>()!;
  final ordering = world.getResource<ScheduleOrderingReport>()!;
  final fps = frames.smoothedFps.toStringAsFixed(0);
  final p99 = (frames.p99FrameSeconds * 1000).toStringAsFixed(1);
  return '$fps fps, p99 $p99 ms, ${ordering.count} ordering issues';
}
```

### Systems

| System | Schedule |
|---|---|
| `FrameStatsSystem` | `first`, in `FirstSets.frameStart`, after `WallTimeUpdateSystem` |
| `SystemStatsStartSystem` | `first`, same phase |
| `ScheduleOrderingReportSystem` | `first`, same phase |
| `SystemStatsEndSystem` | `last` |
| `OverlayPopulateSystem` | `preUpdate` (`DebugPlugin` with `overlay: true` only) |

## Schedule-ordering ambiguities

When two systems in a schedule touch the same data and nothing orders them,
they run in registration order, which changes silently as plugins are added
(see [Ordering & Sets](/docs/scheduling/ordering-and-sets)).
`ScheduleOrderingReport` holds the output of `App.checkScheduleOrdering()`.
It's filled at build time, refreshed on the first tick against the finished
schedule, and again whenever a `RefreshScheduleOrderingReportRequested`
event is sent (the refresh happens on the next tick):

```dart
void requestOrderingRefresh(World world) => world
    .eventWriter<RefreshScheduleOrderingReportRequested>()
    .send(const RefreshScheduleOrderingReportRequested());
```

`refreshScheduleOrderingReport(app)` refreshes it immediately. The text
overlay keeps its own copy, refreshed with `refreshAmbiguityReport(app)`.
Both walk every schedule, so call them from a menu action, not every frame.

## DebugConfig

The overlay reads `showFps`, `showEntityCount`, `showOrderingAmbiguities` and
`showSystemTimings` (off by default), styled by `overlayTextColor`,
`overlayFontSize` and `overlayAnchor`. `DebugGizmosLayer` reads the gizmo
flags, all off by default:

| Flag | Draws |
|---|---|
| `showAabbGizmos` | A magenta box around each `Collider`'s bounds. |
| `showColliderGizmos` | Each collider shape in green. |
| `showCameraFrustum` | A yellow rect around what the lowest-`order` active `Camera2D` shows. |

`DebugConfig` is immutable. Change it by inserting a copy:

```dart
void toggleColliders(App app) {
  final config = app.world.getResource<DebugConfig>()!;
  app.insertResource(
    config.copyWith(showColliderGizmos: !config.showColliderGizmos),
  );
}
```

## DebugGizmosLayer

`DebugGizmosLayer(app:, child:)` paints the gizmos over `child`, in world
space through the active camera (the same mapping as the sprites). With every
gizmo flag off it returns `child` unchanged and costs nothing. It reads the
config when it builds, so rebuild it after changing the flags.

Every collider is drawn when a flag is on. The `DebugAabbGizmo`,
`DebugColliderGizmo` and `DebugCameraFrustumGizmo` marker components are
reserved for limiting gizmos to chosen entities later; today nothing reads
them. The frustum rect is the world area the widget shows through the
lowest-`order` active camera (the one `CameraPlugin` publishes), at the same
zoom as the sprites, so under a full-screen camera it outlines the widget's
own edge, drawn just inside it.

## Not there yet

- Per-system timings: the scheduler has no hook around each system's run.
  `SystemProfilerHook` is the reserved callback shape for one; until then,
  fill `SystemStats.timings` from your own wrappers.
- Entity inspection and editing at runtime.

See the [API reference](https://pub.dev/documentation/fledge_debug/latest/)
for every member.
