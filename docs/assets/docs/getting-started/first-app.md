# Your First App

Let's build a Flutter app where coloured squares bounce around a box. It's not
a game yet, but it has every moving part a game has: components, a resource,
systems in two schedules, a frame loop driven by the display, and painting.

You'll need a Flutter project set up as in
[Installation](/docs/getting-started/installation), with `fledge_ecs` and
`material_ui` in its dependencies.

## The whole app

Replace `lib/main.dart` with this. The sections below go through it.

```dart
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart' hide Velocity;

// --- Components: plain data -------------------------------------------

class Position {
  double x, y;
  Position(this.x, this.y);
}

class Velocity {
  double dx, dy; // pixels per second
  Velocity(this.dx, this.dy);
}

class Square {
  final double size;
  final Color color;
  const Square(this.size, this.color);
}

// --- Resource: one per world ------------------------------------------

class Arena {
  final double width, height;
  const Arena(this.width, this.height);
}

// --- Systems: the logic -----------------------------------------------

void spawnSquares(World world) {
  world
    ..spawnWith([
      Position(40, 60),
      Velocity(180, 120),
      const Square(40, Color(0xFF4CAF50)),
    ])
    ..spawnWith([
      Position(300, 200),
      Velocity(-140, 90),
      const Square(28, Color(0xFFFFC107)),
    ])
    ..spawnWith([
      Position(200, 40),
      Velocity(90, -160),
      const Square(20, Color(0xFF03A9F4)),
    ]);
}

class BounceSystem extends System {
  static const String systemName = 'bounce';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Square>()},
    writes: {ComponentId.of<Position>(), ComponentId.of<Velocity>()},
    resourceReads: {WallTime, Arena},
  );

  @override
  void run(World world) {
    final dt = world.getResource<WallTime>()!.delta;
    final arena = world.getResource<Arena>()!;
    for (final (_, pos, vel, square)
        in world.query3<Position, Velocity, Square>().iter()) {
      pos.x += vel.dx * dt;
      pos.y += vel.dy * dt;

      final maxX = arena.width - square.size;
      final maxY = arena.height - square.size;
      if (pos.x < 0 || pos.x > maxX) {
        vel.dx = -vel.dx;
        pos.x = pos.x.clamp(0.0, maxX);
      }
      if (pos.y < 0 || pos.y > maxY) {
        vel.dy = -vel.dy;
        pos.y = pos.y.clamp(0.0, maxY);
      }
    }
  }
}

App buildApp() => App()
  ..addPlugin(WallTimePlugin())
  ..insertResource(const Arena(480, 320))
  ..addSystem(
    FunctionSystem('spawnSquares', run: spawnSquares),
    schedule: Schedules.startup,
  )
  ..addSystem(BounceSystem(), schedule: Schedules.update);

// --- Flutter: drive the frame loop and paint --------------------------

void main() {
  runApp(
    MaterialApp(
      title: 'Bouncing squares',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(child: GameView(app: buildApp())),
      ),
    ),
  );
}

class GameView extends StatefulWidget {
  const GameView({super.key, required this.app});

  final App app;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frames = ValueNotifier<int>(0);
  bool _ticking = false;

  @override
  void initState() {
    super.initState();
    // Count time in whole display refreshes, read from the vsync timestamp.
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final hz = views.first.display.refreshRate;
    widget.app.world.getResource<WallTime>()!.useClock(
      () => SchedulerBinding.instance.currentSystemFrameTimeStamp,
      frameInterval: WallTime.frameIntervalFor(hz),
    );
    _ticker = createTicker(_onFrame)..start();
  }

  Future<void> _onFrame(Duration _) async {
    if (_ticking) return; // the last tick is still running: skip a frame
    _ticking = true;
    try {
      await widget.app.tick();
      _frames.value++; // repaint, without rebuilding any widget
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'game'),
      );
    } finally {
      _ticking = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arena = widget.app.world.getResource<Arena>()!;
    return CustomPaint(
      size: Size(arena.width, arena.height),
      painter: SquarePainter(widget.app.world, repaint: _frames),
    );
  }
}

class SquarePainter extends CustomPainter {
  SquarePainter(this.world, {super.repaint});

  final World world;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1E1E2E),
    );
    for (final (_, pos, square) in world.query2<Position, Square>().iter()) {
      canvas.drawRect(
        Rect.fromLTWH(pos.x, pos.y, square.size, square.size),
        Paint()..color = square.color,
      );
    }
  }

  @override
  bool shouldRepaint(SquarePainter oldDelegate) => oldDelegate.world != world;
}
```

