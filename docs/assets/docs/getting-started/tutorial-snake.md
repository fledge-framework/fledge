# Tutorial: Snake

In this tutorial you'll build Snake: steer with the arrow keys or WASD, eat
the red food to grow and score, and don't hit the walls or yourself. Along the
way you'll use most of what a real Fledge game needs:

- components, resources and a state machine (`playing` / `gameOver`),
- action-based input with `fledge_input`,
- a fixed timestep, so the snake moves at the same speed on any display,
- explicit system ordering, checked by a test,
- a Flutter widget that drives the frame loop and paints the world.

It assumes you've read [Your First App](/docs/getting-started/first-app).

<!-- snippet-setup
import 'package:flutter/services.dart';

// Components ------------------------------------------------------------

/// A cell on the board.
class GridPos {
  int x, y;
  GridPos(this.x, this.y);

  bool sameCell(GridPos other) => x == other.x && y == other.y;
}

/// Marks a piece of the snake.
class SnakeSegment {
  const SnakeSegment();
}

/// Marks the food.
class Food {
  const Food();
}

// Resources and enums -------------------------------------------------------

enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Direction(this.dx, this.dy);
  final int dx, dy;

  bool isOpposite(Direction other) => dx == -other.dx && dy == -other.dy;
}

/// The game's state machine.
enum Phase { playing, gameOver }

class Board {
  final int columns, rows;
  final double cellSize;
  const Board({this.columns = 20, this.rows = 15, this.cellSize = 24});
}

/// The snake's segments, head first, and where it's going.
class Snake {
  final List<Entity> segments = [];
  Direction heading = Direction.right; // the direction of the last step
  Direction nextHeading = Direction.right; // the direction of the next one
  int growth = 0; // segments still to add
  bool alive = true;
}

class Score {
  int value = 0;
}

class Rng {
  final math.Random random;
  Rng([int? seed]) : random = math.Random(seed);
}

bool isGameOver(World world) =>
    world.getResource<State<Phase>>()!.current == Phase.gameOver;

// Input ---------------------------------------------------------------------

enum SnakeAction { move, restart }

InputMap snakeInputMap() => InputMap.builder()
    .bindArrows(ActionId.fromEnum(SnakeAction.move))
    .bindWasd(ActionId.fromEnum(SnakeAction.move))
    .bindKey(LogicalKeyboardKey.enter, ActionId.fromEnum(SnakeAction.restart))
    .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(SnakeAction.restart))
    .build();

// Level setup ---------------------------------------------------------------

/// Spawns a three-segment snake and one piece of food, and resets the score.
void spawnLevel(World world) {
  final board = world.getResource<Board>()!;
  final snake = world.getResource<Snake>()!
    ..segments.clear()
    ..heading = Direction.right
    ..nextHeading = Direction.right
    ..growth = 0
    ..alive = true;
  world.getResource<Score>()!.value = 0;

  final row = board.rows ~/ 2;
  for (var i = 0; i < 3; i++) {
    snake.segments.add(
      world.spawnWith([GridPos(5 - i, row), const SnakeSegment()]),
    );
  }

  final food = GridPos(0, 0);
  world.spawnWith([food, const Food()]);
  placeFood(world, food);
}

/// Moves [food] to a random cell the snake isn't on.
void placeFood(World world, GridPos food) {
  final board = world.getResource<Board>()!;
  final random = world.getResource<Rng>()!.random;
  final taken = {
    for (final (_, pos)
        in world.query1<GridPos>(filter: const With<SnakeSegment>()).iter())
      (pos.x, pos.y),
  };
  do {
    food
      ..x = random.nextInt(board.columns)
      ..y = random.nextInt(board.rows);
  } while (taken.contains((food.x, food.y)));
}
-->

## Set up the project

```bash
flutter create --platforms=windows,macos,linux snake
cd snake
```

In `pubspec.yaml`:

```yaml
environment:
  sdk: ^3.14.0
  flutter: ">=3.50.0"

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.11.0
  fledge_ecs: ^0.7.1
  fledge_input: ^0.7.1
```

