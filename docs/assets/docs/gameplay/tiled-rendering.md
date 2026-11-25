# Rendering Tilemaps

Tile layers spawned by [`fledge_tiled`](/docs/gameplay/tiled) are drawn
through the same sprite pipeline as everything else: each frame, the
`TilemapExtractor` turns the tiles near the camera into `ExtractedSprite`s in
the render world, and `FledgeRenderView` sorts and batches them together with
your characters, particles and UI. There's no separate tilemap widget or
render layer to set up.

This page covers how tiles are ordered against characters (including tiles
that y-sort with them), culling, flips, and what you can tune. It assumes the
setup from [Tiled Maps](/docs/gameplay/tiled#what-you-need) and the
[Rendering Overview](/docs/rendering/overview).

<!-- snippet-setup
late App app;
late World world;
-->

## The extractor

`TiledPlugin` registers one `TilemapExtractor` with the `Extractors`
resource, if `RenderPlugin` was added first. Every frame, in
`Schedules.extract`, it:

1. Finds each map entity (`Tilemap` + `GlobalTransform2D`) and its loaded
   data, through the handle the map was spawned from.
2. Skips layers that are hidden, unless the plugin was built with
   `TiledPluginConfig(respectLayerVisibility: false)`. A visibility override
   set with `Tilemap.setLayerVisible` wins over the layer's own flag.
3. Works out which tiles of each `TileLayer` are near the camera's view, and
   adds an `ExtractedSprite` for each.

Object layers aren't drawn: they're data, and you add sprites to the objects
you spawn (see [Tile objects](/docs/gameplay/tiled#tile-objects-and-image-collections)).

Each tile is drawn at its image's size, with its bottom-left corner on the
bottom-left of its grid cell (so a tile bigger than the map's grid, a 32×64
tree on a 32×32 map, rises above its cell as in Tiled, and a tile the size of
the grid fills its cell), moved by the tileset's tile offset and the layer's
offset, then by the map's `GlobalTransform2D`, and tinted with the layer's
opacity and tint colour (`TileLayer.effectiveColor`). Culling allows for how
far the biggest tile reaches beyond its cell, so tall tiles don't pop in at
the screen's edge. Tiles painted from an image-collection tileset are drawn
from their own image at its own size.

Layer parallax works as in Tiled: a layer with factor `p` moves `p` times as
fast as the camera, so it is shifted by `camera × (1 − p)`. A factor of 0
pins a layer to the screen; 0.5 gives a distant background. The shift comes
from the [`ActiveCameraView`](/docs/rendering/cameras), so without a camera
there is none. Move the map
with its `Transform2D`; zoom and rotate with the
[camera](/docs/rendering/cameras), not the map: the map's scale and rotation
move the tiles' positions but don't scale or rotate the tiles themselves.

### Options

| Option | Default | Meaning |
|---|---|---|
| `respectVisibility` | `true` | Skip hidden layers. Set from `TiledPluginConfig.respectLayerVisibility` |
| `cullMargin` | `64` (`TilemapExtractor.defaultCullMargin`) | World units beyond the camera's last view that are still extracted |
| `emitLegacyTiles` | `false` | Also emit the deprecated `ExtractedTile` for every tile |

The plugin's extractor uses the defaults apart from `respectVisibility`. To
change the others, swap it out after adding the plugin:

```dart
final extractors = app.world.getResource<Extractors>()!;
extractors.removeWhere((e) => e is TilemapExtractor);
extractors.register(TilemapExtractor(cullMargin: 128));
```

Don't register a second one alongside it: every tile would be drawn twice.

## Draw order

Tiles get the same integer sort keys as sprites (see
[Draw order](/docs/rendering/overview#draw-order)). Which band a tile lands
in depends on its layer's **Class** in Tiled:

| Layer | Band | Drawn |
|---|---|---|
| Class `above` | `DrawLayer.foreground` (300,000+) | Over the characters: roofs, treetops, archways |
| Anything else | `DrawLayer.ground` (100,000+) | Under the characters: floors, paths, rugs |
| `y_sort` tile on a non-`above` layer | `DrawLayer.characters` (200,000+) | Among the characters, by y (see [below](#y-sorted-tiles)) |

To set a layer's class, select it in Tiled's Layers panel and type `above` in
the *Class* field of its properties (Tiled 1.9+). `TileLayer.layerClass` holds
it at runtime.

Within a band, tiles sort by **row first, then layer index**: the sub-order is
`row * tileRowStride + layerIndex` (`tileRowStride` is 100, so up to 100 tile
layers sort correctly). So a tile one row lower draws over the tile above it,
even when it's on a lower layer.

The integer key only has room for rows 0 to 999, so it's clamped there and
the exact value travels as `ExtractedSprite.preciseSubOrder`.
`ExtractedSprite.sortByDrawOrder` (what `FledgeRenderView` uses) breaks ties
with it, so taller maps still sort by row and never spill into the next band.
`tileSortKey(drawLayer:, row:, layerIndex:)` and
`tilePreciseSubOrder(row:, layerIndex:)` compute both, for a custom
extractor.

### Characters

A `Sprite` is in `DrawLayer.characters` by default and y-sorted by its
transform's y (see
[the Sprite component](/docs/rendering/sprites-animation)). Anchor a
character at its feet (`anchor: Vector2(0.5, 1)`) so it sorts where it
stands. Ground tiles are always below it and `above` tiles always over it,
wherever it walks.

## Y-sorted tiles

Some tiles belong with the characters rather than under or over them: the
front wall of a room, a counter, a fence, a hedge. Someone standing behind one
should be hidden by it, and someone in front drawn over it. Give such a tile
the bool property **`y_sort`** in its tileset. Wherever it's painted on a
layer that isn't `above`, it's drawn in `DrawLayer.characters`, y-sorted like a
character, at its **line**:

1. The number property **`sort_y`** (pixels from the tile's top), if set.
2. Otherwise the bottom of its collision shapes (from Tiled's tile collision
   editor), so a wall sorts at its base.
3. Otherwise the tile's own bottom edge.

Flipping or rotating the tile in Tiled moves the line with it.

Sorting at the collision's bottom keeps the order unambiguous: a character
can't stand with its feet inside the solid part, so it's always clearly behind
the line or in front of it. Leave `y_sort` off anything walked on, and off
things nobody can stand behind, such as a back wall: a picture hung on a back
wall would otherwise sort behind it.

On an `above` layer, `y_sort` is ignored and the tile stays in the foreground.
`LoadedTileset.ySortSpans` holds the span each `y_sort` tile sorts by, and
`LoadedTileset.ySortLine(localId, flipFlags)` gives a tile's line in pixels
from its top (null for an ordinary tile).

For tall props that span several tiles (a building, a tree), a tile object
from an image-collection tileset is usually simpler: one sprite anchored at
its base sorts as a whole. See
[Tile objects](/docs/gameplay/tiled#tile-objects-and-image-collections).

## Culling

The extractor only visits tiles near the camera's last view, read from the
`ActiveCameraView` resource (written by `fledge_camera_2d`'s camera system).
Each layer keeps an index of its tiles by grid position, and the view is
mapped back into the layer's grid through the map's transform and the layer's
offset, so the cost follows what's on screen rather than the size of the map.
A whole map that is nowhere near the view is skipped before its layers are
looked at. Several large maps loaded side by side cost little more than one.

- Without `ActiveCameraView` (no camera plugin), or before the first paint,
  every tile is extracted.
- `cullMargin` widens the view to cover camera movement since the last paint.
  Raise it if tiles pop in at the screen edge during fast camera moves.
- Each tile's `ExtractedSprite` is built once and drawn again every frame it
  is in view. The cache is dropped when the map's transform changes, or the
  layer's colour or offset. A parallax layer's shift changes whenever the
  camera moves, so its cache is rebuilt then. Animated tiles are built every
  frame.

### Changing tiles at runtime

The index is rebuilt when a layer's `tiles` list is **replaced** or changes
length. Assign a new list to change a layer:

```dart
for (final (_, layer) in world.query1<TileLayer>().iter()) {
  if (layer.name != 'crops') continue;
  final tiles = layer.tiles ?? const <TileData>[];
  layer.tiles = [
    for (final t in tiles)
      if (t.x == 4 && t.y == 7)
        TileData(
          gid: t.gid + 1,
          x: t.x,
          y: t.y,
          tilesetIndex: t.tilesetIndex,
          localId: t.localId + 1,
        )
      else
        t,
  ];
}
```

Replacing an element of the existing list in place (`tiles[i] = ...`) isn't
noticed: the layer keeps drawing the old tile. The `gid` and `localId` must
agree (`gid` is the tileset's `firstGid` plus `localId`). Tile colliders
generated at spawn time don't change with the tiles.

## Flips and rotation

Tiled's eight orientations (horizontal, vertical and diagonal flips) are kept
on `TileData` (`flipHorizontal`, `flipVertical`, `flipDiagonal`, packed into
`flipFlags` with the bits in `TileFlipFlags`: `horizontal` 1, `vertical` 2,
`diagonal` 4). The extractor turns them into a rotation about the tile's
centre plus a horizontal mirror where needed, so every orientation draws as
it does in Tiled (a diagonal flip of a non-square tile keeps it on the cell's
bottom-left corner). `tileToSprite(...)` does the conversion, for a custom
extractor: give it the cell (`tileTopLeft`, `tileWidth`, `tileHeight`), the
tile's `sourceRect` (its size) and, optionally, `drawOffset` for the
tileset's tile offset.

## Seams between tiles

Gaps or lines between tiles at fractional zoom levels or camera positions are
a sampling problem, not a tilemap one. A pixel-perfect camera and integer
zoom avoid them; see [Pixel Art](/docs/rendering/pixel-art).

## Deprecated extraction types

| Deprecated | Use |
|---|---|
| `CulledTilemapExtractor` | `TilemapExtractor`, which culls itself. The old class is the same extractor with a 96-unit margin: `TilemapExtractor(cullMargin: 96)` |
| `ExtractedTile` | `ExtractedSprite`, which is what the extractor emits. `TilemapExtractor(emitLegacyTiles: true)` still adds an `ExtractedTile` per tile for code that reads them; it doubles the render world's entities |

## See also

- [Tiled Maps](/docs/gameplay/tiled)
- [Rendering Overview](/docs/rendering/overview)
- [Cameras](/docs/rendering/cameras)
- [Sprites & Animation](/docs/rendering/sprites-animation)
- [fledge_tiled API reference](https://pub.dev/documentation/fledge_tiled/latest/)
