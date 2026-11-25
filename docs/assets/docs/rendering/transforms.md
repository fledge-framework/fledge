# Transforms

Every drawn entity has a `Transform2D`, its position, rotation, scale and
skew **relative to its parent**, and a `GlobalTransform2D`, the world-space
result. `TransformPropagateSystem` computes the second from the first, down
the `Parent` / `Children` hierarchy from `fledge_ecs`. Both live in
`fledge_render_2d`.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late World world;
late Entity player;
-->

## Transform2D

```dart
final transform = Transform2D(
  translation: Vector2(100, 200),
  rotation: math.pi / 4, // radians; positive turns clockwise on screen
  scale: Vector2(2, 2),
);

final simple = Transform2D.from(100, 200); // translation only
final origin = Transform2D.identity();
```

World coordinates have y pointing down, as on screen. All fields are
mutable, and there are helpers for the usual edits:

```dart
final t = world.get<Transform2D>(player)!;
t.translate(4, 0);          // move by a delta
t.setTranslation(10, 20);   // or set outright
t.rotate(0.1);              // add radians
t.setRotationDegrees(90);
t.setUniformScale(1.5);
final copy = t.clone();
```

`skew` is a horizontal shear: a point moves `skew` × its (scaled) y along x,
before rotation. The full order is scale, skew, rotate, translate
(`toMatrix()` builds the matrix).

### A drop shadow

A shadow lying on the ground is the sprite's silhouette, mirrored about its
base (`flipY`), squashed and skewed, tinted dark and drawn under the
characters:

```dart
void spawnShadow(World world, TextureHandle texture, double x, double y) {
  world.spawn()
    ..insert(Transform2D(
      translation: Vector2(x, y),
      scale: Vector2(1, 0.45),
      skew: 0.6,
    ))
    ..insert(GlobalTransform2D())
    ..insert(Sprite(
      texture: texture,
      anchor: Vector2(0.5, 1), // mirror about the feet
      flipY: true,
      color: const Color(0x66000000),
      layer: DrawLayer.ground,
    ));
}
```

## GlobalTransform2D

`GlobalTransform2D.matrix` is a `Matrix3` (vector_math, column-major, with
the translation in entries 6 and 7). Read it; don't write it: propagation
overwrites it every time the local transform or a parent changes.

```dart
final global = world.get<GlobalTransform2D>(player)!;
final worldX = global.x;
final worldY = global.y;
final heading = global.rotation; // radians, summed down the hierarchy
final muzzle = global.transformPoint(Vector2(16, 0)); // local → world
final facing = global.transformVector(Vector2(1, 0)); // ignores translation
```

To go from world space back to an entity's local space, use `inverse()`. It
returns a new `GlobalTransform2D` and leaves the original alone:

```dart
final global = world.get<GlobalTransform2D>(player)!;
final local = global.inverse().transformPoint(Vector2(120, 80)); // world → local
```

The one exception is an entity with a `GlobalTransform2D` but **no**
`Transform2D`: propagation leaves its matrix alone, so you can set it by hand,
and its children follow it.

## Running propagation

`RenderPlugin` doesn't add `TransformPropagateSystem`; add it yourself, in a
schedule that runs before what reads `GlobalTransform2D`:

```dart
final app = App()
  ..addPlugin(RenderPlugin())
  ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);
```

`Schedules.preUpdate` (what the Drifter example uses) gives gameplay and
physics fresh world positions. Movement made later in the frame (in
`update` or a fixed step) then reaches `GlobalTransform2D` on the next
frame's propagation, so a non-interpolated sprite is drawn one frame behind
its `Transform2D`. If that matters, add a second `TransformPropagateSystem()`
to `Schedules.postUpdate`; the camera systems already order after
`TransformPropagateSystem.systemName`.

Order your own systems against it by name:

```dart
final readsWorldPositions = FunctionSystem(
  'aim_turrets',
  reads: {ComponentId.of<GlobalTransform2D>()},
  after: [TransformPropagateSystem.systemName],
  run: (world) {/* ... */},
);
```

Outside a schedule (a test, a loading step), `propagateTransforms(world)`
runs it once.