```bash
flutter pub get
```

The game is five files in `lib/`:

| File | What's in it |
|---|---|
| `snake_data.dart` | Components, resources, the input map, level setup |
| `snake_systems.dart` | The systems and the plugin that registers them |
| `snake_painter.dart` | Draws the board |
| `game_host.dart` | A widget that runs any Fledge app: frame loop, input, painting |
| `main.dart` | Puts it together |

## Step 1: The data

The snake is a list of segment entities, each with a `GridPos` and a
`SnakeSegment` marker. The food is one entity with a `GridPos` and a `Food`
marker. The order of the segments matters (each one follows the one ahead of
it), and a query doesn't promise an order, so the `Snake` resource keeps the
segment entities in a list, head first, along with the heading.

Create `lib/snake_data.dart`:

```dart
import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart';

// Components ------------------------------------------------------------

/// A cell on the board.
class GridPos {
  int x, y;
  GridPos(this.x, this.y);

  bool sameCell(GridPos other) => x == other.x && y == other.y;
}

/// Marks a piece of the snake.
class SnakeSegment {
  const SnakeSegment();
}

/// Marks the food.
class Food {
  const Food();
}

// Resources and enums -------------------------------------------------------

enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Direction(this.dx, this.dy);
  final int dx, dy;

  bool isOpposite(Direction other) => dx == -other.dx && dy == -other.dy;
}

/// The game's state machine.
enum Phase { playing, gameOver }

class Board {
  final int columns, rows;
  final double cellSize;
  const Board({this.columns = 20, this.rows = 15, this.cellSize = 24});
}

/// The snake's segments, head first, and where it's going.
class Snake {
  final List<Entity> segments = [];
  Direction heading = Direction.right; // the direction of the last step
  Direction nextHeading = Direction.right; // the direction of the next one
  int growth = 0; // segments still to add
  bool alive = true;
}

class Score {
  int value = 0;
}

class Rng {
  final math.Random random;
  Rng([int? seed]) : random = math.Random(seed);
}

bool isGameOver(World world) =>
    world.getResource<State<Phase>>()!.current == Phase.gameOver;

// Input ---------------------------------------------------------------------

enum SnakeAction { move, restart }

InputMap snakeInputMap() => InputMap.builder()
    .bindArrows(ActionId.fromEnum(SnakeAction.move))
    .bindWasd(ActionId.fromEnum(SnakeAction.move))
    .bindKey(LogicalKeyboardKey.enter, ActionId.fromEnum(SnakeAction.restart))
    .bindKey(LogicalKeyboardKey.space, ActionId.fromEnum(SnakeAction.restart))
    .build();

// Level setup ---------------------------------------------------------------

/// Spawns a three-segment snake and one piece of food, and resets the score.
void spawnLevel(World world) {
  final board = world.getResource<Board>()!;
  final snake = world.getResource<Snake>()!
    ..segments.clear()
    ..heading = Direction.right
    ..nextHeading = Direction.right
    ..growth = 0
    ..alive = true;
  world.getResource<Score>()!.value = 0;

  final row = board.rows ~/ 2;
  for (var i = 0; i < 3; i++) {
    snake.segments.add(
      world.spawnWith([GridPos(5 - i, row), const SnakeSegment()]),
    );
  }

  final food = GridPos(0, 0);
  world.spawnWith([food, const Food()]);
  placeFood(world, food);
}

/// Moves [food] to a random cell the snake isn't on.
void placeFood(World world, GridPos food) {
  final board = world.getResource<Board>()!;
  final random = world.getResource<Rng>()!.random;
  final taken = {
    for (final (_, pos)
        in world.query1<GridPos>(filter: const With<SnakeSegment>()).iter())
      (pos.x, pos.y),
  };
  do {
    food
      ..x = random.nextInt(board.columns)
      ..y = random.nextInt(board.rows);
  } while (taken.contains((food.x, food.y)));
}
```

A few things to note:

