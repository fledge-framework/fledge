# Tiled Maps

`fledge_tiled` loads maps made in the [Tiled](https://www.mapeditor.org/)
editor (`.tmx` maps with embedded or external `.tsx` tilesets) and spawns them
as entities: one per map, one per layer, and one per object you ask for. Tile
layers are drawn through the shared sprite pipeline, object layers become
spawn points, triggers and colliders, and tile collision feeds
[Physics](/docs/gameplay/physics) and [Pathfinding](/docs/gameplay/pathfinding).

This page covers loading, spawning, objects, properties and collision. How
tiles are drawn, sorted against characters and culled is on
[Rendering Tilemaps](/docs/gameplay/tiled-rendering).

## What you need

```yaml
dependencies:
  fledge_tiled: ^0.7.2
  fledge_physics: ^0.7.2    # Collider, CollisionShape, CollisionGrid
  fledge_render_2d: ^0.7.2  # RenderPlugin, Transform2D, textures
  fledge_assets: ^0.7.2     # Assets<T> and Handle<T>
```

- **Flutter 3.50+** (Dart 3.14+). Desktop (Windows, macOS, Linux) is the
  supported target; web and mobile are best-effort. The loader reads files
  through a callback you give it, so loading from the Flutter asset bundle
  works on every platform.
- **Orthogonal maps only.** Isometric, staggered and hexagonal maps load, but
  tiles are placed on a square grid. See [Limitations](#limitations).
- **Add `RenderPlugin` before `TiledPlugin`.** `TiledPlugin` registers its
  tile extractor only if the `Extractors` resource already exists; added the
  other way round, the map spawns but is never drawn.
- **`TransformPropagateSystem`** in a schedule before extraction, so the
  map's `GlobalTransform2D` follows its `Transform2D` (see
  [Transforms](/docs/rendering/transforms#running-propagation)).
- **`WallTimePlugin`** for animated tiles.

The `fledge_tiled` library still re-exports `fledge_physics`, so `Collider`
and `CollisionGrid` resolve from its import alone. That re-export is going
away: import `package:fledge_physics/fledge_physics.dart` yourself.

<!-- snippet-setup
import 'package:vector_math/vector_math.dart';

late App app;
late World world;
late LoadedTilemap tilemap;
late Handle<TilemapAsset> levelHandle;
late TmxLoader tmxLoader;

class Enemy {
  final int health;
  Enemy({required this.health});
}

class Coin {
  final int value;
  Coin(this.value);
}

class DamageZone {
  final int damage;
  DamageZone(this.damage);
}
-->

## Quick start

```dart
import 'package:fledge_assets/fledge_assets.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:fledge_tiled/fledge_tiled.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Decodes an image from the asset bundle into `Assets<Texture>`.
Future<TextureHandle> loadTexture(App app, String asset) async {
  final data = await rootBundle.load(asset);
  final texture = await decodeTextureBytes(data.buffer.asUint8List());
  final handle = app.world.getResource<Assets<Texture>>()!.add(texture);
  return TextureHandle(
    id: handle.id.id,
    width: texture.width,
    height: texture.height,
  );
}

Future<App> buildGame() async {
  final app = App()
    ..addPlugin(WallTimePlugin()) // animated tiles
    ..addPlugin(RenderPlugin()) // before TiledPlugin
    ..addPlugin(TiledPlugin())
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate);

  // For your own sprites; tiles have their own extractor.
  app.world.getResource<Extractors>()!.register(SpriteExtractor());

  // Load the map and every tileset image it uses, before the game starts.
  final loader = TmxLoader(
    tilemapLoader: AssetTilemapLoader(loadStringContent: rootBundle.loadString),
    textureLoader: (path, width, height) => loadTexture(app, path),
  );
  final map = await loader.load('assets/maps/level1.tmx');
  final level = app.world.getResource<Assets<TilemapAsset>>()!.add(map);

  // Spawned by TilemapSpawnSystem on the next tick.
  app.world.eventWriter<SpawnTilemapEvent>().send(
    SpawnTilemapEvent.fromHandle(level),
  );
  return app;
}
```

List the `.tmx`, `.tsx` and image files under `flutter: assets:` in your
`pubspec.yaml`. Paths inside a map (its tilesets, their images) are resolved
relative to the file that names them, `..` included, so a tileset can point
at art outside the maps folder.

Show the game with `FledgeRenderView` as on
[Rendering Overview](/docs/rendering/overview).

## Loading maps

`TiledPlugin` inserts an `Assets<TilemapAsset>` store. A `TilemapAsset`
(an alias of `LoadedTilemap`) is a parsed map plus its loaded tilesets
(`LoadedTileset`, with a `TextureAtlas` each) and its tile animations.

The parsing is done by a `TilemapLoader`. The built-in one is
`AssetTilemapLoader`, which reads text through the `loadStringContent`
callback (optionally behind an `assetPrefix`). Tileset images go through the
`TextureLoader` you pass: a `Future<TextureHandle> Function(String path, int
width, int height)` that decodes the image and registers it in
`Assets<Texture>`. Width and height come from the tileset; returning the
decoded image's real size is fine.

`TmxLoader` wraps a `TilemapLoader` and a `TextureLoader` into a `Loader<TilemapAsset>`,
so maps fit the [asset store](/docs/app/assets). There are two ways to use it.

**Await, then add** (the quick start): the map is ready the moment you send
the spawn event.

**Let the store load it**: `Assets.load` returns a handle at once and fills it
in when loading finishes. Loading the same path twice shares one entry, and
with `AssetPlugin(enableHotReload: true)` the map reloads when its file
changes. A spawn event whose handle isn't ready yet is skipped, so send it
once the handle is ready:

```dart
class SpawnLevelWhenReady extends System {
  static const String systemName = 'spawnLevelWhenReady';

  SpawnLevelWhenReady(this.level);

  final Handle<TilemapAsset> level;
  bool _sent = false;

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    eventWrites: {SpawnTilemapEvent},
  );

  @override
  void run(World world) {
    if (_sent || !level.isReady) return;
    _sent = true;
    world.eventWriter<SpawnTilemapEvent>().send(
      SpawnTilemapEvent.fromHandle(level),
    );
  }
}

void setUpLevel(App app, TmxLoader loader) {
  final level = app.world.getResource<Assets<TilemapAsset>>()!.load(
    'assets/maps/level1.tmx',
    loader,
  );
  app.addSystem(SpawnLevelWhenReady(level), schedule: Schedules.update);
}
```

A load that fails leaves the handle empty, and the store keeps the error:
`handle.error` (or `assets.error(id)` / `assets.hasError(id)`) returns it, and
`assets.onLoadError` is called with the path, error and stack trace if you set
it. So check `handle.error` alongside `isReady` rather than waiting forever.
A failed hot reload keeps the previous map and records the error the same way.

A reload replaces the asset, but a map already spawned keeps the tiles and
objects it was spawned with. To see a changed layout, despawn the map and
spawn it again.

- `SpawnTilemapEvent(assetKey: path)` also works for a map loaded with
  `Assets.load`: the spawn system looks the path up in the store.
- `TsxLoader` is a `Loader<TilesetAsset>` for a standalone `.tsx` file, for
  `Assets<TilesetAsset>`. Construct it with `loadStringContent` and
  `textureLoader` (and an optional `assetPrefix`); it parses the tileset as a
  map's external tileset is parsed, and gives it `firstGid` 1. A map's own
  tilesets still load with the map.
- To load from somewhere other than an asset bundle (files, the network),
  implement `TilemapLoader.load(path, textureLoader)`, or call
  `AssetTilemapLoader.loadFromString(tmx, basePath, textureLoader,
  tsxLoader)` with content you already have.
  `TiledContentProvider` is an interface for such custom loaders; the built-in
  loader doesn't use it.

## Spawning

Send a `SpawnTilemapEvent` to spawn a loaded map:

```dart
world.eventWriter<SpawnTilemapEvent>().send(
  SpawnTilemapEvent.fromHandle(
    levelHandle,
    position: const Offset(0, 0), // where the map's top-left corner goes
    config: const TilemapSpawnConfig(staticTransforms: true),
  ),
);
```

`TilemapSpawnSystem` handles it in `Schedules.first`, in the
`FirstSets.content` phase (after asset hot reloads are applied). Its name is
`TilemapSpawnSystem.systemName`. It's an exclusive system. Like any event,
the spawn happens on the frame after you send it (see
[Events](/docs/ecs/events#timing-events-are-double-buffered)), so systems in
later schedules of that frame already see the map's entities. When it has
spawned a map, it sends `TilemapSpawnedEvent` (`entity`, plus the `handle` or
`assetKey` it was spawned from), readable the frame after.

It builds this hierarchy:

```
Map entity: Tilemap, Transform2D (position), GlobalTransform2D,
            TilemapAnimator (if any tile is animated)
├── Tile layer: TileLayer, Transform2D, GlobalTransform2D
│   └── Collider entity (if tile colliders are generated)
├── Object layer: ObjectLayer, Transform2D, GlobalTransform2D
│   ├── Object entity: TiledObject, Transform2D, GlobalTransform2D, Collider?
│   └── ...
└── ...
```

Layers inside Tiled group layers are flattened into children of the map,
each taking its groups' settings as Tiled draws them: offsets add up, parallax
and opacity multiply, a layer is visible only if every group is, and tints
multiply.
Image layers are skipped. Despawn a whole map with
`world.despawnRecursive(mapEntity)`.

### Spawn options

`TilemapSpawnConfig`:

| Option | Default | Meaning |
|---|---|---|
| `tileConfig` | `TileLayerConfig()` | Tile collider generation (see [Tile collision](#tile-collision)) |
| `objectTypes` | `null` | Which object classes become entities, and how (see [Objects](#objects)) |
| `onLayerSpawn` | `null` | `(EntityCommands entity, String layerName)`, called for every tile and object layer |
| `staticTransforms` | `false` | The map never moves: its root gets `StaticTransform`, so it and everything spawned under it are computed once and then skipped by transform propagation and sprite culling. Leave it off if anything under the map moves after spawning (debug builds assert) |

### Map and layer components

`Tilemap` (on the root) has the map's size in tiles (`width`, `height`),
`tileWidth`, `tileHeight`, `bounds` (in map pixels, from the origin),
`infinite`, `renderOrder` (a `RenderOrder`: `rightDown`, `rightUp`,
`leftDown`, `leftUp`), the parsed `map` (`package:tiled`'s `TiledMap`) and the
`asset` handle it was spawned from.

`TileLayer` has `name`, `layerIndex` (its position among the map's layers),
`layerClass` (Tiled's layer *Class*), `opacity`, `visible`, `tintColor`,
`offset`, `parallax`, and `tiles`: one `TileData` per painted cell, with its
grid `x`/`y`, `gid`, `localId`, `tilesetIndex`, flip flags and `animated`.
On an infinite map, `tiles` holds the tiles of every chunk at their tile
coordinates (negative left of or above the origin), and `chunks` groups the
same tiles by the file's chunks (`ChunkKey` in chunk units, `TileChunk` with
its size and pixel position); it's null on a finite map.

```dart
for (final (_, layer) in world.query1<TileLayer>().iter()) {
  print('${layer.name}: ${layer.tiles?.length ?? 0} tiles');
}
```

Hide or show a layer at runtime through the root, which overrides the
layer's own `visible` flag:

```dart
for (final (_, map) in world.query1<Tilemap>().iter()) {
  map.setLayerVisible('secrets', false);
  map.clearLayerVisibility('roof'); // back to the layer's own setting
}
```

`TiledPlugin(TiledPluginConfig(respectLayerVisibility: false))` draws every
layer regardless. The config's `chunkSize` and `maxLoadedChunks` are
deprecated and never read.

## Objects

Every object layer gets an `ObjectLayer` component holding all its objects as
`TiledObjectData`, whether or not they become entities. Use it for spawn
points and other data you read once:

```dart
for (final (_, layer) in world.query1<ObjectLayer>().iter()) {
  for (final spawn in layer.findByType('spawn_point')) {
    print('spawn at ${spawn.x}, ${spawn.y}');
  }
  final door = layer.findByName('front_door').firstOrNull;
}
```

`findById(id)` finds one object. `TiledObjectData` has `id`, `name`, `type`
(Tiled's *Class*), `x`, `y`, `width`, `height`, `rotation`, `shape` (an
`ObjectShape`: `rectangle`, `ellipse`, `polygon`, `polyline`, `point`, `tile`,
`text`), `points` for polygons and polylines (relative to `x`, `y`),
`properties`, `visible` and `center`.

### Spawning objects as entities

List the classes that should become entities in `objectTypes`. Objects whose
class isn't listed stay as data only.

```dart
world.eventWriter<SpawnTilemapEvent>().send(
  SpawnTilemapEvent.fromHandle(
    levelHandle,
    config: TilemapSpawnConfig(
      objectTypes: {
        'enemy': ObjectTypeConfig(
          createCollider: false,
          onSpawn: (entity, object) {
            entity.insert(
              Enemy(health: object.properties.getIntOr('health', 100)),
            );
          },
        ),
        'coin': ObjectTypeConfig(
          onSpawn: (entity, object) {
            entity.insert(Coin(object.properties.getIntOr('value', 1)));
          },
        ),
      },
    ),
  ),
);
```

Each object entity is a child of its layer's entity and gets:

- `Transform2D.from(object.x, object.y)` plus its layer's offset (its
  groups' included), relative to the map. For a rectangle or ellipse that's
  its top-left corner; for a tile object, its image's bottom-left.
- A `TiledObject` component: `id`, `name`, `type`, `properties`.
- With `createCollider: true` (the default), a `Collider` built from its
  shape in local space (relative to the transform): rectangles (with
  rotation), ellipses, polygons, polylines and points. Tile and text objects
  get no collider this way.

`onSpawn` runs last, so it can add components or replace any of these.

### Tile objects and image collections

A building or tall prop is best placed as a **tile object** from an
**image-collection tileset** (each tile its own image). Tiled shows the real
art in the editor, and the game can draw it y-sorted among the characters,
which a tile layer can't do for something taller than one tile. Give each tile
its class, properties and a collision rectangle (its footprint) once, in the
tileset; every placement inherits them.

`AssetTilemapLoader` loads each image-collection tile's image through your
texture loader. A tile object's `TiledObjectData` then has:

- `type`: its own class if set, otherwise its tile's, so `objectTypes`
  matches it either way.
- `properties`: the tile's, overridden by the object's own.
- `tileImage`: the tile's `TextureHandle`.
- `tileCollision`: the tile's collision shapes, relative to the image's
  top-left corner.
- `tile`: the tileset and local id (a `TilesetLookup`), for anything else.

The spawn system doesn't draw tile objects. Add the sprite in `onSpawn`:

```dart
final props = ObjectTypeConfig(
  createCollider: false,
  onSpawn: (entity, object) {
    final image = object.tileImage;
    if (image == null) return;
    // Tiled anchors a tile object at its image's bottom-left corner, so
    // the sprite y-sorts by its base.
    entity.insert(Sprite(texture: image, anchor: Vector2(0, 1)));
  },
);
```

`Vector2` is from `package:vector_math`. For the footprint, the image's
top-left corner is at `(object.x, object.y - object.height)`, and
`object.tileCollision` is relative to it.

## Custom properties

Map, tile and object properties are read through `TiledProperties`, with a
nullable getter and an `...Or` getter with a default for each type:

```dart
void readProps(TiledObjectData object) {
  final props = object.properties;

  final name = props.getStringOr('display_name', 'Unknown');
  final health = props.getInt('health'); // null if missing
  final speed = props.getDoubleOr('speed', 50);
  final boss = props.getBoolOr('is_boss', false);
  final tint = props.getColor('tint'); // Tiled's #AARRGGBB
  final target = props.getObjectRef('target'); // an object id
  final sprite = props.getFile('sprite');

  if (props.has('loot_table')) {
    // ...
  }
}
```

`names`, `raw`, `length` and `isEmpty` cover the rest. Tile properties are on
the tileset: `tilemap.tilesets[i].getProperties(localId)`.

## Collision

There are two sources of collision, and both produce `fledge_physics`
`Collider` components (see [Physics](/docs/gameplay/physics)):

- **Objects** drawn in an object layer, with `createCollider: true` (above).
- **Tile collision** drawn per tile in Tiled's tileset collision editor.

The loader reads tile collision objects into `LoadedTileset.collisionShapes`
(by local id) as `RectangleShape`, `EllipseShape`, `PolygonShape`,
`PolylineShape` or `PointShape`.

### Tile collision

Turn on `generateColliders` to collect the collision of every tile in a layer
into one `Collider`, on a child entity of the layer:

```dart
world.eventWriter<SpawnTilemapEvent>().send(
  SpawnTilemapEvent.fromHandle(
    levelHandle,
    config: TilemapSpawnConfig(
      tileConfig: TileLayerConfig(
        generateColliders: true,
        colliderLayers: {'walls', 'hazards'}, // null = every tile layer
        onColliderSpawn: (entity, layerName, collider) {
          if (layerName == 'hazards') entity.insert(DamageZone(10));
        },
      ),
    ),
  ),
);
```

For each layer it:

1. Takes the collision shapes of every painted tile. On a flipped or rotated
   tile, unrotated rectangles are flipped with it, about the tile's own size
   (`TileCollider.flipShapes`); other shapes keep their unflipped position.
2. Moves them to where the tile's art is drawn in the map: a tile bigger or
   smaller than the grid sits on its cell's bottom-left corner, moved by the
   tileset's tile offset (`TileCollider.placeTileShapes`).
3. Merges neighbouring unrotated rectangles, first along rows, then rows of
   the same span stacked under each other, so a wall becomes one rectangle.
4. Spawns one entity with `Transform2D` (the layer's offset, its groups'
   included), `GlobalTransform2D` and the `Collider`, and calls
   `onColliderSpawn`. The shapes are in the map's space; physics carries the
   map's position down the hierarchy, so the collision is where the map is
   drawn.

`TileCollider` exposes the steps for your own use: `fromTileCollision`,
`fromTileLayer` (from `TileCollisionData`), `placeTileShapes`, `flipShapes`,
`mergeRectangles`
and `fromObject`.

### Pathfinding grids

`extractCollisionGrid` turns a map into a `fledge_physics` `CollisionGrid`,
one cell per tile, for the A* `Pathfinder`:

```dart
final grid = extractCollisionGrid(
  tilemap,
  collisionLayers: {'Collision'}, // default {'Collision', 'collision'}
);
```

A cell is blocked wherever any tile is painted on one of the named layers;
the tiles' collision shapes aren't consulted, so paint a dedicated (usually
hidden) collision layer. `extractCollisionGrids` does a map of maps at once.
`extractCollisionGridFromTmx(tmx, mapWidth:, mapHeight:)` reads the grid
straight from TMX text without loading tilesets or textures. It throws the
parser's error if the text isn't a valid map.

On an infinite map the grid covers the bounding box of the collision layers'
chunks, which can start left of or above the map's origin.
`collisionGridOrigin(tilemap)` (same `collisionLayers`) is the tile at cell
(0, 0): subtract it from tile coordinates before searching, and add it back to
the path's cells. On a finite map it's (0, 0). `extractCollisionGridFromTmx`
puts tile (x, y) in cell (x, y) and drops chunk tiles outside its size.

`TerrainGrid.fromTilemap(map, layer:)` reads the terrain painted with Tiled's
terrain (Wang corner) brush, at half-tile resolution, and `terrainAt(x, y)`
names the terrain at a map pixel. `applyTerrainCosts` turns it into path
costs so walkers prefer roads:

```dart
final grid = extractCollisionGrid(tilemap);
applyTerrainCosts(
  grid,
  TerrainGrid.fromTilemap(tilemap.map, layer: 'ground'),
  {'road': 1, 'path': 1},
  defaultCost: 3,
);
```

Searching the grid, smoothing paths and weighted costs are covered on
[Pathfinding](/docs/gameplay/pathfinding).

## Animated tiles

Animations set up in Tiled's tileset editor are loaded with the map. If any
tile is animated, the map entity gets a `TilemapAnimator`, which
`TileAnimationSystem` (in `Schedules.update`, named
`TileAnimationSystem.systemName`) advances by `WallTime.delta` each frame. Without `WallTimePlugin`, animated tiles stay on their first
frame. The extractor picks the current frame of each animated tile; nothing
else is needed.

`animator.animations` is keyed by global tile id (GID).
`animator.getCurrentFrame(gid)` returns the local id currently shown for an
animated tile (an unanimated GID comes back unchanged, so check
`hasAnimation(gid)` first) and `reset()` restarts every animation.

## Limitations

- **Infinite maps** spawn, draw and build collision grids from their chunks,
  but every chunk is loaded at once (there's no streaming), so very large
  infinite maps cost memory in proportion to everything painted.
- **Orthogonal only**: other orientations are placed on a square grid.
- **Tiles bigger than the map grid** (a 32×64 tree on a 32×32 map) are drawn
  at full size with their bottom-left corner on the cell's, moved by the
  tileset's tile offset, as in Tiled, and a `y_sort` tile sorts at its line
  measured from the image's top. Generated tile colliders still stay in the
  cell, and Tiled's "Tile render size: Map grid" option isn't read.
- **Move the map, don't scale or rotate it**: the map's scale and rotation
  move tile positions but don't scale or rotate the tiles. Zoom with the
  camera.
- **Image layers** are skipped; **object layers aren't drawn** (spawn sprites
  from them yourself); **object templates** aren't resolved.

## Migrating from `TilemapAssets`

The key-based stores still work for one release, with deprecation warnings:

| Deprecated | Use |
|---|---|
| `TilemapAssets.put(key, map)` + `SpawnTilemapEvent(assetKey: key)` | `Assets<TilemapAsset>.add(map)` + `SpawnTilemapEvent.fromHandle(handle)` |
| `TilesetRegistry` | `Assets<TilesetAsset>` |
| `TiledPluginConfig.chunkSize`, `maxLoadedChunks` | Nothing: never read |
| `CulledTilemapExtractor`, `ExtractedTile` | See [Rendering Tilemaps](/docs/gameplay/tiled-rendering#deprecated-extraction-types) |

A map spawned from the old store has no handle on its `Tilemap`, so the
extractor finds its data by matching map and tile sizes among the stored
maps: two different maps of the same size can be confused. Handles don't
have that problem.

## See also

- [Rendering Tilemaps](/docs/gameplay/tiled-rendering)
- [Physics](/docs/gameplay/physics)
- [Pathfinding](/docs/gameplay/pathfinding)
- [Assets](/docs/app/assets)
- [Hierarchies](/docs/ecs/hierarchies)
- [fledge_tiled API reference](https://pub.dev/documentation/fledge_tiled/latest/)
