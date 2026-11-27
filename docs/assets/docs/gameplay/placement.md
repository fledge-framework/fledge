# Placement

Farming and life-sim games keep asking the same thing: pick an item from the
hotbar, see a ghost of it on the tile in front of the player, red where it
can't go, and drop it on confirm. `fledge_ui` ships the generic part of that
flow as `PlacementCorePlugin`: the placement-mode state machine, its events, a
validator hook, the ghost preview, and a registry for placed things.

Your game supplies what placement *means*: which input enters, moves and
confirms it, what a tile is in world space, which tiles are allowed, and what
a confirm spawns.

## What you need

```yaml
dependencies:
  fledge_ui: ^0.7.1
  fledge_render_2d: ^0.7.1 # Sprite, Transform2D, RenderPlugin
```

- Flutter 3.50+ (Dart `^3.14`). Desktop first (Windows, macOS, Linux); web
  and mobile are best-effort.
- The ghost is an ordinary sprite entity, drawn by the sprite pipeline, so it
  needs `RenderPlugin` (see [Rendering](/docs/rendering/overview)). Without a
  ghost config the plugin needs nothing but `fledge_ecs`.
- `PlacementCorePlugin` is separate from `UiPlugin`; add either without the
  other.

<!-- snippet-setup
const tileSize = 16.0;

/// One placed piece of furniture, as the game saves it.
class FurnitureRecord implements PlacedRecord {
  @override
  final String id;
  @override
  final String mapKey;
  final String key;
  final int x, y;

  FurnitureRecord({
    required this.id,
    required this.mapKey,
    required this.key,
    required this.x,
    required this.y,
  });
}

TextureHandle textureFor(String key) =>
    const TextureHandle(id: 1, width: 16, height: 16);

/// Refuses tiles that already hold furniture.
class FreeTileValidator extends PlacementValidator {
  const FreeTileValidator();

  @override
  bool isValid(World world, String key, PlacementTile tile) {
    final placed = world.getResource<PlacedEntityRegistry<FurnitureRecord>>();
    if (placed == null) return true;
    return !placed
        .recordsOn(tile.mapKey)
        .any((r) => r.x == tile.x && r.y == tile.y);
  }

  @override
  String? refusalReason(World world, String key, PlacementTile tile) =>
      'Something is already there';
}
-->

## Setting it up