- **Two headings.** `nextHeading` is what the player asked for; `heading` is
  the direction of the last step. Input arrives every frame but the snake
  steps less often, so keeping both stops a quick up-then-left from turning
  the snake back into itself between two steps.
- **`Phase`** becomes a state machine in Step 2. `isGameOver` reads it from
  the `State<Phase>` resource.
- **The input map** binds the arrows and WASD to one `move` action, a 2D
  vector (up is negative y, like the screen), and Enter or Space to
  `restart`. Systems ask about actions, never keys, so rebinding later
  touches only this function. See [Input](/docs/platform/input).
- **`spawnLevel`** resets the resources and spawns a fresh snake and food.
  It runs at startup and again on restart.

## Step 2: The systems

Five systems run the game:

| System | Schedule | Runs when | Does |
|---|---|---|---|
| `SteerSystem` | `preUpdate` | always | Reads the `move` action into `Snake.nextHeading` |
| `RestartSystem` | `preUpdate` | `gameOver` | On Enter/Space: respawns the level, back to `playing` |
| `MoveSnakeSystem` | `fixedUpdate` | `playing` | Moves the snake one cell |
| `CollisionSystem` | `fixedUpdate` | `playing` | Walls or body: game over |
| `EatFoodSystem` | `fixedUpdate` | `playing` | Food under the head: score, grow, new food |

**Why a fixed timestep?** The snake moves one cell at a time, eight times a
second. You could count frames or keep a timer, but the fixed-timestep
schedules already do exactly this: the plugin sets `FixedTimestep` to 120 ms,
and Fledge runs the `fixed*` schedules once per elapsed step, whatever the
display's refresh rate. Input is read every frame in `preUpdate`, so no key
press is missed between steps. See
[Time & Fixed Timestep](/docs/scheduling/time).

