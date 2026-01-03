import 'dart:ui';

import 'package:flutter/material.dart' hide Color;
import 'package:flutter/services.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;

import 'extraction.dart';
import 'resources.dart';
import 'systems.dart';
import 'grid_game_painter.dart';

/// Interactive grid game widget demonstrating Fledge ECS with two-world architecture.
///
/// **Note:** This demo creates its own [App] instance because it's embedded in
/// a docs site, not a standalone game. In a real game, you would:
/// 1. Create the App once in `main()`
/// 2. Pass it to your game widget via constructor
/// See the "Desktop App" code example on the demo page for the recommended pattern.
///
/// This widget demonstrates the separation of game logic from rendering:
///
/// **Main World** (game logic):
/// - Entities with GridPosition, Player, Collectible, TileColor
/// - Systems: MovementSystem, SpawnSystem, CollectionSystem
/// - Resources: GridConfig, GameScore, InputState, SpawnTimer
///
/// **Render World** (GPU-ready data):
/// - ExtractedGridEntity with pre-computed pixel coordinates
/// - ExtractedGridConfig, ExtractedScore resources
///
/// Each frame:
/// 1. Main world systems run (game logic)
/// 2. Extractors copy and transform data to render world
/// 3. Painter queries only the render world
///
/// This decouples rendering from game logic, enabling:
/// - Different render backends without changing game code
/// - GPU-optimized data structures
/// - Clean separation of concerns
class GridGameWidget extends StatefulWidget {
  const GridGameWidget({super.key});

  @override
  State<GridGameWidget> createState() => _GridGameWidgetState();
}

class _GridGameWidgetState extends State<GridGameWidget>
    with SingleTickerProviderStateMixin {
  late App _app;
  late AnimationController _ticker;
  late FocusNode _focusNode;

  /// The render world - contains extracted, GPU-ready data.
  late RenderWorld _renderWorld;

  /// Extractors that copy data from main world to render world.
  late Extractors _extractors;

  /// Convenience accessor for the main ECS world (game logic).
  World get _world => _app.world;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _setupGame();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )
      ..addListener(_gameLoop)
      ..repeat();
  }

  void _setupGame() {
    // Create the app with plugins (Main World)
    _app = App()
      ..addPlugin(TimePlugin())
      ..addPlugin(GridGamePlugin());

    // Create the render world (separate from main world)
    _renderWorld = RenderWorld();

    // Set up extractors that copy data from main world to render world
    _extractors = Extractors()
      ..register(GridConfigExtractor()) // Extract grid config
      ..register(ScoreExtractor()) // Extract score
      ..register(GridEntityExtractor()); // Extract entities with positions

    // Register extractors as a resource (for ExtractSystem to find)
    _world.insertResource(_extractors);
  }

  void _gameLoop() {
    // 1. Run game logic systems (main world)
    _app.tick();

    // 2. Extract: Copy data from main world to render world
    //    ExtractSystem clears render world, then runs all extractors
    ExtractSystem().run(_world, _renderWorld);

    // 3. Trigger repaint (painter will query render world)
    setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    final input = _world.getResource<InputState>();
    if (input == null) return;

    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    if (!isDown && !isUp) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        input.leftHeld = isDown;
      case LogicalKeyboardKey.arrowRight:
        input.rightHeld = isDown;
      case LogicalKeyboardKey.arrowUp:
        input.upHeld = isDown;
      case LogicalKeyboardKey.arrowDown:
        input.downHeld = isDown;
    }
  }

  void _resetGame() {
    // Recreate the app with fresh state
    _setupGame();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read from render world (extracted data) for display
    final config = _renderWorld.getResource<ExtractedGridConfig>();
    final score = _renderWorld.getResource<ExtractedScore>()?.value ?? 0;

    // Fallback to main world config if render world hasn't been populated yet
    final mainConfig = _world.getResource<GridConfig>()!;
    final displayWidth = config?.totalWidth ?? mainConfig.totalWidth;
    final displayHeight = config?.totalHeight ?? mainConfig.totalHeight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Game canvas with keyboard focus
        Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            _handleKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF424242),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(
                  // Pass render world to painter (not main world!)
                  painter: GridGamePainter(_renderWorld),
                  size: Size(displayWidth, displayHeight),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Score and controls info
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Score: $score',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Reset button
            TextButton.icon(
              onPressed: _resetGame,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF9E9E9E),
              ),
            ),

            const SizedBox(width: 16),

            // Controls hint
            const Text(
              'Controls: ← ↑ ↓ →',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 14,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Focus hint
        if (!_focusNode.hasFocus)
          const Text(
            'Click the game to focus',
            style: TextStyle(
              color: Color(0xFF616161),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
