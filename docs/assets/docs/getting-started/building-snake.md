# Tutorial: Building Snake

In this tutorial, we'll build a complete Snake game from scratch. You'll learn how to:

- Design game entities and their components
- Handle keyboard input
- Implement collision detection
- Manage game state (score, game over)
- Connect everything to Flutter for rendering

By the end, you'll have a playable Snake game and the skills to build your own games.

## The Game

Classic Snake rules:
- Control a snake that moves continuously in one direction
- Collect food to grow longer and increase your score
- Game over if you hit the walls or yourself

```
+---------------------------+
|  Score: 5                 |
|                           |
|       @ @ @ @             |
|             @             |
|             @             |
|                   o       |
|                           |
+---------------------------+
```

## Project Structure

We'll organize our game like this:

```
lib/
├── main.dart
└── game/
    ├── components.dart     # Data definitions
    ├── resources.dart      # Global state
    ├── systems.dart        # Game logic
    ├── snake_plugin.dart   # Bundles everything
    └── snake_widget.dart   # Flutter integration
```

## Step 1: Define Components

Components define what data exists in our game. Create `lib/game/components.dart`:

```dart
import 'package:fledge_ecs/fledge_ecs.dart';

/// Grid position (integer coordinates for tile-based movement)
class GridPosition {
  int x;
  int y;

  GridPosition(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is GridPosition && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  GridPosition copy() => GridPosition(x, y);
}

/// Movement direction
enum Direction { up, down, left, right }

/// Snake head marker - the front segment the player controls
class SnakeHead {
  Direction direction;
  Direction nextDirection;  // Buffered input (prevents 180-degree turns)

  SnakeHead({this.direction = Direction.right})
      : nextDirection = direction;

  void setDirection(Direction dir) {
    // Prevent 180-degree turns
    if ((direction == Direction.up && dir == Direction.down) ||
        (direction == Direction.down && dir == Direction.up) ||
        (direction == Direction.left && dir == Direction.right) ||
        (direction == Direction.right && dir == Direction.left)) {
      return;
    }
    nextDirection = dir;
  }
}

/// Snake body segment - follows the segment ahead of it
class SnakeSegment {
  final Entity? following;  // The segment this one follows
  GridPosition previousPosition;  // Where we'll move to

  SnakeSegment({this.following, required this.previousPosition});
}

/// Food that the snake can eat
class Food {}

/// Visual appearance
class TileColor {
  final int color;  // ARGB
  TileColor(this.color);
}
```

Key design decisions:
- **GridPosition**: Integer coordinates for tile-based movement
- **SnakeHead vs SnakeSegment**: Different behavior, different components
- **nextDirection**: Buffers input to prevent impossible moves
- **SnakeSegment.following**: Creates a linked chain for smooth movement

## Step 2: Define Resources

Resources hold global game state. Create `lib/game/resources.dart`:

```dart
import 'components.dart';

/// Game configuration
class GameConfig {
  final int gridWidth;
  final int gridHeight;
  final int tileSize;
  final double moveInterval;  // Seconds between moves

  GameConfig({
    this.gridWidth = 20,
    this.gridHeight = 15,
    this.tileSize = 20,
    this.moveInterval = 0.15,
  });

  int get pixelWidth => gridWidth * tileSize;
  int get pixelHeight => gridHeight * tileSize;
}

/// Tracks player score
class Score {
  int value = 0;

  void increment() => value++;
  void reset() => value = 0;
}

/// Game state
class GameState {
  bool isGameOver = false;

  void gameOver() => isGameOver = true;
  void reset() => isGameOver = false;
}

/// Tracks current input state
class InputState {
  Direction? pendingDirection;

  void press(Direction dir) => pendingDirection = dir;
  void clear() => pendingDirection = null;
}

/// Timer for grid-based movement
class MoveTimer {
  double elapsed = 0;

  void add(double dt) => elapsed += dt;
  void reset() => elapsed = 0;
}
```

## Step 3: Create Systems

Systems contain all game logic. Create `lib/game/systems.dart`:

```dart
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'resources.dart';

/// Processes keyboard input and updates snake direction
class InputSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'input',
    writes: {ComponentId.of<SnakeHead>()},
    resourceReads: {InputState, GameState},
  );

  @override
  Future<void> run(World world) async {
    final input = world.getResource<InputState>()!;
    final gameState = world.getResource<GameState>()!;

    if (gameState.isGameOver) return;
    if (input.pendingDirection == null) return;

    for (final (_, head) in world.query1<SnakeHead>().iter()) {
      head.setDirection(input.pendingDirection!);
    }

    input.clear();
  }
}

/// Moves the snake at fixed intervals
class MovementSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'movement',
    writes: {
      ComponentId.of<GridPosition>(),
      ComponentId.of<SnakeHead>(),
      ComponentId.of<SnakeSegment>(),
    },
    resourceReads: {Time, GameConfig, MoveTimer, GameState},
    resourceWrites: {MoveTimer},
  );

  @override
  Future<void> run(World world) async {
    final time = world.getResource<Time>()!;
    final config = world.getResource<GameConfig>()!;
    final timer = world.getResource<MoveTimer>()!;
    final gameState = world.getResource<GameState>()!;

    if (gameState.isGameOver) return;

    timer.add(time.delta);
    if (timer.elapsed < config.moveInterval) return;
    timer.reset();

    // First, update segment previous positions (before head moves)
    for (final (_, segment, pos) in
        world.query2<SnakeSegment, GridPosition>().iter()) {
      if (segment.following != null) {
        final followPos = world.get<GridPosition>(segment.following!);
        if (followPos != null) {
          segment.previousPosition = followPos.copy();
        }
      }
    }

    // Move the head
    for (final (_, head, pos) in
        world.query2<SnakeHead, GridPosition>().iter()) {
      head.direction = head.nextDirection;

      switch (head.direction) {
        case Direction.up:
          pos.y -= 1;
        case Direction.down:
          pos.y += 1;
        case Direction.left:
          pos.x -= 1;
        case Direction.right:
          pos.x += 1;
      }
    }

    // Move segments to their previous positions
    for (final (_, segment, pos) in
        world.query2<SnakeSegment, GridPosition>().iter()) {
      pos.x = segment.previousPosition.x;
      pos.y = segment.previousPosition.y;
    }
  }
}

/// Checks for food collection
class FoodCollisionSystem implements System {
  final Random _random = Random();

  @override
  SystemMeta get meta => SystemMeta(
    name: 'foodCollision',
    reads: {ComponentId.of<SnakeHead>(), ComponentId.of<GridPosition>()},
    resourceReads: {GameConfig, GameState},
    resourceWrites: {Score},
  );

  @override
  Future<void> run(World world) async {
    final config = world.getResource<GameConfig>()!;
    final score = world.getResource<Score>()!;
    final gameState = world.getResource<GameState>()!;

    if (gameState.isGameOver) return;

    final commands = Commands();
    GridPosition? headPos;

    // Get head position
    for (final (_, _, pos) in
        world.query2<SnakeHead, GridPosition>().iter()) {
      headPos = pos;
    }

    if (headPos == null) return;

    // Check food collision
    for (final (entity, _, foodPos) in
        world.query2<Food, GridPosition>().iter()) {
      if (headPos == foodPos) {
        // Eat the food
        commands.despawn(entity);
        score.increment();

        // Spawn new food
        commands.spawn()
          ..insert(GridPosition(
            _random.nextInt(config.gridWidth),
            _random.nextInt(config.gridHeight),
          ))
          ..insert(Food())
          ..insert(TileColor(0xFFFF5722));

        // Grow the snake (add a segment)
        _growSnake(world, commands);
      }
    }

    commands.apply(world);
  }

  void _growSnake(World world, Commands commands) {
    // Find the last segment (or head if no segments)
    Entity? lastEntity;
    GridPosition? lastPos;

    // Check if there are any segments
    final segments = world.query2<SnakeSegment, GridPosition>().iter().toList();

    if (segments.isEmpty) {
      // No segments yet, follow the head
      for (final (entity, _, pos) in
          world.query2<SnakeHead, GridPosition>().iter()) {
        lastEntity = entity;
        lastPos = pos;
      }
    } else {
      // Find the tail (segment not followed by anyone)
      final followedEntities = segments.map((s) => s.$2.following).toSet();
      for (final (entity, segment, pos) in segments) {
        if (!followedEntities.contains(entity)) {
          lastEntity = entity;
          lastPos = pos;
        }
      }
    }

    if (lastEntity == null || lastPos == null) return;

    commands.spawn()
      ..insert(GridPosition(lastPos.x, lastPos.y))
      ..insert(SnakeSegment(
        following: lastEntity,
        previousPosition: lastPos.copy(),
      ))
      ..insert(TileColor(0xFF4CAF50));
  }
}

/// Checks for wall and self collision
class CollisionSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'collision',
    reads: {
      ComponentId.of<SnakeHead>(),
      ComponentId.of<SnakeSegment>(),
      ComponentId.of<GridPosition>(),
    },
    resourceReads: {GameConfig},
    resourceWrites: {GameState},
  );

  @override
  Future<void> run(World world) async {
    final config = world.getResource<GameConfig>()!;
    final gameState = world.getResource<GameState>()!;

    if (gameState.isGameOver) return;

    GridPosition? headPos;

    // Get head position
    for (final (_, _, pos) in
        world.query2<SnakeHead, GridPosition>().iter()) {
      headPos = pos;
    }

    if (headPos == null) return;

    // Wall collision
    if (headPos.x < 0 ||
        headPos.x >= config.gridWidth ||
        headPos.y < 0 ||
        headPos.y >= config.gridHeight) {
      gameState.gameOver();
      return;
    }

    // Self collision
    for (final (_, _, segmentPos) in
        world.query2<SnakeSegment, GridPosition>().iter()) {
      if (headPos == segmentPos) {
        gameState.gameOver();
        return;
      }
    }
  }
}
```