**Why the `before:`/`after:`?** `MoveSnakeSystem`, `CollisionSystem` and
`EatFoodSystem` all touch `GridPos` and the `Snake` resource, so they
conflict. Without explicit constraints they'd run in registration order:
correct today, broken the day someone reorders the `addSystem` calls. So
collision runs after the move (it checks where the head *landed*) and before
eating (a dead snake doesn't eat). `RestartSystem` and `SteerSystem` both
write `Snake`, so restart is ordered before steering too. A test in Step 6
proves every conflicting pair is ordered.

Create `lib/snake_systems.dart`, starting with these imports:

```dart fragment
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

import 'snake_data.dart';
```

followed by:

```dart
/// preUpdate: turns arrows/WASD into the snake's next heading.
class SteerSystem extends System {
  static const String systemName = 'snakeSteer';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    resourceReads: {ActionState},
    resourceWrites: {Snake},
  );

  @override
  void run(World world) {
    final actions = world.getResource<ActionState>()!;
    final snake = world.getResource<Snake>()!;
    final (x, y) = actions.vector2Value(ActionId.fromEnum(SnakeAction.move));
    if (x == 0 && y == 0) return;

    final wanted = x.abs() > y.abs()
        ? (x > 0 ? Direction.right : Direction.left)
        : (y > 0 ? Direction.down : Direction.up);
    // Compare with the last step taken, so two quick turns can't reverse
    // the snake into itself between steps.
    if (!wanted.isOpposite(snake.heading)) snake.nextHeading = wanted;
  }
}

/// fixedUpdate: moves the snake one cell.
class MoveSnakeSystem extends System {
  static const String systemName = 'snakeMove';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {ComponentId.of<GridPos>()},
    resourceWrites: {Snake},
  );

  @override
  void run(World world) {
    final snake = world.getResource<Snake>()!;
    if (!snake.alive) return;
    snake.heading = snake.nextHeading;

    final cells = [for (final e in snake.segments) world.get<GridPos>(e)!];
    final oldTail = GridPos(cells.last.x, cells.last.y);
    // Each segment moves into the cell of the one ahead of it...
    for (var i = cells.length - 1; i > 0; i--) {
      cells[i]
        ..x = cells[i - 1].x
        ..y = cells[i - 1].y;
    }
    // ...and the head moves on.
    cells.first
      ..x += snake.heading.dx
      ..y += snake.heading.dy;

    if (snake.growth > 0) {
      snake.growth--;
      snake.segments.add(world.spawnWith([oldTail, const SnakeSegment()]));
    }
  }
}

/// fixedUpdate: ends the game when the head leaves the board or hits the body.
class CollisionSystem extends System {
  static const String systemName = 'snakeCollision';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<GridPos>()},
    resourceReads: {Board},
    resourceWrites: {Snake, State<Phase>},
    after: [MoveSnakeSystem.systemName],
    before: [EatFoodSystem.systemName],
  );

  @override
  void run(World world) {
    final board = world.getResource<Board>()!;
    final snake = world.getResource<Snake>()!;
    if (!snake.alive) return;

    final head = world.get<GridPos>(snake.segments.first)!;
    final offBoard =
        head.x < 0 ||
        head.y < 0 ||
        head.x >= board.columns ||
        head.y >= board.rows;
    final bitten = snake.segments
        .skip(1)
        .any((e) => world.get<GridPos>(e)!.sameCell(head));

    if (offBoard || bitten) {
      // The state changes at the end of the frame; `alive` stops a second
      // fixed step in this same frame from moving the snake again.
      snake.alive = false;
      world.getResource<State<Phase>>()!.set(Phase.gameOver);
    }
  }
}

/// fixedUpdate: eats food under the head, grows the snake, scores.
class EatFoodSystem extends System {
  static const String systemName = 'snakeEat';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {ComponentId.of<Food>()},
    writes: {ComponentId.of<GridPos>()},
    resourceReads: {Board},
    resourceWrites: {Snake, Score, Rng},
    after: [CollisionSystem.systemName],
  );

  @override
  void run(World world) {
    final snake = world.getResource<Snake>()!;
    if (!snake.alive) return;

    final head = world.get<GridPos>(snake.segments.first)!;
    for (final (_, food)
        in world.query1<GridPos>(filter: const With<Food>()).iter()) {
      if (food.sameCell(head)) {
        world.getResource<Score>()!.value++;
        snake.growth++;
        placeFood(world, food);
      }
    }
  }
}

/// preUpdate, game over only: Enter or Space starts a new game.
class RestartSystem extends System {
  static const String systemName = 'snakeRestart';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    writes: {
      ComponentId.of<GridPos>(),
      ComponentId.of<SnakeSegment>(),
      ComponentId.of<Food>(),
    },
    resourceReads: {ActionState, Board},
    resourceWrites: {Snake, Score, Rng, State<Phase>},
    before: [SteerSystem.systemName],
  );

  @override
  void run(World world) {
    final actions = world.getResource<ActionState>()!;
    if (!actions.justPressed(ActionId.fromEnum(SnakeAction.restart))) return;

    final commands = Commands();
    for (final (entity, _) in world.query1<GridPos>().iter()) {
      commands.despawn(entity);
    }
    commands.apply(world);

    spawnLevel(world);
    world.getResource<State<Phase>>()!.set(Phase.playing);
  }
}

class SnakePlugin extends Plugin {
  @override
  void build(App app) {
    app
      // One fixed step = one move: about 8 cells a second.
      ..insertResource(
        FixedTimestep(stepDuration: const Duration(milliseconds: 120)),
      )
      ..insertResource(const Board())
      ..insertResource(Snake())
      ..insertResource(Score())
      ..insertResource(Rng())
      ..addState<Phase>(Phase.playing)
      ..addSystem(
        FunctionSystem('snakeSpawn', run: spawnLevel),
        schedule: Schedules.startup,
      )
      ..addSystem(SteerSystem(), schedule: Schedules.preUpdate)
      ..addSystemInState(
        RestartSystem(),
        Phase.gameOver,
        schedule: Schedules.preUpdate,
      )
      ..addSystemInState(
        MoveSnakeSystem(),
        Phase.playing,
        schedule: Schedules.fixedUpdate,
      )
      ..addSystemInState(
        CollisionSystem(),
        Phase.playing,
        schedule: Schedules.fixedUpdate,
      )
      ..addSystemInState(
        EatFoodSystem(),
        Phase.playing,
        schedule: Schedules.fixedUpdate,
      );
  }
}

App buildSnakeApp() => App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(
    InputPlugin.simple(
      context: InputContext(name: 'snake', map: snakeInputMap()),
    ),
  )
  ..addPlugin(SnakePlugin());
```

Notes:

- **States.** `addState<Phase>(Phase.playing)` adds the state machine and
  `addSystemInState` runs a system only in one state. A call to
  `State.set` takes effect at the end of the frame (see
  [States & Run Conditions](/docs/ecs/states-run-conditions)), so
  `CollisionSystem` also clears `Snake.alive`: on a slow frame the fixed
  schedules can run twice, and the second step mustn't move a dead snake.
- **Restarting** despawns every entity with a `GridPos` through a
  [`Commands`](/docs/ecs/commands) buffer, then calls `spawnLevel`.
- **`FixedTimestep`** replaces the 60 Hz default that every `App` inserts.
  It's one resource per app, so in a bigger game you'd keep 60 Hz for
  physics and count steps for the snake instead.
- **`buildSnakeApp`** adds `WallTimePlugin` (the frame clock) and
  `InputPlugin.simple` with one input context, then the game.

## Step 3: Drawing the board

The painter reads the world and draws a square per cell. Create
`lib/snake_painter.dart` with these imports:

```dart fragment
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'snake_data.dart';
```

and:

```dart
/// Draws the board from the world's components.
void paintSnake(Canvas canvas, Size size, World world) {
  final cell = world.getResource<Board>()!.cellSize;
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B1B2F));

  void drawCell(GridPos pos, Paint paint) => canvas.drawRect(
    Rect.fromLTWH(pos.x * cell + 1, pos.y * cell + 1, cell - 2, cell - 2),
    paint,
  );

  final food = Paint()..color = const Color(0xFFE53935);
  for (final (_, pos)
      in world.query1<GridPos>(filter: const With<Food>()).iter()) {
    drawCell(pos, food);
  }

  final body = Paint()
    ..color = isGameOver(world)
        ? const Color(0xFF757575)
        : const Color(0xFF4CAF50);
  for (final (_, pos)
      in world.query1<GridPos>(filter: const With<SnakeSegment>()).iter()) {
    drawCell(pos, body);
  }
}
```

This draws straight from the main world, which is fine for a game this small.
With `fledge_render_2d` you'd give entities sprites and let the render world
and `FledgeRenderView` draw them; see
[Rendering Overview](/docs/rendering/overview).

## Step 4: The game host

`GameHost` is the frame loop from Your First App made reusable: it ticks the
app on every display frame with `WallTime` reading the vsync clock, wraps
everything in `InputWidget` so key presses reach the `InputPlugin`, paints
with a `WorldPainter` callback, and rebuilds an optional overlay every frame.
Create `lib/game_host.dart`:

```dart
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Paints a frame of the game from the world.
typedef WorldPainter = void Function(Canvas canvas, Size size, World world);

/// Ticks [app] once per display frame, feeds it keyboard and gamepad input,
/// and paints it.
class GameHost extends StatefulWidget {
  const GameHost({
    super.key,
    required this.app,
    required this.size,
    required this.painter,
    this.overlay,
  });

  final App app;
  final Size size;
  final WorldPainter painter;

  /// Widgets drawn over the game (a score, say), rebuilt every frame.
  final Widget Function(BuildContext context, World world)? overlay;

  @override
  State<GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<GameHost>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frames = ValueNotifier<int>(0);
  bool _ticking = false;

  World get _world => widget.app.world;

  @override
  void initState() {
    super.initState();
    final views = WidgetsBinding.instance.platformDispatcher.views;
    _world.getResource<WallTime>()?.useClock(
      () => SchedulerBinding.instance.currentSystemFrameTimeStamp,
      frameInterval: WallTime.frameIntervalFor(views.first.display.refreshRate),
    );
    _ticker = createTicker(_onFrame)..start();
  }

  Future<void> _onFrame(Duration _) async {
    if (_ticking) return;
    _ticking = true;
    try {
      await widget.app.tick();
      _frames.value++;
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
    final overlay = widget.overlay;
    return InputWidget(
      world: _world,
      autofocus: true,
      child: SizedBox.fromSize(
        size: widget.size,
        child: Stack(
          children: [
            CustomPaint(
              size: widget.size,
              painter: _HostPainter(_world, widget.painter, _frames),
            ),
            if (overlay != null)
              ValueListenableBuilder<int>(
                valueListenable: _frames,
                builder: (context, _, _) => overlay(context, _world),
              ),
          ],
        ),
      ),
    );
  }
}

class _HostPainter extends CustomPainter {
  _HostPainter(this.world, this.paintWorld, Listenable repaint)
    : super(repaint: repaint);

  final World world;
  final WorldPainter paintWorld;

  @override
  void paint(Canvas canvas, Size size) => paintWorld(canvas, size, world);

  @override
  bool shouldRepaint(_HostPainter oldDelegate) =>
      oldDelegate.world != world || oldDelegate.paintWorld != paintWorld;
}
```

`InputWidget` takes keyboard focus when it appears (`autofocus: true`). If the
game stops responding to keys, something else has focus: click the board.

## Step 5: Put it together

Replace `lib/main.dart`:

```dart fragment
import 'package:material_ui/material_ui.dart';

import 'game_host.dart';
import 'snake_data.dart';
import 'snake_painter.dart';
import 'snake_systems.dart';

void main() {
  final app = buildSnakeApp();
  final board = app.world.getResource<Board>()!;
  runApp(
    MaterialApp(
      title: 'Snake',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: GameHost(
            app: app,
            size: Size(
              board.columns * board.cellSize,
              board.rows * board.cellSize,
            ),
            painter: paintSnake,
            overlay: (context, world) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                isGameOver(world)
                    ? 'Game over! Score: ${world.getResource<Score>()!.value}. '
                          'Press Enter to play again.'
                    : 'Score: ${world.getResource<Score>()!.value}',
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
```

Run it:

```bash
flutter run -d macos   # or -d windows, -d linux
```

## Step 6: Test it

Replace `test/widget_test.dart`. The first test is the one every Fledge game
should have; the second runs the systems directly against a world:

```dart fragment
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game/snake_data.dart';
import 'package:my_game/snake_systems.dart';

void main() {
  test('conflicting systems all have an explicit order', () {
    expect(buildSnakeApp().checkScheduleOrdering(), isEmpty);
  });

  test('the snake eats, grows and scores', () async {
    final app = buildSnakeApp();
    await app.tick(); // startup spawns the level
    final world = app.world;
    final snake = world.getResource<Snake>()!;
    final head = world.get<GridPos>(snake.segments.first)!;

    // Put the food right in front of the snake.
    final (_, food) = world
        .query1<GridPos>(filter: const With<Food>())
        .iter()
        .single;
    food
      ..x = head.x + 1
      ..y = head.y;

    MoveSnakeSystem().run(world);
    CollisionSystem().run(world);
    EatFoodSystem().run(world);
    expect(world.getResource<Score>()!.value, 1);

    MoveSnakeSystem().run(world); // the next step adds the segment
    expect(snake.segments, hasLength(4));
  });
}
```

```bash
flutter test
```

Try deleting the `before:` from `CollisionSystem`: the first test fails and
names the pair.

## Where to go from here

- **Speed up** as the score grows: from a system in `update`, insert a new
  `FixedTimestep` with a shorter `stepDuration` (its fields are final).
- **Wrap around** the edges instead of dying, in `MoveSnakeSystem`.
- **Gamepad support**: add `.bindDpad(...)` and `.bindLeftStick(...)` to the
  input map. Nothing else changes.
- **Sprites**: replace the painter with `fledge_render_2d`
  ([Sprites & Animation](/docs/rendering/sprites-animation)).
- **High scores** that survive a restart: [Save & Load](/docs/gameplay/save).
