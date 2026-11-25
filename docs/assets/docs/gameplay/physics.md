# Physics

`fledge_physics` is collision for 2D, top-down and tile-based games: moving
bodies stop at walls and slide along them, sensors report what entered them,
and layers decide what touches what. It isn't a rigid-body engine. There's no
gravity, mass, forces, bounce or rotation: you set each body's velocity, and
the plugin stops it going where it can't.

It also contains the grid pathfinder, covered on its own page:
[Pathfinding](/docs/gameplay/pathfinding).

## What you need

```yaml
dependencies:
  fledge_physics: ^0.6.0
  fledge_render_2d: ^0.6.0 # Transform2D
```

- **Flutter 3.50+** (Dart `^3.14`). Positions come from `Transform2D` in
  `fledge_render_2d`, so import that package too.
- **Platforms**: desktop first (Windows, macOS, Linux). The package is plain
  Dart on top of `fledge_render_2d` and has no platform code, so web and
  mobile should work too, but they aren't tested.
- **A clock**: the default (variable) mode scales movement by `WallTime`, so
  add `WallTimePlugin`. Without it, nothing moves. Fixed mode uses the
  `FixedTimestep` that every `App` already has.

## Quick start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_physics/fledge_physics.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';

void main() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(const PhysicsPlugin());

  // A wall: a collider with no Velocity is static.
  app.world.spawn()
    ..insert(Transform2D.from(100, 50))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 100, height: 20)))
    ..insert(const CollisionConfig.solid());

  // A trigger zone: reports overlaps, never blocks.
  app.world.spawn()
    ..insert(Transform2D.from(200, 100))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 50, height: 50)))
    ..insert(const CollisionConfig.sensor());

  // The player: a collider with Velocity is dynamic.
  app.world.spawn()
    ..insert(Transform2D.from(100, 120))
    ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 16, height: 16)))
    ..insert(Velocity(0, -2));

  await app.run();
}
```

The player moves up 2 pixels per 60 Hz frame, stops under the wall, and stays
there.

<!-- snippet-setup
class Player {}

class Coin {}

class Health {
  int hp = 3;
}

/// Where the player wants to go this frame, -1..1 on each axis
/// (written by your input code).
class MoveIntent {
  double x = 0, y = 0;
}

abstract class GameLayers {
  static const int solid = CollisionLayers.solid;
  static const int trigger = CollisionLayers.trigger;
  static const int player = CollisionLayers.gameLayersStart << 0;
  static const int enemy = CollisionLayers.gameLayersStart << 1;
  static const int projectile = CollisionLayers.gameLayersStart << 2;
}

class PlayerMovementSystem extends System {
  static const String systemName = 'player_movement';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Player>()},
    writes: {ComponentId.of<Velocity>()},
    resourceReads: {MoveIntent},
  );

  @override
  void run(World world) {
    final intent = world.getResource<MoveIntent>();
    if (intent == null) return;
    for (final (_, _, velocity) in world.query2<Player, Velocity>().iter()) {
      velocity.x = intent.x * velocity.max;
      velocity.y = intent.y * velocity.max;
    }
  }
}
-->

## How it works

Every entity with a `Transform2D` and a `Collider` takes part:

| Kind | Components | Behaviour |
|---|---|---|
| **Static** | `Transform2D` + `Collider` | Walls and obstacles. Blocks dynamic bodies. |
| **Dynamic** | `Transform2D` + `Collider` + `Velocity` | Moves by its velocity; blocked by static colliders. |
| **Sensor** | either, with `CollisionConfig.sensor()` | Never blocks; still produces collision events. |

The plugin runs three systems, one after the other, each step:

1. **`CollisionResolutionSystem`** looks at where each moving body would end
   up and zeroes the axis of its `Velocity` that would take it into a static
   collider. Blocked on one axis only, it keeps the other, so a body pushed
   diagonally into a wall slides along it.
2. **`VelocityIntegrationSystem`** moves `Transform2D.translation` by the
   velocity, after resolution zeroed any blocked axis.
3. **`CollisionDetectionSystem`** finds every pair of colliders that now
   overlap and sends a `CollisionEvent` for each.

Resolution writes to your `Velocity`: after a frame against a wall, the
blocked axis is 0. Set the velocity from input every frame rather than adding
to it.

### Velocity units

`Velocity(x, y)` is in **pixels per 60 Hz frame**, whatever the real frame
rate or step: `Velocity(0, 4)` moves 240 pixels a second. The plugin scales
it by `dt / physicsReferenceFrameSeconds` (one 60 Hz frame, 16.667 ms).

| Member | Meaning |
|---|---|
| `x`, `y` | Velocity, mutable |
| `max` | Top speed (default 4), a setting for your movement code (`velocity.x = intent.x * velocity.max`). The physics systems don't enforce it |
| `isMoving` | `x` or `y` is non-zero |
| `reset()` | Zero both axes |
| `Velocity.stationary(max: 5)` | Starts at rest |

### Shapes

A `Collider` holds one or more `CollisionShape`s, with coordinates relative
to the entity's `Transform2D.translation`:

```dart
final player = Collider.single(
  RectangleShape(x: -8, y: -8, width: 16, height: 16),
);
final table = Collider(
  shapes: [
    RectangleShape(x: 0, y: 0, width: 48, height: 8), // top
    RectangleShape(x: 4, y: 8, width: 6, height: 16), // legs
    RectangleShape(x: 38, y: 8, width: 6, height: 16),
  ],
);
final pillar = Collider.single(
  EllipseShape(centerX: 16, centerY: 16, radiusX: 16, radiusY: 16),
);
```

The shape types are `RectangleShape`, `EllipseShape` (also
`EllipseShape.fromBounds`), `PolygonShape`, `PolylineShape` and `PointShape`.
Most of them come from Tiled maps (see [Tiled](/docs/gameplay/tiled)).

Limits to know about:

- **Every shape collides as its axis-aligned bounding box.** A circle or a
  polygon collides as the rectangle around it. Build curved or sloped walls
  from several rectangles, or accept the boxy edges.
- **A moving body blocks as one box**: the bounding box of all its shapes
  (`Collider.bounds`). Detection checks shape against shape.
- **Only `translation` counts.** Rotation and scale on `Transform2D` are
  ignored, and so is the hierarchy: physics reads the entity's own
  `Transform2D`, not `GlobalTransform2D`, so put colliders on top-level
  entities.
- **Movement isn't swept.** Resolution checks where a body ends up, not the
  path there, so a body moving further in one step than a wall is thick can
  pass through it. Keep walls thicker than your fastest per-step move.
- **Nothing pushes bodies apart.** A dynamic body that starts inside a wall
  (spawned there, or teleported) is blocked in every direction and can't
  move out. Place bodies clear of walls.
- **Rotated rectangles collide as their bounding box.**
  `RectangleShape.rotation` turns the rectangle clockwise about its `x`, `y`
  corner, as Tiled rotates objects, and `bounds` is the smallest axis-aligned
  box around the result (a 10×10 square at 45° is about 14.1 across). That
  box is what collides.
- Edges that only touch don't count as overlapping.

## Moving things: system ordering

**Anything that writes `Velocity` (your input system, AI steering, knockback)
must run before `CollisionResolutionSystem`.** Otherwise resolution clamps
last frame's velocity, your system then writes a velocity into the wall, and
integration moves the body through it. It compiles and runs; the player just
walks through walls.

Pick one of these:

```dart-tabs
// @tab preUpdate (simplest)
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(const PhysicsPlugin())
  ..insertResource(MoveIntent())
  ..addSystem(PlayerMovementSystem(), schedule: Schedules.preUpdate);