A placeable is identified by a string key you choose (`'chair'`), and a map by
an opaque string `mapKey` (your map's id). A `PlacementTile(mapKey, x, y)`
names one tile.

```dart
final app = App()
  ..addPlugin(RenderPlugin())
  ..insertResource(PlacedEntityRegistry<FurnitureRecord>())
  ..addPlugin(
    PlacementCorePlugin(
      validator: const FreeTileValidator(),
      // What the validator reads, so the scheduler can order around it.
      validatorAccess: const PlacementAccess(
        resourceReads: {PlacedEntityRegistry<FurnitureRecord>},
      ),
      ghost: PlacementGhostConfig(
        tileToWorld: (tile) => (tile.x * tileSize, tile.y * tileSize),
        ghostSpriteFor: (world, key) => Sprite(texture: textureFor(key)),
      ),
    ),
  );
```

The plugin inserts the `PlacementState` resource, registers the eight
placement events, adds `PlacementSystem` (in `Schedules.update` by default)
and, when you pass `ghost:`, inserts the `PlacementGhostConfig` resource and
adds `PlacementGhostSystem` (in `Schedules.postUpdate`). It does not insert a
`PlacedEntityRegistry`: that's yours, typed by your record class.

## The flow

Everything goes through events. Any system (or a widget, between ticks) sends
requests; only `PlacementSystem` reads them, and it is the only writer of
`PlacementState`:

```dart
final world = App().addPlugin(PlacementCorePlugin()).world;

// The player picked a chair on the hotbar.
world.eventWriter<PlacementEnterRequested>().send(
  const PlacementEnterRequested('chair'),
);

// Each frame: the tile in front of the player.
world.eventWriter<PlacementPreviewRequested>().send(
  const PlacementPreviewRequested('farmhouse', 4, 7),
);

// The player pressed confirm (or cancel).
world.eventWriter<PlacementConfirmRequested>().send(
  const PlacementConfirmRequested(),
);
world.eventWriter<PlacementCancelRequested>().send(
  const PlacementCancelRequested(),
);
```

| Request | Effect |
|---|---|
| `PlacementEnterRequested(key)` | Enters placement mode for `key`, with no preview tile yet. Placing something else is cancelled first; already placing `key` does nothing. The last one in a frame wins |
| `PlacementPreviewRequested(mapKey, x, y)` | Moves the preview to that tile and validates it. Ignored unless placing. The last one wins |
| `PlacementConfirmRequested()` | Places at the preview tile if it's valid (re-checked in the same run), and ends placement mode. Otherwise ignored |
| `PlacementCancelRequested()` | Leaves placement mode without placing. Ignored unless placing |

In one run, `PlacementSystem` applies them in the order cancel, enter,
preview, confirm. So a cancel and an enter in the same frame leave placement
entered, and an enter plus a preview in the same frame preview the new
placeable.

Like all [events](/docs/ecs/events#timing-events-are-double-buffered), a
request sent by a system is read on the next frame, and the notifications
`PlacementSystem` sends are readable the frame after that:

| Notification | Sent when |
|---|---|
| `PlacementEntered(key)` | Placement mode started |
| `PlacementPreviewMoved(tile, isValid:, reason:)` | The preview moved, or its validity or refusal reason changed on the same tile |
| `PlacementConfirmed(key, tile)` | The player placed `key` on `tile`. Placement mode has ended |
| `PlacementCancelled(key)` | Placement ended without placing (a cancel, or entering another placeable) |

### Reacting to a confirm

The core doesn't spawn anything. Read `PlacementConfirmed` and do what your
game does: take the item from the inventory, register a record, spawn the
entity.

```dart
class SpawnFurnitureSystem extends System {
  static const String systemName = 'spawnFurniture';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    resourceWrites: {PlacedEntityRegistry<FurnitureRecord>},
    eventReads: {PlacementConfirmed},
  );

  @override
  void run(World world) {
    final placed = world.getResource<PlacedEntityRegistry<FurnitureRecord>>()!;
    for (final event in world.eventReader<PlacementConfirmed>().read()) {
      final record = FurnitureRecord(
        id: placed.allocateId(event.key),
        mapKey: event.tile.mapKey,
        key: event.key,
        x: event.tile.x,
        y: event.tile.y,
      );
      placed.register(record);
      world.spawn()
        ..insert(PlacedEntityRef(record.id))
        ..insert(Transform2D.from(record.x * tileSize, record.y * tileSize))
        ..insert(GlobalTransform2D())
        ..insert(Sprite(texture: textureFor(record.key)));
    }
  }
}
```

## PlacementState

Read it anywhere (a HUD hint, a run condition). It's transient: never saved.

| Member | Meaning |
|---|---|
| `mode` | `PlacementMode.idle`, `previewing` (the preview tile is valid) or `invalid` (no preview tile yet, or the validator refuses it) |
| `isPlacing` | Not idle |
| `isValid` | `mode == previewing`: a confirm would place |
| `placeableKey` | The key being placed, or null |
| `previewTile` | The preview `PlacementTile`, or null |
| `refusalReason` | The validator's reason for refusing the tile, or null |

`placementActive` is a run condition that is true while placing (false
without a `PlacementState`). Pause other systems with it:

```dart
final steerNpcs = FunctionSystem(
  'steerNpcs',
  runIf: RunConditions.not(placementActive),
  run: (world) {
    // ...
  },
);
```

`PlacementSystem` itself only runs while placing or when an enter request is
waiting, so an idle game pays only for that check.

## Validation

A `PlacementValidator` decides where a placeable may go. `PlacementSystem`
asks `isValid(world, key, tile)` about the preview tile on **every run** while
placing, not just when the tile changes, so a tile turns invalid when an NPC
walks onto it. When `isValid` returns false it also asks
`refusalReason(...)` (default null) for a player-facing reason.

- Validators must only read the world: no writes, no events.
- Declare what they read in `PlacementCorePlugin(validatorAccess:)` as a
  `PlacementAccess(reads: {...}, resourceReads: {...})`. Those go on
  `PlacementSystem`'s `SystemMeta`.
- Without a validator, every tile is valid.

## The ghost

With a `PlacementGhostConfig`, `PlacementGhostSystem` keeps one entity at the
preview tile: a `PlacementGhost` component (`key`, `tile`, `isValid`), a
`Transform2D`, a `GlobalTransform2D` and the sprite your `ghostSpriteFor`
returns. It appears once there is a preview tile, is rebuilt when the
placeable changes, and is despawned when placement ends.

| Field | Meaning |
|---|---|
| `tileToWorld(tile)` | World position for the ghost, the same anchor you spawn the real entity at |
| `ghostSpriteFor(world, key)` | A fresh `Sprite` for the placeable (texture, anchor, draw layer), or null for no ghost. Use a world layer so the ghost follows the camera |
| `validColor` | Tint on a valid tile (default `0x80FFFFFF`, the sprite at half opacity). Replaces the sprite's `color` |
| `invalidColor` | Tint on an invalid tile (default `0x80FF4040`, half-transparent red) |
| `resourceReads` | Resources `ghostSpriteFor` reads, declared on the ghost system's meta |

## Placed things: PlacedEntityRegistry

`PlacedEntityRegistry<TRecord>` holds the placed things in the world, per
map. Your record class implements `PlacedRecord` (an `id` and a `mapKey`);
everything else on it is yours.

| Member | Meaning |
|---|---|
| `allocateId(prefix)` | A fresh id `<prefix>_<n>`. Deterministic: the same allocations after the same load give the same ids. An id is never handed out twice |
| `nextId` | The next number `allocateId` uses. Settable for a save load (values below 1 become 1) |
| `register(record)` | Adds a record, replacing one with the same id |
| `remove(id)` | Removes and returns a record, or null |
| `get(id)`, `contains(id)` | Look one up |
| `records`, `recordsOn(mapKey)` | All records, or those on one map, in registration order |
| `length`, `clear()` | Count, and remove all (the id counter is kept) |

Put a `PlacedEntityRef(recordId)` on every entity you spawn for a record, so
you can find (and despawn) placed entities generically, and tell which
records already have an entity on the current map after a map change.

The registry doesn't mix in `Saveable`, so `fledge_ui` doesn't depend on
`fledge_save`. Wrap it in your own saved resource and restore the records and
`nextId` on load; see [Save & Load](/docs/gameplay/save). Records are kept in
registration order, so a save written from them is deterministic.

## Ordering

| System | Name constant | Default schedule |
|---|---|---|
| `PlacementSystem` | `PlacementSystem.systemName` | `Schedules.update` |
| `PlacementGhostSystem` | `PlacementGhostSystem.systemName` | `Schedules.postUpdate` |

`PlacementCorePlugin` takes `schedule` and `ghostSchedule` to move them, and
`placementBefore`/`placementAfter`/`ghostBefore`/`ghostAfter` (lists of
system or set names) to order them against your systems. For example, run
placement after the system that works out which tile the player faces:

```dart
const facingTileSystem = 'facingTile'; // your system's systemName

final plugin = PlacementCorePlugin(
  validator: const FreeTileValidator(),
  placementAfter: [facingTileSystem],
);
```

The ghost system always runs after `PlacementGhostSystem.defaultAfter`:
`TransformPropagateSystem` and the camera systems (`CameraFollowSystem`,
`CameraShakeSystem`, `ParallaxSystem`, `ActiveCameraViewSystem`), when they
share its schedule. Names that aren't registered in that schedule are
ignored.

## See also

- [Tiled Maps](/docs/gameplay/tiled), for tile coordinates and map keys
- [Save & Load](/docs/gameplay/save)
- [Events](/docs/ecs/events)
- [fledge_ui API reference](https://pub.dev/documentation/fledge_ui/latest/)
