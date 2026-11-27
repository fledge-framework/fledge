# Package Catalog

Fledge is 21 packages. Add only what your game uses. They're released
together, in lockstep: every package has the same version (currently 0.6.0),
so pin them all to the same constraint:

```yaml
dependencies:
  fledge_ecs: ^0.7.1
  fledge_render_2d: ^0.7.1
  fledge_input: ^0.7.1
```

**Pure Dart** packages need Dart 3.11+ and run anywhere Dart does, including
servers and command-line tools. **Flutter** packages need Flutter 3.50+ (Dart
3.14+). Desktop (Windows, macOS, Linux) is the primary target for everything;
web and mobile are best-effort unless noted. Each package's API reference is
at `https://pub.dev/documentation/<package>/latest/`.

Most packages provide a plugin (`app.addPlugin(...)`); see
[App & Plugins](/docs/app/app-and-plugins). Packages that draw build on
`fledge_render_2d`: add its `RenderPlugin` before their plugins.

## Core

| Package | What it is | Kind | Depends on (Fledge) | Docs |
|---|---|---|---|---|
| [fledge_ecs](https://pub.dev/packages/fledge_ecs) | The ECS: world, queries, systems, resources, events, commands, hierarchies, observers, change detection, states, schedules and the fixed timestep, `App` and plugins. Also `WallTimePlugin` (the `WallTime` clock, updated by `WallTimeUpdateSystem`) and `FrameLimiterPlugin` | Pure Dart | `fledge_ecs_annotations` | [ECS](/docs/ecs/entities-components), [Scheduling](/docs/scheduling/schedules), [App & Plugins](/docs/app/app-and-plugins), [Reflection](/docs/app/reflection) |
| [fledge_ecs_annotations](https://pub.dev/packages/fledge_ecs_annotations) | `@system`, `@component` (re-exported by `fledge_ecs`) | Pure Dart | none | [Code Generation](/docs/app/codegen) |
| [fledge_ecs_generator](https://pub.dev/packages/fledge_ecs_generator) | `build_runner` generator: `@system` functions become `System` classes. A dev dependency | Pure Dart | `fledge_ecs_annotations` | [Code Generation](/docs/app/codegen) |
| [fledge_assets](https://pub.dev/packages/fledge_assets) | `Assets<T>` store, ref-counted `Handle<T>`, `Loader<T>`, optional hot reload | Pure Dart | `fledge_ecs` | [Assets](/docs/app/assets) |

Hot reload in `fledge_assets` watches the file system, so it's for desktop
development builds only.

## Rendering and UI

| Package | What it is | Kind | Depends on (Fledge) | Docs |
|---|---|---|---|---|
| [fledge_render_2d](https://pub.dev/packages/fledge_render_2d) | The render world and extractors, `RenderPlugin`, sprites, texture atlases, animation, `Transform2D` and propagation, draw layers, `FledgeRenderView` | Flutter | `fledge_ecs`, `fledge_assets` | [Rendering Overview](/docs/rendering/overview), [Sprites & Animation](/docs/rendering/sprites-animation), [Transforms](/docs/rendering/transforms), [Pixel Art](/docs/rendering/pixel-art), [Render Graph](/docs/rendering/render-graph) |
| [fledge_camera_2d](https://pub.dev/packages/fledge_camera_2d) | Cameras and projections (orthographic, isometric, oblique), follow, shake, letterbox, parallax, transitions | Flutter | `fledge_ecs`, `fledge_render_2d` | [Cameras](/docs/rendering/cameras) |
| [fledge_lighting_2d](https://pub.dev/packages/fledge_lighting_2d) | Point, directional and spot lights and ambient light, drawn as a light map that multiplies the sprites (older additive modes remain) | Flutter | `fledge_ecs`, `fledge_assets`, `fledge_render_2d` | [Lighting](/docs/rendering/lighting) |
| [fledge_particles](https://pub.dev/packages/fledge_particles) | CPU particle emitters with pooling and presets | Flutter | `fledge_ecs`, `fledge_assets`, `fledge_render_2d` | [Particles](/docs/rendering/particles) |
| [fledge_tween](https://pub.dev/packages/fledge_tween) | Easing curves and value tweens with loop modes | Flutter | `fledge_ecs` | [Tweens](/docs/rendering/tween) |
| [fledge_ui](https://pub.dev/packages/fledge_ui) | Retained-mode in-game HUD: anchored layout, text, images, panels; tile placement helpers | Flutter | `fledge_ecs`, `fledge_assets`, `fledge_render_2d`, `fledge_camera_2d` | [HUD](/docs/ui/hud), [Tile Placement](/docs/gameplay/placement) |
| [fledge_debug](https://pub.dev/packages/fledge_debug) | Overlay (FPS, entity count, schedule-ordering report) and AABB, collider and camera-frustum gizmos | Flutter | `fledge_ecs`, `fledge_render_2d`, `fledge_camera_2d`, `fledge_physics`, `fledge_ui` | [Debug Tools](/docs/ui/debug) |

## Platform

| Package | What it is | Kind | Depends on (Fledge) | Docs |
|---|---|---|---|---|
| [fledge_input](https://pub.dev/packages/fledge_input) | Action-based input: keyboard, mouse, gamepad, input contexts, rebinding, rumble, controller-driven Flutter menus | Flutter | `fledge_ecs` | [Input](/docs/platform/input), [Controller Menus](/docs/ui/controller-menus) |
| [fledge_window](https://pub.dev/packages/fledge_window) | Windowed, borderless and fullscreen modes, window events | Flutter | `fledge_ecs` | [Window](/docs/platform/window) |
| [fledge_audio](https://pub.dev/packages/fledge_audio) | Music, sound effects, 2D positional audio and volume channels, on `flutter_soloud` | Flutter | `fledge_ecs`, `fledge_assets`, `fledge_render_2d` | [Audio](/docs/platform/audio) |

`fledge_window` is **desktop only** (built on `window_manager`).
`fledge_audio`'s backend also runs on Android, iOS and the web, untested with
Fledge.

## Gameplay

| Package | What it is | Kind | Depends on (Fledge) | Docs |
|---|---|---|---|---|
| [fledge_physics](https://pub.dev/packages/fledge_physics) | Velocity, layer-based collision detection and resolution, collision events, grid pathfinding | Flutter | `fledge_ecs`, `fledge_render_2d` | [Physics & Collision](/docs/gameplay/physics), [Pathfinding](/docs/gameplay/pathfinding) |
| [fledge_tiled](https://pub.dev/packages/fledge_tiled) | Load [Tiled](https://www.mapeditor.org/) TMX/TSX maps: tile layers, objects, colliders, terrain | Flutter | `fledge_ecs`, `fledge_assets`, `fledge_physics`, `fledge_render_2d`, `fledge_camera_2d` | [Tiled Maps](/docs/gameplay/tiled), [Rendering Tilemaps](/docs/gameplay/tiled-rendering) |
| [fledge_yarn](https://pub.dev/packages/fledge_yarn) | [Yarn Spinner](https://yarnspinner.dev/) dialogue: parse `.yarn` files, run branching conversations | Flutter | `fledge_ecs` | [Dialogue (Yarn)](/docs/gameplay/dialogue) |
| [fledge_save](https://pub.dev/packages/fledge_save) | Save slots for `Saveable` resources, with versioning and migration | Flutter | `fledge_ecs` | [Save & Load](/docs/gameplay/save) |
| [fledge_calendar](https://pub.dev/packages/fledge_calendar) | In-game calendar: days, seasons, day/night cycle, time scaling | Pure Dart | `fledge_ecs` | [Calendar](/docs/gameplay/calendar) |

`fledge_tiled` supports orthogonal, fixed-size maps. `fledge_save` writes
files with `dart:io`, so it doesn't work on the web.

## Networking

| Package | What it is | Kind | Depends on (Fledge) | Docs |
|---|---|---|---|---|
| [fledge_net](https://pub.dev/packages/fledge_net) | Host-authoritative multiplayer: replication, owned inputs, prediction and reconciliation, interpolation, RPCs, over UDP with optional AES-256-GCM | Pure Dart | `fledge_ecs` | [Networking Overview](/docs/networking/overview) and the rest of that section |
| [fledge_net_steam](https://pub.dev/packages/fledge_net_steam) | `fledge_net` over Steam Networking: relays, NAT traversal, lobbies, Steam identities | Pure Dart | `fledge_net` | [Steam](/docs/networking/steam) |

`fledge_net` uses `dart:io` UDP (IPv4): no web. `fledge_net_steam` is desktop
only, uses `dart:ffi`, needs the Steam client running and the `steam_api`
library from the Steamworks SDK shipped with your game.

## Which packages do I need?

| Building | Start with |
|---|---|
| A simulation, server or tool | `fledge_ecs` |
| A 2D game | `fledge_ecs`, `fledge_render_2d`, `fledge_input`, then `fledge_camera_2d`, `fledge_audio` and `fledge_ui` as needed |
| A tile-based game | add `fledge_tiled` and `fledge_physics` |
| A story game | add `fledge_yarn` and `fledge_save` |
| Multiplayer | add `fledge_net` (and `fledge_net_steam` for Steam) |

The [Drifter example](/docs/examples/drifter) wires up render, camera, input,
physics, save, UI and debug in one small game.
