# Events

Events are typed messages between systems. One system sends a
`DamageEvent`; any number of others read it, without knowing about each
other.

<!-- snippet-setup
class Health {
  int current;
  Health(this.current);
}

class DamageEvent {
  final Entity target;
  final int amount;
  const DamageEvent(this.target, this.amount);
}

class DeathEvent {
  final Entity entity;
  const DeathEvent(this.entity);
}
-->

## Defining and registering

An event is any class, typically small and immutable:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

class DamageEvent {
  final Entity target;
  final int amount;
  const DamageEvent(this.target, this.amount);
}
```

Register each event type before anything reads or writes it:

```dart
final app = App()
  ..addEvent<DamageEvent>()
  ..addEvent<DeathEvent>();

// Or on a bare World:
final world = World()..registerEvent<DamageEvent>();
```

`world.eventReader<T>()` and `eventWriter<T>()` throw a `StateError` for an
unregistered type. Registering a type again replaces its queue and drops
pending events, so register once, in your plugin's `build`.

## Sending and reading

```dart
class DamageSystem extends System {
  static const String systemName = 'damage';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<Health>()},
    eventReads: {DamageEvent},
    eventWrites: {DeathEvent},
  );

  @override
  void run(World world) {
    final deaths = world.eventWriter<DeathEvent>();
    for (final event in world.eventReader<DamageEvent>().read()) {
      final health = world.get<Health>(event.target);
      if (health == null) continue; // target already gone
      health.current -= event.amount;
      if (health.current <= 0) deaths.send(DeathEvent(event.target));
    }
  }
}
```

- `EventWriter<T>`: `send(event)` and `sendBatch(iterable)`.
- `EventReader<T>`: `read()`, `length`, `isEmpty`, `isNotEmpty`.
- `EventReadWriter<T>`: both, for a system that reads and sends the same type
  (mainly for generated systems).

```dart
final world = World()..registerEvent<DamageEvent>();
final a = world.spawnWith([Health(10)]);
final b = world.spawnWith([Health(10)]);

world.eventWriter<DamageEvent>().sendBatch([
  DamageEvent(a, 3),
  DamageEvent(b, 3),
]);
```

## Timing: events are double-buffered

Each event type has two buffers. `send` writes to the current one; `read`
returns the previous one. At the start of every `App.tick` (before any
schedule, including startup) the buffers swap and the old ones are dropped.
So:

- An event sent during frame N is readable during **frame N + 1**, in every
  schedule, and is gone in frame N + 2.
- A system never sees events sent in the same frame, whether the sender runs
  before or after it. Ordering a reader after a writer doesn't make it see the
  event sooner.
- Every reader sees every event. Reading doesn't consume.

A chain of reactions therefore advances one frame per hop: damage in frame 1,
`DeathEvent` sent in frame 2, despawn in frame 3.

A bare `World` doesn't swap on its own. If you drive one manually, call
`world.updateEvents()` once per frame.

### Events and the fixed timestep

The buffers swap once per *frame*, not once per fixed step. A system in
`Schedules.fixedUpdate` runs zero or more times per frame (see
[Time & Fixed Timestep](/docs/scheduling/time)), so:

- On a frame with **two fixed steps**, a fixed-step reader sees the same
  events in both steps.
- On a frame with **no fixed steps**, a fixed-step reader doesn't run, and the
  events it would have read are gone by the next frame.
- An event sent in one fixed step isn't readable in the next step of the same
  frame.

If a fixed-step system must handle each event exactly once, read events in a
per-frame schedule (such as `preUpdate`) and push them into a resource queue
the fixed step drains.

## Running only when events arrived

`RunConditions.onEvent<T>()` skips a system on frames with nothing to read (and
when `T` isn't registered):

```dart
final onDeath = FunctionSystem(
  'onDeath',
  eventReads: {DeathEvent},
  runIf: RunConditions.onEvent<DeathEvent>(),
  run: (world) {
    final commands = Commands();
    for (final event in world.eventReader<DeathEvent>().read()) {
      commands.despawn(event.entity);
    }
    commands.apply(world);
  },
);
```

## The `Events` registry

`world.events` holds every queue:

```dart
final world = World()..registerEvent<DamageEvent>();

world.events.isRegistered<DamageEvent>(); // true
final queue = world.events.tryQueue<DeathEvent>(); // null: not registered
world.events.clear(); // empty every queue (both buffers)
```

`App.resetToGameCheckpoint()` and `world.resetGameState()` clear all queues.

## Declaring event access

`eventReads`/`eventWrites` in `SystemMeta` make a reader and a writer of the same
type conflict, so `App.checkScheduleOrdering()` asks you to order them. Given
the buffering above, the order doesn't change which events a reader sees; pick
one (`after:` the writer reads naturally) to keep the report clean.

## Events or components?

| Events | Components |
|---|---|
| Something happened once ("took damage") | Ongoing state ("is burning") |
| Many independent listeners | Owned by one entity |
| Fine to arrive a frame later | Must be visible right away |

For reacting to a component being added or removed the moment it happens, see
[Observers](/docs/ecs/observers).

## See also

- [Systems](/docs/ecs/systems)
- [States & Run Conditions](/docs/ecs/states-run-conditions)
- [Time & Fixed Timestep](/docs/scheduling/time)
