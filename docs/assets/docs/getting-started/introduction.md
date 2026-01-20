# Introduction to Fledge

Welcome! Fledge is a modern game framework for Flutter that brings the power of Entity Component System (ECS) architecture to Dart. If you've used Bevy (Rust), you'll feel right at home. If not, don't worry - we'll guide you through everything you need to know.

## What You'll Build

By the end of the Getting Started guide, you'll:

1. **Understand ECS** - Learn why separating data from logic makes games easier to build
2. **Set up a project** - Install Fledge and configure your development environment
3. **Create your first game** - Build a working Snake game from scratch

Here's a preview of what you'll create:

```
+---------------------------+
|  Score: 5                 |
|                           |
|       * * *               |
|           *               |
|           @               |
|                           |
|             o             |
+---------------------------+
```

A classic Snake game with player movement, food collection, and collision detection - all built using clean ECS architecture.

## What is Fledge?

Fledge is a **desktop-first** game framework that provides:

- **Clean ECS architecture** - Separate data (components) from logic (systems)
- **Archetype-based storage** - Excellent cache locality for fast iteration
- **Automatic parallelism** - Systems run concurrently when they don't conflict
- **Code generation** - Optional annotations to reduce boilerplate
- **Modular plugins** - Add only what you need (rendering, audio, input, physics)

## Why ECS?

Traditional game development often uses deep inheritance hierarchies:

```dart
// Traditional OOP - gets messy fast
class Player extends Character {
  // Character extends Entity
  // Entity extends GameObject
  // What if I want a Player that's also a Vehicle?
}
```

With ECS, you compose game objects from small, focused pieces:

```dart
// ECS approach - flexible and clean
final player = world.spawn()
  ..insert(Position(0, 0))    // Where it is
  ..insert(Velocity(0, 0))    // How it moves
  ..insert(Health(100))       // Can take damage
  ..insert(Player());         // It's the player

// Want a rideable mount? Just add components!
final mount = world.spawn()
  ..insert(Position(0, 0))
  ..insert(Velocity(0, 0))
  ..insert(Health(200))
  ..insert(Mount())
  ..insert(Rideable());
```

### The Three Pillars of ECS

| Concept | What It Is | Example |
|---------|------------|---------|
| **Entity** | A unique ID | `Entity(id: 42)` |
| **Component** | Data attached to an entity | `Position(x: 10, y: 20)` |
| **System** | Logic that processes components | "Move all entities with Position and Velocity" |

**Entities** are just IDs - they have no data or behavior on their own.

**Components** are pure data containers - `Position`, `Health`, `Sprite`, etc.

**Systems** are functions that query for entities with specific components and process them:

```dart
// This system runs every frame on all entities with Position and Velocity
void movementSystem(World world) {
  for (final (entity, pos, vel) in world.query2<Position, Velocity>().iter()) {
    pos.x += vel.dx;
    pos.y += vel.dy;
  }
}
```

## Fledge vs Other Frameworks

| Feature | Fledge | Flame | Unity |
|---------|--------|-------|-------|
| Architecture | Pure ECS | Component-based | Hybrid ECS |
| Language | Dart | Dart | C# |
| Platform Focus | Desktop | Mobile-first | Cross-platform |
| Parallelism | Automatic | Manual | Jobs system |
| Type Safety | Strong (Dart) | Moderate | Weak (runtime) |

Fledge is inspired by [Bevy](https://bevyengine.org/), the popular Rust game engine. If you're coming from Bevy, you'll find familiar concepts like:

- Archetype-based ECS
- Plugin architecture
- Schedule stages
- Change detection
- Two-world rendering architecture

## Prerequisites

Before starting, you should have:

- Basic Dart/Flutter knowledge (variables, classes, functions)
- Flutter SDK 3.10+ installed
- A code editor (VS Code recommended)

No game development experience required! We'll explain everything as we go.

## Next Steps

Ready to begin? Let's [install Fledge](/docs/getting-started/installation) and set up your project.
