# Introduction

Fledge is a game framework for Dart and Flutter built on an Entity Component
System (ECS), modelled on [Bevy](https://bevyengine.org/). Your game state is
plain Dart objects attached to entities; your game logic is systems that query
for them. Fledge schedules the systems, keeps them in a predictable order, and
provides packages for rendering, input, audio, physics, tilemaps, dialogue,
saving and networking.

It targets desktop first (Windows, macOS and Linux). The web and mobile work on
a best-effort basis; each package page says where it stands.

## The idea in one example

<!-- snippet-setup
class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy;
  Velocity(this.dx, this.dy);
}

class Health {
  int value;
  Health(this.value);
}

class Player {
  const Player();
}
-->

An **entity** is an ID. **Components** are the data you attach to it:

```dart
final world = World();

final player = world.spawnWith([
  Position(0, 0),
  Velocity(40, 0),
  Health(100),
  const Player(),
]);

// A crate: no Velocity, no Health. Nothing to inherit, nothing to override.
world.spawnWith([Position(120, 0)]);
```

A **system** is logic that runs every frame over every entity that has the
components it asks for:

```dart
class MovementSystem extends System {
  static const String systemName = 'movement';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Velocity>()},
    writes: {ComponentId.of<Position>()},
    resourceReads: {WallTime},
  );

  @override
  void run(World world) {
    final dt = world.getResource<WallTime>()!.delta;
    for (final (_, pos, vel) in world.query2<Position, Velocity>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;
    }
  }
}
```

The player moves; the crate doesn't, because it has no `Velocity`. Give the
crate a `Velocity` later and it starts moving, with no code change. That is
the point of ECS: behaviour comes from which data an entity has, so features
compose instead of fighting over a class hierarchy.

The `SystemMeta` declares what the system touches. Fledge uses it to order
systems that conflict, and `App.checkScheduleOrdering()` tells you when two
conflicting systems have no explicit order.

## What you get

- **Core ECS** (`fledge_ecs`, pure Dart): archetype storage, queries with
  filters, resources, events, commands, hierarchies, observers, change
  detection, states and run conditions.
- **Scheduling**: named schedules for each part of the frame, a fixed-timestep
  chain for physics, explicit `before`/`after` ordering and system sets.
- **A plugin for each concern**: rendering (sprites, cameras, lighting,
  particles), input, window, audio, physics, Tiled maps, Yarn dialogue, save
  games, an in-game calendar and multiplayer networking. See the
  [Package Catalog](/docs/app/packages).
- **Optional code generation**: write systems as annotated functions and let
  `fledge_ecs_generator` produce the wrapper classes. See
  [Code Generation](/docs/app/codegen).

Systems run one at a time, in an order computed once per schedule: Dart runs
your game on a single isolate, and Fledge doesn't pretend otherwise.

## How these docs are organised

1. **Getting Started** (here): [install](/docs/getting-started/installation),
   [build a first app](/docs/getting-started/first-app), read the
   [core concepts](/docs/getting-started/core-concepts), then
   [make Snake](/docs/getting-started/tutorial-snake).
2. **ECS** and **Scheduling & Time**: the core, one topic per page.
3. **App & Tooling**, **Rendering**, **UI & Tools**, **Platform**,
   **Gameplay**, **Networking**: one page per package or feature.
4. **Examples**: walkthroughs of the runnable programs in the repository.
5. **API Reference**: the dartdoc for every package on pub.dev.

## Before you start

You should be comfortable with Dart (classes, generics, records) and, for a
game with graphics, with basic Flutter widgets. You don't need game
development experience.

Next: [Installation](/docs/getting-started/installation).
