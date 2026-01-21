import 'dart:ui';

import 'package:flutter/material.dart' hide Color;
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_render/fledge_render.dart';

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
/// - Resources: GridConfig, GameScore, ActionState (from InputPlugin), MoveTimer, SpawnTimer
/// - Input handled via `fledge_input` plugin with `InputWidget` wrapper
///
/// **Render World** (GPU-ready data):
/// - ExtractedGridEntity with pre-computed pixel coordinates
/// - ExtractedGridConfig, ExtractedScore resources
///
/// Each frame:
/// 1. InputWidget captures keyboard input and updates ActionState
/// 2. Main world systems run (game logic)
/// 3. RenderPlugin's extraction system copies data to render world
/// 4. Painter queries only the render world
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

  /// Convenience accessor for the main ECS world (game logic).
  World get _world => _app.world;

  @override
  void initState() {
    super.initState();
    _setupGame();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )
      ..addListener(_gameLoop)
      ..repeat();
  }

  void _setupGame() {
    // Create the app with plugins
    // RenderPlugin provides: Extractors, RenderWorld, and RenderExtractionSystem
    // GridGamePlugin configures InputPlugin for arrow key input
    _app = App()
      ..addPlugin(TimePlugin())
      ..addPlugin(RenderPlugin())
      ..addPlugin(GridGamePlugin());

    // Register extractors with the Extractors resource from RenderPlugin
    final extractors = _world.getResource<Extractors>()!;
    extractors.register(GridConfigExtractor());
    extractors.register(ScoreExtractor());
    extractors.register(GridEntityExtractor());
  }

  void _gameLoop() {
    // Run game logic AND extraction (RenderPlugin runs extraction at CoreStage.last)
    _app.tick();

    // Trigger repaint (painter will query render world)
    setState(() {});
  }

  void _resetGame() {
    // Recreate the app with fresh state
    _setupGame();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read from render world (extracted data) for display
    final renderWorld = _world.getResource<RenderWorld>();
    final config = renderWorld?.getResource<ExtractedGridConfig>();
    final score = renderWorld?.getResource<ExtractedScore>()?.value ?? 0;

    // Fallback to main world config if render world hasn't been populated yet
    final mainConfig = _world.getResource<GridConfig>()!;
    final displayWidth = config?.totalWidth ?? mainConfig.totalWidth;
    final displayHeight = config?.totalHeight ?? mainConfig.totalHeight;

    // InputWidget captures all keyboard input and injects it into the ECS world
    return InputWidget(
      world: _world,
      autofocus: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Game canvas
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF4CAF50),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                // Pass render world to painter (not main world!)
                painter:
                    renderWorld != null ? GridGamePainter(renderWorld) : null,
                size: Size(displayWidth, displayHeight),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ],
      ),
    );
  }
}
