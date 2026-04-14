# Drifter

A minimal end-to-end vertical slice for the Fledge framework. Move a green square around a walled room, collect gold pickups, and persist the high score across runs.

![Drifter gameplay sketch](./docs/sketch.png) <!-- optional; drop a screenshot here if you capture one -->

## What it demonstrates

This is the "does everything wire up cleanly?" example. In ~500 LOC across the `lib/` tree it exercises:

| Package | Integration point |
|---|---|
| `fledge_ecs` | App + World, resources, marker components, systems, stage ordering (`preUpdate` → `update` → `last`) |
| `fledge_render_2d` | `Transform2D` positions, `TransformPropagateSystem` wired manually (there's no plugin) |
| `fledge_render` | `RenderPlugin` + `Extractors` + a custom `Extractor` to build a `RenderWorld` snapshot each frame |
| `fledge_input` | `InputWidget` with a caller-owned `FocusNode`, arrow/WASD + action keys via `bindArrows`/`bindWasd`/`bindKey`, pause-on-blur |
| `fledge_physics` | `Velocity` + `Collider` + `CollisionConfig` with game-defined layer bits; sensor pickups vs solid walls; `CollisionEvent` consumption |
| `fledge_tiled` | Source of `Collider` / `RectangleShape` (yes — the shapes live here, not in `fledge_physics`) |
| `fledge_save` | `HighScore` as an auto-discovered `Saveable` world resource; no `registerSaveable` boilerplate |

Intentionally **not** exercised: audio, networking, tilemaps, yarn, window. Add those when your game needs them; the point of this slice is a clean core loop.

## Running

From the workspace root:

```bash
# macOS / Linux
cd examples/drifter && flutter run -d macos        # or -d linux / -d windows

# Web
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
├── extraction.dart                    Main-world → render-world snapshot extractors
├── render/game_painter.dart           Reads ONLY the render world; draws via Canvas primitives
└── systems/
    ├── input_movement_system.dart     ActionState → player Velocity
    ├── velocity_apply_system.dart     Integrates Velocity into Transform2D (post collision resolution)
    ├── pickup_collection_system.dart  CollisionEvent on Player → despawn Pickup + score++
    └── save_load_system.dart          S/L/R action → flags that the Flutter layer drains
```

## Integration notes (things that bit during the build)

- **No `Transform2DPlugin`.** `fledge_render_2d` ships `TransformPropagateSystem` but no plugin; register it manually in `CoreStage.preUpdate` or `GlobalTransform2D` stays empty.
- **Velocity units are per-frame at 60 fps**, not per-second. `CollisionResolutionSystem` scales velocity by `dt / 0.01667`, so `VelocityApplySystem` here does the same so the value resolution *clamped* is the value you integrate.
- **`Collider` lives in `fledge_tiled`**, not `fledge_physics`. You need both packages to get physical shapes.
- **`fledge_physics` doesn't integrate velocity for you** — it only clamps it against solids. The game owns the `transform.translation += velocity * dt` step (here: `VelocityApplySystem`).
- **Movement systems must run before collision resolution, or the player walks through walls.** The scheduler serialises same-stage conflicts by registration order; `PhysicsPlugin` lands first, so anything that writes `Velocity` in `CoreStage.update` runs *after* `collision_resolution` and its clamping is discarded. Drifter puts `InputMovementSystem` in `CoreStage.preUpdate` to make this impossible. `test/schedule_ordering_test.dart` asserts the schedule has zero registration-order ambiguities — that test would have failed loudly on the buggy ordering, and it's a template you can copy into your own game.
- **`SaveManager.save` is async** (path_provider). Fire-and-forget from the Flutter ticker listener is usually fine; await if you want to pause the game during I/O.
- **`Saveable` resources are auto-discovered** as of `fledge_save` ≥ 0.1.13 — just `world.insertResource(HighScore())` and it's in the save set. No `registerSaveable` needed for world resources.
- **System names referenced in `before:` / `after:` are the registered snake_case names**, not the Dart class names. `collision_resolution`, `collision_detection`, `collision_cleanup`, `inputPolling`, `actionResolution`, etc. A typo silently no-ops; verify with `App.checkScheduleOrdering()`.

## Tests

```bash
cd examples/drifter && flutter test
```

- `pickup_collection_test.dart` — drives the physics plugin directly, asserts pickups despawn and scores update on collision.
- `wall_collision_test.dart` — regression for the "player clips through walls" bug: holds right-arrow for 120 simulated frames against a wall and verifies velocity is clamped to zero before the collider overruns the wall face.
- `schedule_ordering_test.dart` — calls `app.checkScheduleOrdering()` on the built `App` and asserts the result is empty. Catches same-stage conflicts that would rely on registration order. Copy this pattern into your own game.
- `widget_test.dart` — HUD smoke test, pause-overlay-on-outer-focus, and arrow-key integration (key → InputWidget → ActionState → velocity → transform after N frames).
