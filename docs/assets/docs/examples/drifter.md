# Drifter

Drifter is a small but complete Flutter game: move a green square around a
walled room, collect the gold pickups, and keep a high score between runs. It
exists to show the main packages wired together in one place, in about 500
lines.

You can play it on this site at [/demo/drifter](/demo/drifter).

Source: [`examples/drifter`](https://github.com/fledge-framework/fledge/tree/main/examples/drifter)
(Flutter 3.50+, Dart 3.14+).

## Running it

From a clone of the repository, after `melos bootstrap`:

```bash
cd examples/drifter
flutter run -d macos     # or -d windows, -d linux
flutter test             # its test suite
```

CI builds it as a release desktop app on Windows, macOS and Linux, and the
docs site's web build includes it.

| Key | Action |
|---|---|
| Arrows / WASD | Move |
| S | Save (slot 0) |
| L | Load slot 0 |
| R | New layout, run score back to zero |

The game pauses when it loses keyboard focus; click the canvas to resume.
Saving uses files, so S and L don't persist anything in the browser demo.

## What it uses

| Package | How |
|---|---|
| `fledge_ecs` | `App`, resources, marker components (`Player`, `Wall`, `Pickup`), five game systems in `preUpdate` and `update` |
| `fledge_render_2d` | `RenderPlugin`, `Transform2D` + `TransformPropagateSystem`, `Sprite`s tinted from a 1×1 white texture, `SpriteExtractor`, `FledgeRenderView` |
| `fledge_camera_2d` | `CameraPlugin`, a `Camera2D` with `CameraFollow` on the player |
| `fledge_input` | An `InputMap` with `bindArrows`/`bindWasd`/`bindKey`, `InputPlugin.simple`, `InputWidget` with a caller-owned `FocusNode` |
| `fledge_physics` | `PhysicsPlugin`, `Velocity`, `Collider` + `RectangleShape`, `CollisionConfig` layers, sensor pickups, `CollisionEvent`s |
| `fledge_save` | `SavePlugin` and a `Saveable` `HighScore` resource |
| `fledge_ui` | `UiPlugin`, two anchored `UiText` labels for the in-canvas score, `FledgeUiOverlay` |
| `fledge_debug` | `DebugPlugin` (FPS, entity count, schedule-ordering report) and `DebugGizmosLayer` |

It doesn't use audio, lighting, particles, tilemaps, dialogue, networking or
window management.

## Code map

| File | What's in it |
|---|---|
| `lib/main.dart` | `runApp` |
| `lib/game_widget.dart` | `DrifterWidget`: the ticker, focus handling, save/load/reset draining, the widget tree |
| `lib/game_app.dart` | `buildApp()`, `spawnScene()`, `clearScene()`: all the Fledge wiring |
| `lib/components.dart` | Marker components |
| `lib/resources.dart` | `GameBounds`, `RunScore`, `HighScore`, `LoadRequested`, `ResetRequested` |
| `lib/actions.dart` | The `DrifterAction` enum and input map |
| `lib/systems/` | `InputMovementSystem`, `SaveLoadSystem`, `PickupCollectionSystem`, `HudUpdateSystem` |

## Building the app

`buildApp` adds the plugins, the game's resources and its systems:

```dart fragment
App buildApp({SaveConfig? saveConfig}) {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(RenderPlugin())
    ..addPlugin(const CameraPlugin())
    ..addPlugin(
      InputPlugin.simple(
        context: InputContext(name: 'gameplay', map: buildInputMap()),
      ),
    )
    ..addPlugin(PhysicsPlugin())
    ..addPlugin(
      SavePlugin(
        config: saveConfig ?? const SaveConfig(gameDirectory: 'Drifter'),
      ),
    )
    ..addPlugin(const UiPlugin())
    // DebugPlugin's default config paints FPS + entity count +
    // `checkScheduleOrdering()` output. AABB / collider / camera-
    // frustum gizmos are opt-in — flip a flag on `DebugConfig` from
    // a debug menu (or the widget below) to enable them.
    ..addPlugin(const DebugPlugin())
    ..insertResource(const GameBounds())
    ..insertResource(RunScore())
    ..insertResource(HighScore()) // auto-discovered via Saveable mixin
    ..insertResource(LoadRequested())
    ..insertResource(ResetRequested())
    // preUpdate — runs before every update-stage physics system:
    //  - TransformPropagateSystem: GlobalTransform2D fresh before anyone reads it.
    //  - SaveLoadSystem: converts input actions to save/load/reset flags.
    //  - InputMovementSystem: MUST run before CollisionResolutionSystem so
    //    resolution clamps *this* frame's velocity, not last frame's.
    //    Putting this in Schedules.update next to physics looks innocent
    //    but silently lets the player walk through walls: the scheduler
    //    orders within a schedule by conflict + insertion order, and the
    //    physics plugin was added first, so it wins the velocity race.
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate)
    ..addSystem(SaveLoadSystem(), schedule: Schedules.preUpdate)
    ..addSystem(InputMovementSystem(), schedule: Schedules.preUpdate)
    ..addSystem(PickupCollectionSystem(), schedule: Schedules.update)
    // HudUpdateSystem writes UiText.text before LayoutSystem runs in
    // postUpdate, so the extractor sees this frame's text.
    ..addSystem(HudUpdateSystem(), schedule: Schedules.update);

  // ... sprite extractor and solid-colour texture, below ...
  return app;
}
```

Points worth copying:

- **Movement runs before physics.** `PhysicsPlugin` (in its default
  `PhysicsMode.variable`) resolves collisions in `update`, clamping each
  `Velocity` against walls and then integrating it into `Transform2D`.
  `InputMovementSystem` writes `Velocity` from input, so it's registered in
  `preUpdate`, where it's guaranteed to run first; otherwise the clamp could
  run on last frame's velocity and the player would walk through walls.
  Games that need deterministic physics pass
  `PhysicsConfig(mode: PhysicsMode.fixed)` to run it in `fixedUpdate` instead
  (see [Physics & Collision](/docs/gameplay/physics)).
- **`TransformPropagateSystem` is registered by hand**, in `preUpdate`: there
  is no transform plugin, and without it `GlobalTransform2D` never updates.
- **The HUD system runs in `update`**, before `fledge_ui`'s layout in
  `postUpdate`, so this frame's text is what gets drawn.
- `PickupCollectionSystem` reads the `CollisionEvent`s produced by the
  physics plugin's detection system and is ordered after it, and
  `HudUpdateSystem` is ordered after `PickupCollectionSystem`, so
  `test/schedule_ordering_test.dart` finds no ambiguity.

Then it registers the sprite extractor and a white pixel that every sprite
tints with `Sprite.color`:

```dart fragment
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // Register a 1×1 white pixel under the reserved solid-colour
  // handle. Drifter's sprites tint this via `Sprite.color`, so
  // walls/player/pickups get their colour without a real atlas.
  final textures = app.world.getResource<Assets<Texture>>()!;
  textures.addWithId(
    const HandleId(kSolidColorTextureId, debugLabel: 'solid_color'),
    Texture(createSolidColorImageSync(const Color(0xFFFFFFFF)), 1, 1),
  );
```

Entities are spawned by `spawnScene` (walls, player, pickups, the follow
camera, the HUD labels) after the app is built, and `clearScene` despawns
them for a reset.

## Input

`lib/actions.dart` in full:

```dart
import 'package:flutter/services.dart';
import 'package:fledge_input/fledge_input.dart';

/// Logical actions the player can trigger.
enum DrifterAction {
  /// WASD / arrow keys → vector2 movement.
  move,

  /// Save the current state to slot 0.
  save,

  /// Load slot 0 into the current state.
  load,

  /// Wipe the current run and start over.
  reset,
}

/// Build the input map used by the game. Exposed as a function so tests
/// can reuse it without constructing a full plugin.
InputMap buildInputMap() => InputMap.builder()
    .bindArrows(ActionId.fromEnum(DrifterAction.move))
    .bindWasd(ActionId.fromEnum(DrifterAction.move))
    .bindKey(LogicalKeyboardKey.keyS, ActionId.fromEnum(DrifterAction.save))
    .bindKey(LogicalKeyboardKey.keyL, ActionId.fromEnum(DrifterAction.load))
    .bindKey(LogicalKeyboardKey.keyR, ActionId.fromEnum(DrifterAction.reset))
    .build();
```

Systems read `ActionState`: `InputMovementSystem` takes
`vector2Value(move)` and normalises it, and `SaveLoadSystem` checks
`justPressed` for save, load and reset. See [Input](/docs/platform/input).

## Saving

The high score is a resource that mixes in `Saveable`. `SavePlugin` finds
`Saveable` resources on its own, so inserting it is all the registration it
needs:

```dart
import 'package:fledge_save/fledge_save.dart';

/// Highest pickup count ever achieved. Persisted across runs via
/// [Saveable] — `fledge_save` auto-discovers this when it walks the
/// world's resources at save time.
class HighScore with Saveable {
  int value = 0;

  @override
  String get saveKey => 'drifter.highScore';

  @override
  Map<String, dynamic> toSaveJson() => {'value': value};

  @override
  void loadFromSaveJson(Map<String, dynamic> json) {
    value = (json['value'] as num?)?.toInt() ?? 0;
  }
}
```

`SaveLoadSystem` only sets flags (`SaveManager.requestSave()`,
`LoadRequested.pending`). The widget sees them after each tick and starts
`SaveManager.save`/`load` without awaiting them, so disk I/O never runs inside
a frame. See [Save & Load](/docs/gameplay/save).

## The widget

`DrifterWidget` ticks the app from an `AnimationController` that only runs
while the `InputWidget` has focus, and drains the save/load/reset requests
after each tick:

```dart fragment
  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!focused && _ticker.isAnimating) {
      _ticker.stop();
    }
    setState(() {});
  }

  void _gameLoop() {
    _app.tick();

    // Drain save/load/reset requests produced by SaveLoadSystem.
    final saveManager = _world.getResource<SaveManager>();
    if (saveManager?.saveRequested ?? false) {
      saveManager!.clearSaveRequest();
      // Fire-and-forget; we don't want to block the ticker on disk I/O.
      // Surface success/failure by reading the Future if desired.
      saveManager.save(_world);
    }

    final load = _world.getResource<LoadRequested>();
    if (load?.pending ?? false) {
      load!.pending = false;
      saveManager?.load(_world);
    }

    final reset = _world.getResource<ResetRequested>();
    if (reset?.pending ?? false) {
      reset!.pending = false;
      clearScene(_app);
      spawnScene(_app);
    }

    setState(() {});
  }
```

It calls `app.tick()` without awaiting it, which is fine while every system
is synchronous. [Your First App](/docs/getting-started/first-app#the-frame-loop)
shows a stricter loop that awaits the tick, reports errors and feeds
`WallTime` the vsync clock.

The canvas is three layers: `FledgeRenderView` draws the sprites,
`FledgeUiOverlay` the HUD labels, and `DebugGizmosLayer` the debug overlay
and gizmos.

## Tests

`flutter test` runs:

| Test | Checks |
|---|---|
| `schedule_ordering_test.dart` | `app.checkScheduleOrdering()` is empty. Copy this one into your game |
| `wall_collision_test.dart` | Holding right against a wall for 120 frames never lets the player through |
| `pickup_collection_test.dart` | Touching a pickup despawns it and updates the scores; the high score survives a reset |
| `camera_follow_integration_test.dart` | The camera follows the player |
| `focus_retention_test.dart` | Clicking the focused canvas doesn't lose focus |
| `widget_test.dart` | The HUD boots, losing focus shows the overlay, a held arrow key moves the player |

## See also

- [Tutorial: Snake](/docs/getting-started/tutorial-snake)
- [Rendering Overview](/docs/rendering/overview)
- [Package Catalog](/docs/app/packages)