// @tab before: in update
class SteeringSystem extends System {
  static const String systemName = 'steering';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Velocity>()},
    before: const [CollisionResolutionSystem.systemName],
  );

  @override
  void run(World world) {
    for (final (_, velocity) in world.query1<Velocity>().iter()) {
      velocity.x *= 0.9; // e.g. friction
    }
  }
}
```

In variable mode the physics systems also join the `UpdateSets.simulate` set,
so a system in `Schedules.update` can join `UpdateSets.receive` (which runs
before it) instead of naming the system. In fixed mode they run in
`Schedules.fixedUpdate` and join no set (`UpdateSets` only orders
`Schedules.update`).

In [fixed mode](#fixed-timestep-mode), use `Schedules.fixedPreUpdate`, or
`before: [CollisionResolutionSystem.systemName]` in `Schedules.fixedUpdate`.

Always order against the `systemName` constants, never string literals:

| System | `systemName` | Reads | Writes |
|---|---|---|---|
| `CollisionResolutionSystem` | `'collision_resolution'` | `Transform2D`, `Collider`, `CollisionConfig` | `Velocity` |
| `VelocityIntegrationSystem` | `'velocity_integration'` | `Velocity` | `Transform2D` |
| `CollisionDetectionSystem` | `'collision_detection'` | `Transform2D`, `Collider`, `CollisionConfig` | `CollisionEvent` (event) |

Their order among themselves is declared with `after:`, so it doesn't depend on
the order plugins are added.

To catch a missing `before:`, call `App.checkScheduleOrdering()` in a test. It
lists every conflicting pair of systems whose order falls back to registration
order:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(const PhysicsPlugin())
  ..insertResource(MoveIntent())
  ..addSystem(PlayerMovementSystem(), schedule: Schedules.preUpdate);

final issues = app.checkScheduleOrdering();
assert(issues.isEmpty, issues.join('\n'));
```