Each system has a single responsibility:
- **InputSystem**: Reads keyboard input, updates snake direction
- **MovementSystem**: Moves snake at fixed intervals
- **FoodCollisionSystem**: Detects food collection, spawns new food, grows snake
- **CollisionSystem**: Detects wall/self collision, triggers game over

## Step 4: Create the Plugin

The plugin bundles everything together. Create `lib/game/snake_plugin.dart`:

```dart
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'resources.dart';
import 'systems.dart';

class SnakePlugin implements Plugin {
  final Random _random = Random();

  @override
  void build(App app) {
    final config = GameConfig();

    // Register resources
    app.world.insertResource(config);
    app.world.insertResource(Score());
    app.world.insertResource(GameState());
    app.world.insertResource(InputState());
    app.world.insertResource(MoveTimer());

    // Add systems in order
    app.addSystem(InputSystem(), stage: CoreStage.preUpdate);
    app.addSystem(MovementSystem(), stage: CoreStage.update);
    app.addSystem(FoodCollisionSystem(), stage: CoreStage.postUpdate);
    app.addSystem(CollisionSystem(), stage: CoreStage.postUpdate);

    // Spawn the snake head
    final headPos = GridPosition(config.gridWidth ~/ 2, config.gridHeight ~/ 2);
    app.world.spawn()
      ..insert(headPos)
      ..insert(SnakeHead())
      ..insert(TileColor(0xFF8BC34A));  // Light green for head

    // Spawn initial food
    app.world.spawn()
      ..insert(GridPosition(
        _random.nextInt(config.gridWidth),
        _random.nextInt(config.gridHeight),
      ))
      ..insert(Food())
      ..insert(TileColor(0xFFFF5722));  // Orange for food
  }

  @override
  void cleanup() {}
}
```

## Step 5: Create the Flutter Widget

