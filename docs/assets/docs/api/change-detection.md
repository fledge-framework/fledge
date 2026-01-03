# Change Detection API

Runtime component change tracking for reactive systems.

## Tick

Represents a frame counter for change tracking.

```dart
class Tick {
  int get value;
  void advance();
  void reset();
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `int` | Current tick value |

### Methods

| Method | Description |
|--------|-------------|
| `advance()` | Increment the tick counter |
| `reset()` | Reset tick to zero |

## ComponentTicks

Tracks when a component was added and last changed.

```dart
class ComponentTicks {
  int addedTick;
  int changedTick;

  bool isAdded(int lastRun, int current);
  bool isChanged(int lastRun, int current);
  void markChanged(int tick);
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `addedTick` | `int` | Tick when component was added |
| `changedTick` | `int` | Tick when component was last changed |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `isAdded(lastRun, current)` | `bool` | True if added after lastRun |
| `isChanged(lastRun, current)` | `bool` | True if changed after lastRun |
| `markChanged(tick)` | `void` | Update the changed tick |

## Changed<T>

Query filter that matches entities where component T changed.

```dart
class Changed<T> extends QueryFilter {
  const Changed();
}
```

### Usage

```dart
// Filter for changed Position components
for (final (entity, pos) in world.query1<Position>(
  filter: Changed<Position>(),
).iter()) {
  // Only entities where Position changed this frame
}
```

## Added<T>

Query filter that matches entities where component T was just added.

```dart
class Added<T> extends QueryFilter {
  const Added();
}
```

### Usage

```dart
// Filter for newly added Enemy components
for (final (entity, enemy) in world.query1<Enemy>(
  filter: Added<Enemy>(),
).iter()) {
  // Only entities that just received Enemy this frame
}
```

## Combining Filters

Change filters can be combined with other filters using `And`:

```dart
// Changed Position AND has Enemy marker
final filter = And([Changed<Position>(), With<Enemy>()]);

// Query usage
for (final (entity, pos) in world.query1<Position>(
  filter: And([Changed<Position>(), With<Enemy>()]),
).iter()) {
  // Process enemies with changed positions
}
```

Note: There is no `Or` filter - use separate queries if you need OR logic.

## World Tick Methods

The World maintains the global tick counter:

```dart
extension on World {
  int get currentTick;
  void advanceTick();
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `currentTick` | `int` | Current frame tick |

### Methods

| Method | Description |
|--------|-------------|
| `advanceTick()` | Advance to next frame (called by App) |

## Example

Complete change detection example:

```dart
final world = World();

// Spawn entity
final entity = world.spawn()
  ..insert(Position(0, 0));

// First frame - Position was just added
for (final (e, pos) in world.query1<Position>(
  filter: Added<Position>(),
).iter()) {
  print('Position added: $e'); // Prints
}

world.advanceTick();

// Second frame - Position not added this frame
for (final (e, pos) in world.query1<Position>(
  filter: Added<Position>(),
).iter()) {
  print('Position added: $e'); // Does not print
}

// Modify position
world.get<Position>(entity.entity)!.x = 100;

// Position changed this frame
for (final (e, pos) in world.query1<Position>(
  filter: Changed<Position>(),
).iter()) {
  print('Position changed: $e'); // Prints
}
```

## See Also

- [Change Detection Guide](/docs/guides/change-detection)
- [Queries](/docs/api/query)
- [Observers](/docs/api/observer)
