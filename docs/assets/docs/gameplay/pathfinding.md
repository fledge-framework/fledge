# Pathfinding

`fledge_physics` includes A* pathfinding on a grid: a `CollisionGrid` says
which cells are walkable and what each costs to cross, and a `Pathfinder`
finds the cheapest route between two cells. Helpers then turn the cell path
into something a character can walk: straightened, kept to the middle of a
road, or kept to one side of it like traffic.

Everything on this page is plain Dart with no ECS dependency, so you can call
it from a system, a resource, a test or a tool. `fledge_tiled` builds grids
from Tiled maps ([below](#grids-from-tiled-maps)).

## What you need

```yaml
dependencies:
  fledge_physics: ^0.6.0
```

Flutter 3.50+, like the rest of `fledge_physics`
(see [Physics](/docs/gameplay/physics#what-you-need)). The pathfinding code
itself has no platform dependencies.

## Finding a path

```dart
final grid = CollisionGrid(width: 20, height: 15);
grid.setRegionBlocked(8, 0, 1, 10); // a wall, 1 cell wide and 10 tall

const pathfinder = Pathfinder();
final result = pathfinder.findPath(grid, 2, 2, 15, 2);

if (result.success) {
  for (final (x, y) in result.path!) {
    print('step to ($x, $y)');
  }
} else {
  print('no path: ${result.failureReason}');
}
```

Coordinates are cell indices: `(0, 0)` is the top-left cell, `x` grows right
and `y` grows down.

`PathResult`:

| Member | Meaning |
|---|---|
| `success` | Whether a path was found |
| `path` | The cells to walk through, **excluding the start** and including the goal. Empty when start equals goal; `null` on failure |
| `pathLength` | `path.length`, or `-1` on failure |
| `failureReason` | Why it failed (below), or `null` |
| `nodesExplored` | Cells the search expanded, for profiling |

The failure reasons are plain strings:

| `failureReason` | When |
|---|---|
| `'Start position is not walkable'` | Start is blocked or outside the grid |
| `'Goal position is not walkable'` | Goal is blocked or outside the grid |
| `'No path exists'` | The goal can't be reached |
| `'Pathfinding exceeded maximum iterations (N)'` | The search gave up after `maxIterations` cells |

`hasPath(grid, sx, sy, gx, gy)` answers whether any path exists, the same
yes or no as `findPath(...).success`, more cheaply: reachability doesn't
depend on cell costs, so it runs a greedy search that heads for the goal and
stops when it gets there, with no costs to weigh and no path to build. The
same diagonal and corner-cutting rules and `maxIterations` budget apply
(usually far fewer cells are visited, so it can answer yes where a
cost-weighted `findPath` on the same budget gives up).

### Options

```dart
const pathfinder = Pathfinder(
  maxIterations: 10000, // cells to expand before giving up
  allowDiagonal: true, // 8 directions; false for 4
  allowCornerCutting: false, // may a diagonal step squeeze past a wall corner?
);
```

| Option | Default | Meaning |
|---|---|---|
| `maxIterations` | `10000` | Upper bound on cells expanded, so a hopeless search on a big map can't stall a frame. Raise it for large maps |
| `allowDiagonal` | `true` | Diagonal steps cost `Pathfinder.diagonalCost` (1.414) |
| `allowCornerCutting` | `false` | When false, a diagonal step needs both cells beside it walkable, so paths don't clip wall corners |

A `Pathfinder` holds no state, so one `const` instance can serve every search.
Searches run synchronously on the calling isolate. A town-sized grid (tens of
thousands of cells) searches in well under a frame, but don't run hundreds of
searches per frame: find a path when a character's goal changes, store it,
and walk it over the next frames.

## The grid

```dart
final grid = CollisionGrid(width: 64, height: 48); // all walkable

grid.setBlocked(10, 4);
grid.setWalkable(10, 4);
grid.set(11, 4, false);
grid.setRegionBlocked(20, 10, 5, 3); // x, y, width, height
grid.setRegionWalkable(21, 11, 3, 1); // a doorway

final walkable = grid.isWalkable(10, 4);
final blocked = grid.isBlocked(-1, 0); // true: outside counts as blocked

final snapshot = grid.copy(); // walkability and costs
grid.clear(); // all walkable
grid.fill(); // all blocked
print('${snapshot.walkableCount} open, ${snapshot.blockedCount} blocked');
```

`CollisionGrid.fromData(rows)` builds one from a `List<List<bool>>` where
`rows[y][x]` is true when walkable. The list is used as is, not copied.

The setters ignore cells outside the grid.

## Movement costs

Every walkable cell costs 1.0 until you set it. A step costs its length (1
straight, 1.414 diagonal) times the average cost of the two cells it joins,
and the pathfinder returns the cheapest path. Make roads cheap and open ground
dear and walkers keep to the roads, leaving them only where the detour would
cost more than cutting across:

```dart
final grid = CollisionGrid(width: 30, height: 30);
for (var y = 0; y < 30; y++) {
  for (var x = 0; x < 30; x++) {
    grid.setCost(x, y, 3.0); // grass: worth up to a 3x detour to avoid
  }
}
for (var x = 0; x < 30; x++) {
  grid.setCost(x, 15, 1.0); // a road across the middle
}

print(grid.costAt(0, 15)); // 1.0
print(grid.minCost); // 1.0
```

- `setCost` throws an `ArgumentError` for a cost that isn't positive.
- `costAt` returns 1.0 for cells outside the grid.
- The A* estimate assumes every remaining step costs `grid.minCost`, so it
  never overestimates and paths stay optimal. The flip side: one very cheap
  cell anywhere makes every search explore more of the map. Keep your
  cheapest cost at 1.0 and make other ground dearer, rather than making roads
  cheaper than 1.

## Turning cells into waypoints

A path is a list of cells. To walk it, convert each cell to a point. The
helpers below work in **grid cells as continuous values**: cell `(x, y)`
covers `x <= px < x + 1`, so its centre is `(x + 0.5, y + 0.5)`. Multiply by
your tile size for world coordinates.

```dart
const tileSize = 16.0;

/// The world position of a waypoint in cell units.
(double, double) toWorld((double, double) p) =>
    (p.$1 * tileSize, p.$2 * tileSize);

/// The cell a world position is in.
(int, int) toCell(double x, double y) =>
    ((x / tileSize).floor(), (y / tileSize).floor());
```

### Straightening: `smoothPath`

A raw path zigzags from cell to cell. `smoothPath` drops every waypoint a
walker could skip by heading straight on, where the straight line stays on
walkable cells and costs no more than the stretch of path it replaces. So a
walker cuts the corner of a road, but not across the grass beside it. With
every cost at 1.0 it's plain line-of-sight smoothing.

```dart
final grid = CollisionGrid(width: 20, height: 20);
final (sx, sy) = (1, 1);
final cells = const Pathfinder().findPath(grid, sx, sy, 18, 12).path!;

final waypoints = smoothPath(
  grid,
  (sx + 0.5, sy + 0.5), // where the walker is now
  [for (final (x, y) in cells) (x + 0.5, y + 0.5)],
  slack: 1.0, // cost tolerance for a shortcut, in cost-weighted cells
  sampleStep: 0.25, // spacing of walkability samples along a line, in cells
);
```

The result is the kept points, ending at the goal; the start isn't included.
Lines are checked by sampling every `sampleStep` cells, so a wall narrower
than that can be missed. `smoothPath` only checks cells: a shortcut through a
gap barely wider than the walker can clip a wall. `simplifyPath` (below)
takes your own fit check.

### Walking like people: lanes

Smoothing makes paths cut diagonally across roads and hug the inside of every
bend. For people in a town, shape the grid and the path instead:

1. **`EdgeDistance.of(grid)`** measures how far each walkable cell is from
   the edge of its ground: a blocked cell, the map's bounds, or dearer ground.
   Pass `wallsAreEdges: false` to measure by the ground alone, so benches and
   lamp posts on a square don't push paths around. Rebuild it if walls or
   costs change.
2. **`preferCentres(grid, edges)`** makes the sides of every stretch of
   ground dearer (by `edgeCost`, default 0.5, fading out `reach` cells in,
   default 3), so A* follows the middle of the road. It changes the grid's
   costs, so call it once when you build the grid.
3. **`keepToSide(grid, edges, points)`** moves each waypoint to one side of
   the direction of travel (`side: Side.right` by default), by `share` of the
   distance to the edge there, at most `maxOffset` cells. Walkers going
   opposite ways take opposite halves of a road. The offset eases in and out
   over the first and last `taper` points, so the path still starts and ends
   where it did.
4. **`simplifyPath(grid, points)`** drops waypoints that lie within
   `tolerance` cells of a straight line between their neighbours
   (Ramer-Douglas-Peucker). Runs of grid steps become straight walks, and
   bends stay where they are: it never cuts a corner. First and last points
   are kept.

```dart
final grid = CollisionGrid(width: 40, height: 30);
final edges = EdgeDistance.of(grid, wallsAreEdges: false);
preferCentres(grid, edges); // once, when the grid is built

final (sx, sy) = (2, 2);
final result = const Pathfinder().findPath(grid, sx, sy, 35, 25);
if (result.success) {
  final cells = [(sx, sy), ...result.path!];
  final centres = [for (final (x, y) in cells) (x + 0.5, y + 0.5)];
  final way = simplifyPath(grid, keepToSide(grid, edges, centres));
  print(way);
}
```

Note that the start cell goes in front of the path here, since
`keepToSide` and `simplifyPath` keep the first point.

### Not clipping walls: `PathFits`

The grid only knows whole cells, judged at their centres, so a point moved
off a centre (a lane, a straightened run) can clip a wall in a gap barely
wider than the walker. Give `keepToSide` and `simplifyPath` your own geometry
as `fits`, a `PathFits` (`bool Function(double x, double y)`: does the walker
fit with their feet exactly here, in cell units?). `keepToSide` then shifts a
point no further than the walker fits, and `simplifyPath` keeps a bend
wherever the straight run wouldn't fit.

```dart
/// Solid rectangles in world pixels, e.g. from your level's colliders.
final walls = <Rect>[const Rect.fromLTWH(160, 0, 16, 160)];
const tileSize = 16.0;

bool fits(double x, double y) {
  final feet = Rect.fromCenter(
    center: Offset(x * tileSize, y * tileSize),
    width: 12,
    height: 6,
  );
  return !walls.any(feet.overlaps);
}

final grid = CollisionGrid(width: 20, height: 20);
final edges = EdgeDistance.of(grid);
final centres = [for (var x = 2; x < 18; x++) (x + 0.5, 12.5)];
final way = simplifyPath(
  grid,
  keepToSide(grid, edges, centres, fits: fits),
  fits: fits,
);
```

## Using it in a game

Keep the grid in a resource, compute a path when a character's target
changes, and let a per-frame system walk it:

```dart
class LevelGrid {
  final CollisionGrid grid;
  LevelGrid(this.grid);
}

/// Added to an NPC to send it somewhere.
class GoTo {
  final int x, y;
  GoTo(this.x, this.y);
}

/// The waypoints still ahead, in cell units.
class Route {
  final List<(double, double)> points;
  Route(this.points);
}

/// A grid-position component for this example; a real game would use
/// Transform2D.
class Cell {
  double x, y;
  Cell(this.x, this.y);
}

class PlanRoutesSystem extends System {
  static const String systemName = 'plan_routes';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<GoTo>(), ComponentId.of<Cell>()},
    resourceReads: {LevelGrid},
  );

  @override
  void run(World world) {
    final grid = world.getResource<LevelGrid>()?.grid;
    if (grid == null) return;
    final commands = Commands();
    for (final (entity, goTo, at) in world.query2<GoTo, Cell>().iter()) {
      final sx = at.x.floor(), sy = at.y.floor();
      final result = const Pathfinder().findPath(grid, sx, sy, goTo.x, goTo.y);
      commands.remove<GoTo>(entity);
      if (!result.success) continue;
      final points = smoothPath(grid, (at.x, at.y), [
        for (final (x, y) in result.path!) (x + 0.5, y + 0.5),
      ]);
      commands.insert(entity, Route(points));
    }
    commands.apply(world);
  }
}
```

Because `GoTo` is removed once handled, each request is searched once, not
every frame. Register it with `app.addSystem(PlanRoutesSystem(), schedule:
Schedules.update)`; a walking system then moves each `Cell` toward
`route.points.first` and drops points as it reaches them.

If walls change (a door closes, a building is placed), update the grid and
re-plan the routes that cross the change.

## Grids from Tiled maps

`fledge_tiled` builds grids from a map's collision layers: any non-empty tile
in those layers marks its cell blocked. The grid is one cell per tile.

```dart
CollisionGrid gridFor(TilemapAsset tilemap) {
  // Default layer names: {'Collision', 'collision'}.
  return extractCollisionGrid(tilemap, collisionLayers: {'Collision', 'Walls'});
}

CollisionGrid gridFromTmx(String tmx) {
  // Parses only the layers: no textures or tilesets loaded.
  return extractCollisionGridFromTmx(
    tmx,
    mapWidth: 100, // in tiles
    mapHeight: 80,
    collisionLayers: {'Collision'},
  );
}
```

- `extractCollisionGrids({'town': town, 'mine': mine})` does several maps at
  once and returns a `Map<String, CollisionGrid>`.
- `extractCollisionGridFromTmx` is the cheap way to preload grids for maps
  the player hasn't visited (for NPCs walking there off-screen). If the TMX
  fails to parse, it throws the parser's error.
- On an **infinite (chunked) map**, `extractCollisionGrid` covers the
  bounding box of the collision layers' chunks, which can start at negative
  tile coordinates. `collisionGridOrigin(tilemap)` (with the same
  `collisionLayers`) is the tile at cell (0, 0); it's (0, 0) on a finite
  map. `extractCollisionGridFromTmx` puts tile (x, y) in cell (x, y) and
  drops chunk tiles outside the size you give it.

Convert between tiles and cells with the origin:

```dart
List<(int, int)>? tilePath(TilemapAsset tilemap, (int, int) from, (int, int) to) {
  final grid = extractCollisionGrid(tilemap);
  final origin = collisionGridOrigin(tilemap);
  final result = const Pathfinder().findPath(
    grid,
    from.$1 - origin.x,
    from.$2 - origin.y,
    to.$1 - origin.x,
    to.$2 - origin.y,
  );
  final path = result.path;
  if (path == null) return null; // no path
  return [for (final (x, y) in path) (x + origin.x, y + origin.y)];
}
```

### Costs from painted terrain

If the map's ground is painted with Tiled's terrain brush (a corner or mixed
Wang set), `TerrainGrid` reads the terrain name at each tile corner, and
`applyTerrainCosts` turns it into costs:

```dart
void roadsAreCheap(TilemapAsset tilemap, CollisionGrid grid) {
  final terrain = TerrainGrid.fromTilemap(tilemap.map, layer: 'ground');
  print(terrain.terrainAt(100, 40)); // e.g. 'road', at map pixel (100, 40)

  applyTerrainCosts(
    grid,
    terrain,
    {'road': 1, 'path': 1},
    defaultCost: 3, // any other terrain, or none
  );
}
```

The terrain grid has a cell per tile corner, twice the map's size in tiles.
`applyTerrainCosts` takes a grid at that resolution or one cell per tile (as
`extractCollisionGrid` makes it), where each tile costs the average of its
four corners; any other size throws an `ArgumentError`. Build the
`TerrainGrid` from a map loaded by `AssetTilemapLoader` (directly, or as the
`tilemapLoader` of a `TmxLoader`), which restores the Wang data
`package:tiled` drops. Loading maps is covered in
[Tiled](/docs/gameplay/tiled).

## See also

- [Physics](/docs/gameplay/physics)
- [Tiled](/docs/gameplay/tiled)
- [`fledge_physics` API reference](https://pub.dev/documentation/fledge_physics/latest/)