Entities need a `Transform2D`; propagation inserts a missing
`GlobalTransform2D` the first time it sees one. Inserting the
`GlobalTransform2D` yourself at spawn means the entity is drawn on its first
frame. Propagation skips anything whose local transform and parent haven't
changed, so a large static scene costs a comparison per entity, not a matrix
multiply.

## Hierarchies

Parent an entity with the `fledge_ecs` hierarchy API and its transform
becomes relative to the parent:

```dart
final ship = world.spawn()
  ..insert(Transform2D.from(200, 200))
  ..insert(GlobalTransform2D());

// A turret 12 units in front of the ship, turning with it.
world.spawnChild(ship.entity)
  ..insert(Transform2D.from(12, 0))
  ..insert(GlobalTransform2D());

// Or attach an existing entity:
final flag = world.spawn()..insert(Transform2D.from(0, -20));
world.setParent(flag.entity, ship.entity);
```

`world.removeParent(child)` detaches, and `world.despawnRecursive(entity)`
removes a whole subtree. See [Hierarchies](/docs/ecs/hierarchies) for the
rest of the API.

## Smooth movement between fixed steps

Simulation in the fixed-step schedules runs at 60 Hz by default, but a
display may refresh at 120 or 144 Hz. Without help, a fixed-step mover
stays put on some frames and jumps on others. Interpolation draws it between
its last two fixed-step positions instead.

Opt an entity in with `PreviousTransform2D`, and snapshot it at the start of
every fixed step with `SnapshotPreviousTransformSystem` in
`Schedules.fixedFirst`:

```dart
final app = App()
  ..addPlugin(RenderPlugin())
  ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate)
  ..addSystem(
    const SnapshotPreviousTransformSystem(),
    schedule: Schedules.fixedFirst,
  );

app.world.spawn()
  ..insert(Transform2D.from(0, 0))
  ..insert(GlobalTransform2D())
  ..insert(PreviousTransform2D()); // its starting value doesn't matter
```

`SpriteExtractor` and `AtlasSpriteExtractor` then draw such an entity at
`previous + (current − previous) × FixedTimestep.alpha`, and
`CameraFollowSystem` follows that same interpolated position.

- **Register the snapshot system.** Without it the snapshot never updates,
  and the sprite is drawn part of the way towards wherever the snapshot was
  created (the origin, by default).
- **Teleports:** after setting a position outright (a door, a respawn), call
  `world.get<PreviousTransform2D>(entity)!.snapTo(transform)` so the next
  frames don't smear the sprite across the jump.
- Only the translation is interpolated; rotation and scale are drawn at the
  current step's values.
- The interpolation is done on the local translation, so it is only correct
  for entities without a parent. Put `PreviousTransform2D` on the root of a
  moving hierarchy, not on a child.

Systems that snapshot before your fixed-step movement can order against
`SnapshotPreviousTransformSystem.systemName`.

## Static scenery

Mark scenery that never moves with `StaticTransform`:

```dart
world.spawn()
  ..insert(Transform2D.from(320, 96))
  ..insert(const StaticTransform())
  ..insert(Sprite(texture: kSolidColorTexture));
```

`TransformPropagateSystem` computes a static root (and its whole subtree)
once, then marks every entity in it `TransformFrozen` and never visits it
again. `SpriteExtractor` keeps frozen sprites in a spatial grid and only looks
at those near the view, so the per-frame cost follows what's on screen rather
than what's loaded.

The contract: once spawned, the entity's `Transform2D` and its place in the
hierarchy never change. Its `Sprite` (texture, colour, source rect, flips)
and `Visibility` may. Debug builds check every
`TransformPropagateSystem.frozenCheckInterval` (120) runs and throw a
`StateError` naming any frozen entity that moved. Don't insert
`TransformFrozen` yourself; filter on it (`Without<TransformFrozen>`) in an
extractor that only wants what can move. The `StaticTransforms` resource's
`generation` goes up whenever more entities are frozen, for caches that need
to rebuild.

Anything that moves even slightly (a swaying tree, a shaken prop) must not be
static.
