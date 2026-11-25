# Drifter

A minimal end-to-end vertical slice for the Fledge framework. Move a green square around a walled room, collect gold pickups, and persist the high score across runs.

![Drifter gameplay sketch](./docs/sketch.png) <!-- optional; drop a screenshot here if you capture one -->

## What it demonstrates

This is the "does everything wire up cleanly?" example. In ~500 LOC across the `lib/` tree it exercises:

| Package | Integration point |
|---|---|
| `fledge_ecs` | App + World, resources, marker components, systems ordered with `systemName` constants (`preUpdate` → `update` → `last`) |
| `fledge_render_2d` | `Transform2D` positions, `TransformPropagateSystem` registered in `preUpdate` (no plugin adds it), `Sprite` + `SpriteExtractor` + `FledgeRenderView` |
| `fledge_camera_2d` | `CameraPlugin` and a `CameraFollow` camera that scrolls the arena at 1:1 |
| `fledge_input` | `InputWidget` with a caller-owned `FocusNode`, arrow/WASD + action keys via `bindArrows`/`bindWasd`/`bindKey`, pause-on-blur |
| `fledge_physics` | `PhysicsPlugin` (velocity integration included), `Velocity` + `Collider` + `CollisionConfig` with game-defined layer bits; sensor pickups vs solid walls; `CollisionEvent` consumption |
| `fledge_ui` | The score HUD as UI entities (`UiPlugin`, `UiText`) |
| `fledge_debug` | `DebugPlugin` overlay |
| `fledge_save` | `HighScore` as an auto-discovered `Saveable` world resource; no `registerSaveable` boilerplate |

Intentionally **not** exercised: audio, networking, tilemaps, yarn, window. Add those when your game needs them; the point of this slice is a clean core loop.

## Running

From the workspace root:

```bash
# macOS / Linux
cd examples/drifter && flutter run -d macos        # or -d linux / -d windows

# Web (also embedded on the docs site at /demo/drifter)
cd examples/drifter && flutter run -d chrome
```

## Controls

| Key | Action |
|---|---|
| Arrows / WASD | Move |
| S | Save the current run (slot 0) |
| L | Load slot 0 |
| R | Reset the scene (new pickup layout, run score back to zero) |

Click the canvas when the "Click to play" overlay is visible to grab keyboard focus. The ticker only runs while the game has focus — consistent with the docs grid-game demo.

## Code map

```
lib/
├── main.dart                          Flutter entry point
├── game_widget.dart                   Widget host: InputWidget + ticker + HUD + pause overlay
├── game_app.dart                      buildApp(), spawnScene(), clearScene() — the Fledge wiring
├── components.dart                    Player / Wall / Pickup marker components
├── resources.dart                     GameBounds, RunScore, HighScore (Saveable), Load/ResetRequested
├── actions.dart                       DrifterAction enum + InputMap builder
└── systems/
    ├── input_movement_system.dart     ActionState → player Velocity
    ├── pickup_collection_system.dart  CollisionEvent on Player → despawn Pickup + score++
    ├── hud_update_system.dart         RunScore / HighScore → HUD text
    └── save_load_system.dart          S/L/R action → flags that the Flutter layer drains
```

## Integration notes

- **Register `TransformPropagateSystem` yourself.** `fledge_render_2d` has no plugin for it; drifter adds it in `Schedules.preUpdate`, or `GlobalTransform2D` stays empty.
- **Velocity units are per-frame at 60 fps**, not per-second, and `PhysicsPlugin` integrates velocity into `Transform2D` itself (`VelocityIntegrationSystem`, after collision resolution).
- **Movement systems must run before collision resolution, or the player walks through walls.** Drifter puts `InputMovementSystem` in `Schedules.preUpdate`. `test/schedule_ordering_test.dart` asserts `App.checkScheduleOrdering()` is empty: copy it into your own game.
- **Order by `systemName` constants**, e.g. `after: [CollisionDetectionSystem.systemName]`, never string literals: a typo in a literal silently orders nothing.
- **`SaveManager.save` is async** (path_provider). Fire-and-forget from the Flutter ticker listener is usually fine; await if you want to pause the game during I/O.
- **`Saveable` resources are auto-discovered**: `world.insertResource(HighScore())` puts it in the save set. `registerSaveable` is only for objects that aren't world resources.

## Tests

```bash
cd examples/drifter && flutter test
```

- `camera_follow_integration_test.dart` — the follow camera tracks the player through the real app.
- `focus_retention_test.dart` — the game keeps keyboard focus across clicks.
- `pickup_collection_test.dart` — drives the physics plugin directly, asserts pickups despawn and scores update on collision.
- `wall_collision_test.dart` — regression for the "player clips through walls" bug: holds right-arrow for 120 simulated frames against a wall and verifies velocity is clamped to zero before the collider overruns the wall face.
- `schedule_ordering_test.dart` — calls `app.checkScheduleOrdering()` on the built `App` and asserts the result is empty. Catches same-stage conflicts that would rely on registration order. Copy this pattern into your own game.
- `widget_test.dart` — HUD smoke test, pause-overlay-on-outer-focus, and arrow-key integration (key → InputWidget → ActionState → velocity → transform after N frames).
