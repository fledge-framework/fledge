# Hello Fledge

Let's create our first visual Fledge application - a bouncing square! This will introduce the core concepts in action: entities, components, systems, and the game loop.

## What We're Building

A simple animation where a colored square bounces around the screen:

```
+---------------------------+
|                           |
|     [ ]                   |
|        \                  |
|         \                 |
|          [ ]              |
|                           |
+---------------------------+
```

Not a game yet, but it demonstrates everything you need to know to build one.

## Step 1: Create Components

Components hold data. We need two: where the square is, and how fast it's moving.

Create `lib/game/components.dart`:

```dart
// Components are just plain Dart classes that hold data.
// No inheritance required, no special base class.

/// Where an entity is in 2D space
class Position {
  double x;
  double y;

  Position(this.x, this.y);
}

/// How fast an entity moves
class Velocity {
  double dx;
  double dy;

  Velocity(this.dx, this.dy);
}

/// Visual appearance
class Square {
  final double size;
  final int color; // ARGB color value

  Square({this.size = 40, this.color = 0xFF4CAF50});
}
```

Notice: these are just regular Dart classes. No annotations, no base classes. That's the beauty of ECS - your data stays simple.

## Step 2: Create Systems

Systems contain the logic. We need one to move entities based on their velocity.

Create `lib/game/systems.dart`:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'resources.dart';

/// Moves entities based on their velocity and bounces off screen edges
class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
    resourceReads: {ScreenSize, Time},
  );

  @override
  Future<void> run(World world) async {
    final dt = world.getResource<Time>()?.delta ?? 0.016;
    final screen = world.getResource<ScreenSize>()!;

    for (final (_, pos, vel, square) in
        world.query3<Position, Velocity, Square>().iter()) {
      // Move
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;

      // Bounce off edges
      if (pos.x <= 0 || pos.x + square.size >= screen.width) {
        vel.dx = -vel.dx;
        pos.x = pos.x.clamp(0, screen.width - square.size);
      }
      if (pos.y <= 0 || pos.y + square.size >= screen.height) {
        vel.dy = -vel.dy;
        pos.y = pos.y.clamp(0, screen.height - square.size);
      }
    }
  }
}
```

The `SystemMeta` declares what data this system reads and writes. Fledge uses this for:
- Automatic parallel execution (non-conflicting systems run together)
- Error detection (catches data races at runtime)

## Step 3: Create Resources

Resources are global singletons - shared data that isn't attached to any entity.

Create `lib/game/resources.dart`:

```dart
/// Screen dimensions for boundary checking
class ScreenSize {
  double width;
  double height;

  ScreenSize(this.width, this.height);
}
```

We're using `Time` from Fledge's built-in `TimePlugin`, and we need `ScreenSize` to know where to bounce.

## Step 4: Create a Plugin

Plugins bundle related functionality together. Let's create one for our bouncing square.

Create `lib/game/game_plugin.dart`:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'resources.dart';
import 'systems.dart';

class BouncingSquarePlugin implements Plugin {
  final double screenWidth;
  final double screenHeight;

  BouncingSquarePlugin({
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  void build(App app) {
    // Register resources
    app.world.insertResource(ScreenSize(screenWidth, screenHeight));

    // Add systems
    app.addSystem(MovementSystem());

    // Spawn our bouncing square
    app.world.spawn()
      ..insert(Position(100, 100))
      ..insert(Velocity(200, 150))  // pixels per second
      ..insert(Square(size: 40, color: 0xFF4CAF50));
  }

  @override
  void cleanup() {}
}
```

## Step 5: Create the Flutter Widget

Now we connect Fledge to Flutter. We'll use a `StatefulWidget` with an `AnimationController` for the game loop.

Create `lib/game/game_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'game_plugin.dart';

class BouncingSquareWidget extends StatefulWidget {
  const BouncingSquareWidget({super.key});

  @override
  State<BouncingSquareWidget> createState() => _BouncingSquareWidgetState();
}

class _BouncingSquareWidgetState extends State<BouncingSquareWidget>
    with SingleTickerProviderStateMixin {
  late App _app;
  late AnimationController _ticker;

  @override
  void initState() {
    super.initState();

    // Create the Fledge app
    _app = App()
      ..addPlugin(TimePlugin())
      ..addPlugin(BouncingSquarePlugin(
        screenWidth: 400,
        screenHeight: 300,
      ));

    // Start the game loop
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1), // Runs indefinitely
    )
      ..addListener(_gameLoop)
      ..repeat();
  }

  void _gameLoop() {
    _app.tick();        // Run all systems
    setState(() {});    // Trigger repaint
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SquarePainter(_app.world),
      size: const Size(400, 300),
    );
  }
}

/// Renders entities with Position and Square components
class SquarePainter extends CustomPainter {
  final World world;

  SquarePainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1E1E2E),
    );

    // Draw all squares
    for (final (_, pos, square) in
        world.query2<Position, Square>().iter()) {
      canvas.drawRect(
        Rect.fromLTWH(pos.x, pos.y, square.size, square.size),
        Paint()..color = Color(square.color),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SquarePainter oldDelegate) => true;
}
```

## Step 6: Run It!

Update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'game/game_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Fledge',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Hello Fledge')),
        body: const Center(
          child: BouncingSquareWidget(),
        ),
      ),
    );
  }
}
```

Run your app:

```bash
flutter run -d windows  # or macos/linux
```

You should see a green square bouncing around the screen!

## What Just Happened?

Let's trace through a single frame:

1. **AnimationController** triggers `_gameLoop()`
2. **`app.tick()`** runs all systems in order
3. **TimePlugin's system** updates the `Time` resource with delta time
4. **MovementSystem** queries for entities with `Position`, `Velocity`, and `Square`
5. **MovementSystem** updates positions and handles bouncing
6. **`setState()`** triggers Flutter to repaint
7. **SquarePainter** queries for entities with `Position` and `Square` and draws them

This is the ECS game loop in action:
- **Data** (components) is separate from **logic** (systems)
- **Queries** find entities with specific component combinations
- **Resources** provide global state like time and screen size

## Try It Yourself

1. **Add more squares**: Spawn multiple entities with different colors and speeds
2. **Change colors on bounce**: Add logic to change the square's color when it hits a wall
3. **Add gravity**: Create a `GravitySystem` that increases `velocity.dy` each frame

## What's Next?

Now you understand the basics! Let's solidify these concepts in [Core Concepts](/docs/getting-started/core-concepts), then we'll build a complete Snake game in [Building Snake](/docs/getting-started/building-snake).