See [Ordering & Sets](/docs/scheduling/ordering-and-sets).

## Collision events

`CollisionEvent` is an [event](/docs/ecs/events), not a component. The plugin
registers it; read it with `world.eventReader<CollisionEvent>()`:

```dart
class CoinPickupSystem extends System {
  static const String systemName = 'coin_pickup';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Player>(), ComponentId.of<Coin>()},
    eventReads: {CollisionEvent},
  );

  @override
  void run(World world) {
    final commands = Commands();
    for (final hit in world.eventReader<CollisionEvent>().read()) {
      final player = world.has<Player>(hit.entityA)
          ? hit.entityA
          : world.has<Player>(hit.entityB)
          ? hit.entityB
          : null;
      if (player == null) continue;
      final coin = hit.otherOf(player)!;
      if (world.has<Coin>(coin)) commands.despawn(coin);
    }
    commands.apply(world);
  }
}
```

| Member | Meaning |
|---|---|
| `entityA`, `entityB` | The two entities. One event per pair, in no particular order |
| `otherOf(entity)` | The other side of the pair, or `null` if `entity` isn't in it |
| `involves(entity)` | Whether `entity` is either side |

What to expect:

- **Every overlapping pair, every step**, while they overlap: not just when
  they first touch. For a one-shot trigger, remember what you've already
  handled (a flag on a component, or a set of pairs in a resource).
- **Solid and sensor alike.** A body pressed against a wall overlaps it only
  if it actually got inside, and resolution stops it short, so walls usually
  produce no events. Sensors, which don't block, do.
