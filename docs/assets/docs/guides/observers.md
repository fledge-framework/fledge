# Observers Guide

Observers provide reactive triggers that fire when components are added, removed, or changed.

## Overview

Observers let you:

- React immediately to component lifecycle events
- Decouple systems that respond to changes
- Implement event-driven patterns without polling
- Build reactive game systems

## Registering Observers

### On Add

Triggered when a component is first added to an entity:

```dart
world.observers.register(Observer<Enemy>.onAdd((world, entity, enemy) {
  print('Enemy spawned: $entity');
  world.insertResource(EnemyCount(
    world.getResource<EnemyCount>()!.count + 1
  ));
}));
```

### On Remove

Triggered when a component is removed or the entity is despawned:

```dart
world.observers.register(Observer<Health>.onRemove((world, entity, health) {
  if (health.current <= 0) {
    print('Entity $entity died');
    world.eventWriter<DeathEvent>().send(DeathEvent(entity));
  }
}));
```

### On Change

Triggered when a component is modified (not on initial add):

```dart
world.observers.register(Observer<Score>.onChange((world, entity, score) {
  print('Score changed to ${score.value}');
  updateScoreDisplay(score.value);
}));
```

## Multiple Observers

Register multiple observers for the same component type:

```dart
// Logging observer
world.observers.register(Observer<Position>.onChange((w, e, p) {
  log('Position changed: $e -> (${p.x}, ${p.y})');
}));

// Bounds checking observer
world.observers.register(Observer<Position>.onChange((w, e, p) {
  p.x = p.x.clamp(0, worldWidth);
  p.y = p.y.clamp(0, worldHeight);
}));
```

Both observers will be called when Position changes.

## Unregistering Observers

Remove observers when no longer needed:

```dart
final observer = Observer<Enemy>.onAdd((w, e, enemy) {
  // Handle enemy spawn
});

world.observers.register(observer);

// Later...
world.observers.unregister(observer);
```

## Common Patterns

### Spawning Side Effects

Create related entities when something spawns:

```dart
world.observers.register(Observer<Explosion>.onAdd((world, entity, explosion) {
  // Spawn particle effects
  for (var i = 0; i < 20; i++) {
    world.spawn()
      ..insert(Particle())
      ..insert(Position(explosion.x, explosion.y))
      ..insert(Velocity.random());
  }

  // Play sound
  world.eventWriter<PlaySound>().send(PlaySound('explosion.wav'));
}));
```

### Cleanup on Removal

Clean up resources when entities are removed:

```dart
world.observers.register(Observer<AudioSource>.onRemove((world, entity, audio) {
  audio.stop();
  audio.dispose();
}));

world.observers.register(Observer<NetworkPlayer>.onRemove((world, entity, player) {
  networkManager.disconnect(player.connectionId);
}));
```

### Derived State

Update derived state when source changes:

```dart
world.observers.register(Observer<Inventory>.onChange((world, entity, inv) {
  // Recalculate total weight
  var totalWeight = 0.0;
  for (final item in inv.items) {
    totalWeight += item.weight;
  }
  world.insert(entity, CarryWeight(totalWeight));
}));
```

### Event Translation

Convert component changes to events:

```dart
world.observers.register(Observer<Health>.onChange((world, entity, health) {
  if (health.current <= 0) {
    world.eventWriter<EntityDied>().send(EntityDied(entity));
  } else if (health.current < health.max * 0.25) {
    world.eventWriter<EntityLowHealth>().send(EntityLowHealth(entity));
  }
}));
```

### Hierarchical Updates

Propagate changes through hierarchies:

```dart
world.observers.register(Observer<Transform>.onChange((world, entity, transform) {
  // Update all children
  for (final child in world.getChildren(entity)) {
    final localTransform = world.get<LocalTransform>(child);
    if (localTransform != null) {
      world.insert(child, Transform(
        x: transform.x + localTransform.x,
        y: transform.y + localTransform.y,
        rotation: transform.rotation + localTransform.rotation,
      ));
    }
  }
}));
```

## Observer vs Change Detection

| Feature | Observers | Change Detection |
|---------|-----------|------------------|
| When | Immediate | During query iteration |
| Use case | Side effects, events | Batch processing |
| Overhead | Per-change callback | Per-query filter |
| Best for | Reactive logic | Bulk updates |

Use observers for immediate reactions, change detection for batch processing.

## Performance Tips

- Keep observer callbacks fast
- Avoid spawning many entities in observers
- Use events for complex cross-system communication
- Unregister observers when no longer needed

## See Also

- [Change Detection](/docs/guides/change-detection) - Query-based change detection
- [Events](/docs/guides/events) - Event communication
- [Observer API](/docs/api/observer) - API reference