Now we connect everything to Flutter. Create `lib/game/snake_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart';

import 'components.dart';
import 'resources.dart';
import 'snake_plugin.dart';

class SnakeGameWidget extends StatefulWidget {
  const SnakeGameWidget({super.key});

  @override
  State<SnakeGameWidget> createState() => _SnakeGameWidgetState();
}

class _SnakeGameWidgetState extends State<SnakeGameWidget>
    with SingleTickerProviderStateMixin {
  late App _app;
  late AnimationController _ticker;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _initGame();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )
      ..addListener(_gameLoop)
      ..repeat();
  }

  void _initGame() {
    _app = App()
      ..addPlugin(TimePlugin())
      ..addPlugin(SnakePlugin());
  }

  void _gameLoop() {
    _app.tick();
    setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final input = _app.world.getResource<InputState>();
    if (input == null) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        input.press(Direction.up);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        input.press(Direction.down);
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        input.press(Direction.left);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        input.press(Direction.right);
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.enter:
        _resetGame();
    }
  }

  void _resetGame() {
    _initGame();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _app.world.getResource<GameConfig>()!;
    final score = _app.world.getResource<Score>()?.value ?? 0;
    final isGameOver = _app.world.getResource<GameState>()?.isGameOver ?? false;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score display
            Container(
              width: config.pixelWidth.toDouble(),
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF1E1E2E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score: $score',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isGameOver)
                    const Text(
                      'GAME OVER - Press Space to restart',
                      style: TextStyle(
                        color: Color(0xFFFF5722),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),

            // Game canvas
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF424242),
                  width: 2,
                ),
              ),
              child: CustomPaint(
                painter: SnakeGamePainter(_app.world),
                size: Size(
                  config.pixelWidth.toDouble(),
                  config.pixelHeight.toDouble(),
                ),
              ),
            ),

            // Controls hint
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Controls: Arrow Keys or WASD',
                style: TextStyle(color: Color(0xFF757575)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the game grid
class SnakeGamePainter extends CustomPainter {
  final World world;

  SnakeGamePainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    final config = world.getResource<GameConfig>()!;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1E1E2E),
    );

    // Draw grid lines (subtle)
    final gridPaint = Paint()
      ..color = const Color(0xFF2D2D3D)
      ..strokeWidth = 1;

    for (var x = 0; x <= config.gridWidth; x++) {
      canvas.drawLine(
        Offset(x * config.tileSize.toDouble(), 0),
        Offset(x * config.tileSize.toDouble(), size.height),
        gridPaint,
      );
    }
    for (var y = 0; y <= config.gridHeight; y++) {
      canvas.drawLine(
        Offset(0, y * config.tileSize.toDouble()),
        Offset(size.width, y * config.tileSize.toDouble()),
        gridPaint,
      );
    }

    // Draw all entities with GridPosition and TileColor
    for (final (_, pos, color) in
        world.query2<GridPosition, TileColor>().iter()) {
      final rect = Rect.fromLTWH(
        pos.x * config.tileSize.toDouble() + 1,
        pos.y * config.tileSize.toDouble() + 1,
        config.tileSize.toDouble() - 2,
        config.tileSize.toDouble() - 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = Color(color.color),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SnakeGamePainter oldDelegate) => true;
}
```

## Step 6: Update main.dart

Finally, update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'game/snake_widget.dart';

void main() {
  runApp(const SnakeApp());
}

class SnakeApp extends StatelessWidget {
  const SnakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake - Fledge Tutorial',
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        appBar: AppBar(
          title: const Text('Snake'),
          backgroundColor: const Color(0xFF1E1E2E),
        ),
        body: const Center(
          child: SnakeGameWidget(),
        ),
      ),
    );
  }
}
```

## Run the Game

```bash
flutter run -d windows  # or macos/linux
```

Use arrow keys or WASD to move. Collect food to grow. Don't hit the walls or yourself!

## What We Built

Let's review the ECS architecture we created:

### Components (Data)
| Component | Purpose |
|-----------|---------|
| `GridPosition` | Where an entity is on the grid |
| `SnakeHead` | Marks the player-controlled segment |
| `SnakeSegment` | Marks a body segment, tracks what it follows |
| `Food` | Marks collectible items |
| `TileColor` | Visual appearance |

### Resources (Global State)
| Resource | Purpose |
|----------|---------|
| `GameConfig` | Grid size, tile size, move speed |
| `Score` | Player's current score |
| `GameState` | Game over flag |
| `InputState` | Pending input direction |
| `MoveTimer` | Time since last move |

### Systems (Logic)
| System | Stage | Purpose |
|--------|-------|---------|
| `InputSystem` | preUpdate | Process keyboard input |
| `MovementSystem` | update | Move snake at intervals |
| `FoodCollisionSystem` | postUpdate | Handle food collection |
| `CollisionSystem` | postUpdate | Detect game over conditions |

## Challenges

Try extending the game:

1. **Speed increase**: Make the snake faster as score increases
2. **Obstacles**: Add wall entities that cause game over on collision
3. **Power-ups**: Add special food that gives temporary invincibility
4. **High score**: Save and display the best score

## Conclusion

Congratulations! You've built a complete game using Fledge. You now understand:

- How to design components for your game objects
- How to write systems that process those components
- How to use resources for global state
- How to connect Fledge to Flutter for rendering

Ready to learn more? Explore the [Guides](/docs/guides/entities-components) for deeper dives into specific topics, or check out the [API Reference](/docs/api/world) for complete documentation.