Run it:

```bash
flutter run -d macos   # or -d windows, -d linux
```

Three squares bounce around a dark box.

## Components and resources

`Position`, `Velocity` and `Square` are **components**: plain classes, no base
class, no annotations. An entity is whatever set of components you give it,
and `spawnWith` creates one with a list of them.

`Arena` is a **resource**: a single value stored on the world rather than on an
entity. Systems read it with `world.getResource<Arena>()`. `WallTime`, added by
`WallTimePlugin`, is another resource: it holds the seconds since the last
frame in `delta`.

Flutter also has a class called `Velocity` (for gestures), and its `State`
clashes with the `State` resource Fledge exports, hence the two `hide`s in the
imports.

## Systems and schedules

`BounceSystem` is the game logic. Its `SystemMeta` names it and declares what
it touches: it reads `Square`, writes `Position` and `Velocity`, and reads the
`WallTime` and `Arena` resources. The declarations don't restrict what `run`
can do; they tell the scheduler which systems conflict, so it can keep them in
a stable order (see [Systems](/docs/ecs/systems)).

Two details in `run`:

- Movement is `velocity * delta`, so speed is in pixels per second whatever
  the frame rate.
- `clamp(0.0, maxX)` uses `0.0`, not `0`. On a `double`, `clamp` with two
  `double` arguments returns a `double`; with an `int` argument it returns
  `num`, which won't assign to `pos.x`.

`buildApp` registers everything:

- `spawnSquares` runs in `Schedules.startup`, which runs once, on the first
  tick. `FunctionSystem` turns a function into a system.
- `BounceSystem` runs in `Schedules.update` every frame.

There are more schedules: input is read in `first` and `preUpdate`, physics
runs in the fixed-timestep schedules, and so on. See
[Schedules & the Frame](/docs/scheduling/schedules).

## The frame loop

Fledge doesn't own a game loop in a Flutter app: your widget calls
`app.tick()` once per display frame. `GameView` does that from a `Ticker`,
which Flutter calls on every vsync:

- **`WallTime.useClock`** makes `WallTime` read the frame's vsync timestamp
  instead of a stopwatch, and count time in whole display refreshes. A
  stopwatch read at slightly different points each frame makes motion
  judder; see
  [Smooth frame times in Flutter](/docs/scheduling/time#smooth-frame-times-in-flutter).
- **`app.tick()` returns a `Future`.** With synchronous systems it completes
  in the same frame, before Flutter paints. `_onFrame` awaits it, skips a
  frame if the previous tick is still running (an `async` system that really
  waits), and reports errors through `FlutterError.reportError` instead of
  losing them in an unawaited future.
- **Repainting.** `_frames` is bumped after each tick and passed to the
  painter as `repaint`, so the canvas repaints every frame without rebuilding
  any widget.

`SquarePainter` reads the main world directly: `query2<Position, Square>()`
finds every entity with both components. That's fine for simple drawing. Real
games use `fledge_render_2d`, which copies what's visible into a separate
render world each frame and draws sprites with `FledgeRenderView`; see
[Rendering Overview](/docs/rendering/overview).

## Test the schedule

Systems that conflict and have no explicit order run in registration order,
which changes silently when you add plugins. `App.checkScheduleOrdering()`
lists every such pair. Put it in a test from day one, in
`test/widget_test.dart`:

```dart fragment
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game/main.dart';

void main() {
  test('conflicting systems all have an explicit order', () {
    expect(buildApp().checkScheduleOrdering(), isEmpty);
  });

  test('startup spawns three squares', () async {
    final app = buildApp();
    await app.tick();
    expect(app.world.query1<Square>().iter().length, 3);
  });
}
```

```bash
flutter test
```

Systems are plain objects, so you can also test one by building a `World` and
calling `run` on it directly.

## Try it yourself

- Spawn twenty squares with random sizes and speeds.
- Add a `Gravity` resource and a system that adds it to `Velocity.dy`. It
  writes `Velocity` like `BounceSystem`, so give one of them an
  `after:`/`before:` on the other, and watch the test fail until you do.
- Change a square's colour when it hits a wall (make `Square.color`
  non-final).

Next: [Core Concepts](/docs/getting-started/core-concepts) explains the pieces
in more depth, and [Tutorial: Snake](/docs/getting-started/tutorial-snake)
builds a complete game.