- **Dynamic pairs too**, even ones that don't block each other, and static
  pairs (two overlapping walls) as well. Filter with [layers](#layers).
- **One frame late.** Events are double-buffered: those sent during frame N
  are read in frame N + 1, wherever the reader runs.
- **In fixed mode**, detection runs once per fixed step, so a frame with two
  steps sends each pair twice, and a frame with no steps sends nothing. See
  [Events and the fixed timestep](/docs/ecs/events#events-and-the-fixed-timestep).

Detection uses a spatial hash (a uniform grid) as its broad phase, so only
colliders in the same grid cells are tested against each other. Set the cell
size with `PhysicsConfig.spatialHashCellSize` (default 64); about twice your
typical collider size works well. Resolution doesn't use the hash: it tests
each moving body against every blocker, which is fine for the tens to low
hundreds of moving bodies a typical top-down game has.

## Layers

`CollisionConfig` puts an entity on one or more layers (`layer`, what it
**is**) and says which layers it interacts with (`mask`). Two entities
interact only if each one's mask includes the other's layer:

```text
(A.layer & B.mask) != 0 && (B.layer & A.mask) != 0
```

This applies to both blocking and events. An entity without a
`CollisionConfig` is on every layer, interacts with every layer, and blocks.

`CollisionLayers` defines the framework layers. Bits 0 to 7 are reserved;
your own layers start at `gameLayersStart` (bit 8):

| Constant | Value |
|---|---|
| `CollisionLayers.solid` | `0x0001`, walls and terrain |
| `CollisionLayers.trigger` | `0x0002`, sensors |
| `CollisionLayers.all` | `0xFFFFFFFF` |
| `CollisionLayers.none` | `0` |
| `CollisionLayers.gameLayersStart` | `0x0100` |

```dart
abstract class MyLayers {
  static const int player = CollisionLayers.gameLayersStart << 0; // 0x0100
  static const int enemy = CollisionLayers.gameLayersStart << 1; // 0x0200
  static const int projectile = CollisionLayers.gameLayersStart << 2; // 0x0400
}
```

```dart
// The player hits walls, triggers and enemies.
const player = CollisionConfig(
  layer: GameLayers.player,
  mask: GameLayers.solid | GameLayers.trigger | GameLayers.enemy,
);

// A projectile reports hits on enemies and passes through everything else.
const projectile = CollisionConfig(
  layer: GameLayers.projectile,
  mask: GameLayers.enemy,
  isSensor: true,
);

// A door trigger that only notices the player.
const door = CollisionConfig.sensor(
  layer: GameLayers.trigger,
  mask: GameLayers.player,
);
```

| Constructor | `layer` default | `mask` default | Notes |
|---|---|---|---|
| `CollisionConfig()` | `all` | `all` | Takes every option |
| `CollisionConfig.solid()` | `solid` | `all` | Blocks; takes `blocksDynamic`, `yieldAfter` |
| `CollisionConfig.sensor()` | `trigger` | `all` | Never blocks |

Remember the mask goes both ways: an enemy that should block the player needs
the player's layer in its own mask as well.

## Bodies blocking each other

By default dynamic bodies pass through each other; only static colliders block.
Set `blocksDynamic: true` on **both** bodies for them to block each other.
Neither is pushed: each one's velocity into the other is zeroed, so two bodies
walking into each other both stop.

```dart
final world = World();
world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(Collider.single(RectangleShape(x: 0, y: 0, width: 16, height: 16)))
  ..insert(Velocity(1, 0))
  ..insert(
    const CollisionConfig(
      layer: GameLayers.player,
      mask: GameLayers.solid | GameLayers.player,
      blocksDynamic: true,
      yieldAfter: Duration(milliseconds: 500),
    ),
  );
```

Two villagers meeting in a doorway would then block each other forever.
`yieldAfter` fixes that: once two bodies, **both** with `yieldAfter` set, have
been in contact that long, they stop blocking each other and pass through until
they separate; then blocking resumes. A pair yields at the shorter of its two
`yieldAfter` values. Static walls never yield.

Contact time follows the physics clock, so it's deterministic in fixed mode and
approximate in variable mode. Bodies about to touch (resolution is stopping
them) count as in contact, not only bodies that overlap.

Two events report it, registered by the plugin:

```dart
final yieldLog = FunctionSystem(
  'yield_log',
  eventReads: {ContactYieldStarted, ContactYieldEnded},
  run: (world) {
    for (final e in world.eventReader<ContactYieldStarted>().read()) {
      print('${e.entityA} and ${e.entityB} squeeze past each other');
    }
    for (final e in world.eventReader<ContactYieldEnded>().read()) {
      print('${e.entityA} and ${e.entityB} separated');
    }
  },
);
```

The plugin also inserts the `ContactYieldTracker` resource that keeps the
contact times. You rarely need it, but it answers `isYielding(a, b)` and
`contactAge(a, b)` (seconds) for a debug overlay, and `clear()` resets it
(without sending end events) when you tear down a scene.

## Fixed-timestep mode

The default `PhysicsMode.variable` runs the three systems in `Schedules.update`
and scales by `WallTime.delta`. For anything that must be deterministic
(network prediction, replays, lockstep), use fixed mode: the systems run in
`Schedules.fixedUpdate` and scale by `FixedTimestep.stepSeconds`.

```dart
final app = App()
  ..addPlugin(const PhysicsPlugin(config: PhysicsConfig(mode: PhysicsMode.fixed)))
  ..insertResource(MoveIntent())
  ..addSystem(PlayerMovementSystem(), schedule: Schedules.fixedPreUpdate);
```

Velocity means the same in both modes (pixels per 60 Hz frame), so switching
needs no retuning. To draw smoothly between fixed steps, see
[Smoothing with alpha](/docs/scheduling/time#smoothing-with-alpha).

## Configuration

```dart
final plugin = PhysicsPlugin(
  config: PhysicsConfig(
    mode: PhysicsMode.variable,
    enableResolution: true,
    enableIntegration: true,
    spatialHashCellSize: 64,
  ),
);
```

| Field | Default | Meaning |
|---|---|---|
| `mode` | `PhysicsMode.variable` | `variable` (update, `WallTime`) or `fixed` (fixedUpdate, `FixedTimestep`) |
| `enableResolution` | `true` | `false` lets bodies move through walls (a noclip or ghost mode); events still fire |
| `enableIntegration` | `true` | `false` when your own system moves `Transform2D` and you only want blocking and events |
| `spatialHashCellSize` | `64` | Broad-phase grid cell, in world units |

`PhysicsPlugin` registers `CollisionEvent`, `ContactYieldStarted` and
`ContactYieldEnded`, inserts `ContactYieldTracker`, and adds the systems. To
assemble it yourself, the systems take a mode in their constructor:

```dart
final app = App()
  ..addEvent<CollisionEvent>()
  ..addSystem(
    const CollisionResolutionSystem.fixed(),
    schedule: Schedules.fixedUpdate,
  )
  ..addSystem(
    const VelocityIntegrationSystem.fixed(),
    schedule: Schedules.fixedUpdate,
  )
  ..addSystem(
    const CollisionDetectionSystem(spatialHashCellSize: 32),
    schedule: Schedules.fixedUpdate,
  );
```

`CollisionResolutionSystem()` and `VelocityIntegrationSystem()` (no `.fixed`)
are the variable-mode versions, for `Schedules.update`. Yielding needs the
tracker: insert a `ContactYieldTracker` and register both yield events.

## Tilemaps

`fledge_tiled` can spawn colliders from a Tiled map's tile layers, per-tile
collision shapes and objects, and can build a pathfinding grid from collision
layers. See [Tiled](/docs/gameplay/tiled) and
[Pathfinding](/docs/gameplay/pathfinding).

To see colliders while you work, turn on collider gizmos in
[Debug](/docs/ui/debug).

## See also

- [Pathfinding](/docs/gameplay/pathfinding)
- [Time & Fixed Timestep](/docs/scheduling/time)
- [Events](/docs/ecs/events)
- [`fledge_physics` API reference](https://pub.dev/documentation/fledge_physics/latest/)
