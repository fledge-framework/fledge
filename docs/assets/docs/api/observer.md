# Observer API

Reactive triggers for component lifecycle events.

## TriggerKind

Enum defining when observers trigger.

```dart
enum TriggerKind {
  onAdd,    // Component added to entity
  onRemove, // Component removed from entity
  onChange, // Component modified (not on initial add)
}
```

## Observer<T>

An observer that reacts to component lifecycle events.

```dart
class Observer<T> {
  final TriggerKind trigger;
  final ObserverCallback<T> callback;

  Observer.onAdd(ObserverCallback<T> callback);
  Observer.onRemove(ObserverCallback<T> callback);
  Observer.onChange(ObserverCallback<T> callback);
}

typedef ObserverCallback<T> = void Function(World world, Entity entity, T component);
```

### Constructors

| Constructor | Trigger |
|-------------|---------|
| `Observer.onAdd(callback)` | When component is added |
| `Observer.onRemove(callback)` | When component is removed |
| `Observer.onChange(callback)` | When component is modified |

### Callback Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `world` | `World` | The world instance |
| `entity` | `Entity` | The affected entity |
| `component` | `T` | The component value |

## Observers

Registry for managing observers.

```dart
class Observers {
  void register<T>(Observer<T> observer);
  bool unregister<T>(Observer<T> observer);
  void triggerOnAdd<T>(World world, Entity entity, T component);
  void triggerOnRemove<T>(World world, Entity entity, T component);
  void triggerOnChange<T>(World world, Entity entity, T component);
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `register<T>(observer)` | `void` | Add an observer |
| `unregister<T>(observer)` | `bool` | Remove an observer, returns true if found |
| `triggerOnAdd<T>(...)` | `void` | Fire all onAdd observers for type |
| `triggerOnRemove<T>(...)` | `void` | Fire all onRemove observers for type |
| `triggerOnChange<T>(...)` | `void` | Fire all onChange observers for type |

## World Observer Access

```dart
class World {
  final Observers observers;
}
```

Observers are automatically triggered by World operations:

| Operation | Trigger |
|-----------|---------|
| `world.insert(entity, component)` | `onAdd` (new) or `onChange` (existing) |
| `world.remove<T>(entity)` | `onRemove` |
| `world.despawn(entity)` | `onRemove` for all components |

## Examples

### Basic Registration

```dart
// Register an onAdd observer
world.observers.register(Observer<Enemy>.onAdd((world, entity, enemy) {
  print('Enemy spawned: $entity');
}));

// Register an onRemove observer
world.observers.register(Observer<Health>.onRemove((world, entity, health) {
  print('Health removed from $entity');
}));

// Register an onChange observer
world.observers.register(Observer<Score>.onChange((world, entity, score) {
  print('Score is now ${score.value}');
}));
```

### Spawning Triggers OnAdd

```dart
world.observers.register(Observer<Position>.onAdd((w, e, p) {
  print('Position added'); // Fires
}));

world.spawn()..insert(Position(0, 0));
```

### Modification Triggers OnChange

```dart
world.observers.register(Observer<Position>.onChange((w, e, p) {
  print('Position changed'); // Fires
}));

final entity = world.spawn()..insert(Position(0, 0));
world.insert(entity.entity, Position(10, 10)); // Triggers onChange
```

### Despawn Triggers OnRemove

```dart
world.observers.register(Observer<Enemy>.onRemove((w, e, enemy) {
  print('Enemy removed'); // Fires
}));

final entity = world.spawn()..insert(Enemy());
world.despawn(entity.entity); // Triggers onRemove
```

### Unregistering

```dart
final observer = Observer<Position>.onAdd((w, e, p) {
  print('Position added');
});

world.observers.register(observer);
// ... later ...
world.observers.unregister(observer); // Returns true
```

### Multiple Observers

```dart
// Multiple observers for same type
world.observers.register(Observer<Health>.onChange((w, e, h) {
  print('Observer 1: ${h.current}');
}));

world.observers.register(Observer<Health>.onChange((w, e, h) {
  print('Observer 2: ${h.current}');
}));

// Both fire when Health changes
```

## Use Cases

### Event Broadcasting

```dart
world.observers.register(Observer<Dead>.onAdd((world, entity, _) {
  world.eventWriter<EntityDied>().send(EntityDied(entity));
}));
```

### Resource Tracking

```dart
world.observers.register(Observer<Enemy>.onAdd((world, entity, _) {
  final count = world.getResource<EnemyCount>()!;
  world.insertResource(EnemyCount(count.value + 1));
}));

world.observers.register(Observer<Enemy>.onRemove((world, entity, _) {
  final count = world.getResource<EnemyCount>()!;
  world.insertResource(EnemyCount(count.value - 1));
}));
```

### Cleanup

```dart
world.observers.register(Observer<Texture>.onRemove((world, entity, texture) {
  texture.dispose();
}));
```

## See Also

- [Observers Guide](/docs/guides/observers)
- [Change Detection](/docs/api/change-detection)
- [Events](/docs/guides/events)
