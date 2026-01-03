import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../widgets/code_block.dart';
import '../widgets/tabbed_code_block.dart';
import '../widgets/doc_sidebar.dart';
import '../demos/grid_game/grid_game_widget.dart';

/// Demo page showing an interactive Fledge ECS example.
///
/// Displays a playable grid game alongside code explanations
/// showing how to recreate it as a desktop application.
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMediumScreen = screenWidth >= 768;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InkWell(
              onTap: () => context.go('/'),
              child: Text(
                'Fledge',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: FledgeTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Demo',
              style: theme.textTheme.headlineMedium?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isMediumScreen
          ? null
          : Drawer(
              child: DocSidebar(
                currentSection: 'demos',
                currentPage: 'grid-game',
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar (visible on medium+ screens)
          if (isMediumScreen)
            SizedBox(
              width: 280,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: theme.dividerColor,
                    ),
                  ),
                ),
                child: const DocSidebar(
                  currentSection: 'demos',
                  currentPage: 'grid-game',
                ),
              ),
            ),
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 24),
                      _buildDisclaimer(theme),
                      const SizedBox(height: 32),
                      _buildGameSection(theme),
                      const SizedBox(height: 48),
                      _buildCodeWalkthrough(theme),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grid Collector Game',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A complete walkthrough demonstrating the Two-World Architecture',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'This demo walks through building a game using Fledge\'s two-world architecture, '
          'which separates game logic from rendering. The Main World contains game state '
          '(positions, scores, entities), while the Render World contains GPU-optimized '
          'data (pixel coordinates, colors). Each frame, Extractors copy and transform '
          'data between worlds, enabling clean separation of concerns.',
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildDisclaimer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.amber[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Note',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This demo runs in the browser for demonstration purposes. '
                  'Fledge is optimized for desktop applications (Windows, macOS, Linux) '
                  'where it delivers significantly better performance. '
                  'Use the code examples below to build your own desktop application.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try It Out',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: const GridGameWidget(),
        ),
      ],
    );
  }

  Widget _buildCodeWalkthrough(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Building a game with ECS requires a different mindset than traditional object-oriented '
          'design. Instead of thinking "I need a Player class with move() and render() methods," '
          'you think "I need position data (component), movement logic (system), and rendering '
          '(painter)." This demo also demonstrates the two-world architecture that separates '
          'game logic from rendering.\n\n'
          'The walkthrough below follows the order you\'d typically design a game:\n'
          '1. Identify what data each entity needs (Components)\n'
          '2. Identify what global state is shared (Resources)\n'
          '3. Write the logic that operates on that data (Systems)\n'
          '4. Define extracted render data (Extraction)\n'
          '5. Render from the Render World (Painter)\n'
          '6. Connect everything with Flutter (Widget)\n'
          '7. Organize everything into reusable units (Plugins)',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        // Components section
        _buildTabbedCodeSection(
          theme,
          title: '1. Components',
          description:
              'The first step in designing an ECS game is identifying what data belongs '
              'on individual entities. Ask yourself: "Does each instance of this thing need '
              'its own copy of this data?" If yes, it\'s a component.\n\n'
              'For our grid game, we identify these components:\n\n'
              '• GridPosition - Every entity on the grid needs its own position. The player '
              'is at (5, 5) while a collectible might be at (2, 7). This is clearly per-entity data.\n\n'
              '• Player / Collectible / Tile - These are "marker components" with no data. They act '
              'like tags that let systems identify entity types. A system can query for "all entities '
              'with GridPosition AND Player" to find only the player.\n\n'
              '• TileColor - Each entity can have its own color. The player is green, collectibles '
              'are gold. This could have been hardcoded in rendering, but making it a component '
              'allows for dynamic color changes (power-ups, damage flash, etc.).\n\n'
              'Notice what\'s NOT a component: the grid size, spawn rate, or score. These don\'t '
              'belong to any specific entity—they\'re global to the game. That\'s how you know '
              'they should be Resources instead.',
          inheritanceCode: _componentsCode,
          annotationCode: _componentsAnnotationCode,
        ),
        const SizedBox(height: 32),

        // Resources section
        _buildCodeSection(
          theme,
          title: '2. Resources',
          description:
              'Resources are singletons—there\'s exactly one instance shared across all systems. '
              'The key question: "Is there only ONE of this in the entire game?" If yes, it\'s a resource.\n\n'
              '• GridConfig - There\'s one grid with one size. Every system that needs to know '
              'the grid dimensions reads the same GridConfig. Making this a resource means '
              'changing grid size in one place affects everything automatically.\n\n'
              '• GameScore - There\'s one score for the whole game. Multiple systems might read it '
              '(UI display) or write it (collection system), but they all share the same instance.\n\n'
              '• MovementTimer / SpawnTimer - These control game-wide timing. There\'s one movement '
              'rate and one spawn rate. Notice these hold mutable state (elapsed time) that persists '
              'across frames—resources are perfect for this.\n\n'
              '• ActionState (from InputPlugin) - Provided by the input plugin, this resource gives '
              'all systems access to the current input state. Systems don\'t need to know HOW input '
              'is captured, just what actions are active.\n\n'
              'The Timer resources show a common pattern: they encapsulate timing logic so systems '
              'can simply ask "should I act this frame?" rather than reimplementing delta time '
              'accumulation everywhere.',
          code: _resourcesCode,
        ),
        const SizedBox(height: 32),

        // Systems section
        _buildTabbedCodeSection(
          theme,
          title: '3. Systems',
          description:
              'Systems are where behavior lives. The key principle: each system should do ONE thing well. '
              'This makes them easy to understand, test, and reorder.\n\n'
              '• MovementSystem - ONLY handles player movement. It reads input, updates position, and '
              'clamps to bounds. It doesn\'t know about collectibles, scoring, or spawning. If movement '
              'feels wrong, you know exactly where to look.\n\n'
              '• SpawnSystem - ONLY creates new collectibles. It checks the timer, finds empty positions, '
              'and spawns entities. It doesn\'t move anything or check collisions.\n\n'
              '• CollectionSystem - ONLY handles pickup logic. It compares player position to collectible '
              'positions, updates the score, and despawns collected items.\n\n'
              'Notice how systems communicate through the world state, not direct calls. MovementSystem '
              'doesn\'t tell CollectionSystem "I moved here." Instead, it updates GridPosition, and '
              'CollectionSystem queries positions each frame. This decoupling means you can add/remove '
              'systems without breaking others.\n\n'
              'The SystemMeta declares what each system reads and writes. This enables Fledge to detect '
              'conflicts and potentially parallelize systems that don\'t share data. It also serves as '
              'documentation—you can see at a glance what data a system touches.',
          inheritanceCode: _systemsCode,
          annotationCode: _systemsAnnotationCode,
        ),
        const SizedBox(height: 32),

        // Extraction section
        _buildTabbedCodeSection(
          theme,
          title: '4. Extraction (Two-World Architecture)',
          description:
              'The two-world architecture separates game logic from rendering. The Main World '
              'contains game state (GridPosition, Player components), while the Render World '
              'contains GPU-optimized data (pixel coordinates, colors, entity types).\n\n'
              'Each frame, Extractors copy and transform data:\n\n'
              '• RenderWorld - A separate ECS world that\'s cleared each frame. Entities here '
              'are temporary; they exist only for rendering that frame.\n\n'
              '• ExtractedGridEntity - GPU-ready data with pre-computed pixel positions. The painter '
              'doesn\'t need to know about grid coordinates or do any math. Uses the ExtractedData '
              'mixin for semantic clarity and SortableExtractedData if draw ordering is needed.\n\n'
              '• GridEntityExtractor - Queries the main world for entities with GridPosition + TileColor, '
              'converts grid coordinates to pixels, and spawns ExtractedGridEntity in the render world.\n\n'
              'Why extract? This decoupling means:\n'
              '• Game code doesn\'t know about pixels or rendering\n'
              '• Render code doesn\'t know about game logic\n'
              '• You can swap render backends without changing game code\n'
              '• Data is optimized for GPU consumption (pre-computed transforms, sort keys, etc.)\n\n'
              'The Extractors registry collects all extractors and runs them in sequence. This happens '
              'after game systems run but before rendering.',
          inheritanceCode: _extractionCode,
          annotationCode: _extractionAnnotationCode,
        ),
        const SizedBox(height: 32),

        // Painter section
        _buildCodeSection(
          theme,
          title: '5. Rendering from the Render World',
          description:
              'The painter queries ONLY the Render World—it never sees the main game world. '
              'This is the key insight of the two-world architecture.\n\n'
              'Benefits of querying the render world:\n\n'
              '• Pre-computed data - Pixel positions are already calculated. The painter just draws.\n\n'
              '• Clean separation - The painter doesn\'t know about GridPosition, Player, or Collectible '
              'components. It only knows ExtractedGridEntity with pixel coordinates and entity types.\n\n'
              '• Type-based rendering - The EntityType enum (player, collectible, tile) tells the painter '
              'how to draw each entity without querying marker components.\n\n'
              'The shouldRepaint optimization is crucial for performance. Rather than repainting every '
              'frame, we compute a hash of the extracted state and only repaint when something changed. '
              'This is especially important for games where the state might not change every frame.\n\n'
              'Notice what the painter DOESN\'T do: it doesn\'t query GridPosition, it doesn\'t check '
              'world.has<Player>(), and it doesn\'t read GridConfig. All that data was transformed '
              'during extraction into render-ready format.',
          code: _painterCode,
        ),
        const SizedBox(height: 32),

        // Plugin section
        _buildTabbedCodeSection(
          theme,
          title: '6. Game Plugin',
          description:
              'Plugins are the organizational unit for Fledge code. They bundle related resources, '
              'systems, and setup logic into a reusable package.\n\n'
              'The GridGamePlugin does several things:\n\n'
              '• Registers game-specific resources (GridConfig, GameScore, timers). These are added '
              'to the App, making them available to all systems.\n\n'
              '• Adds systems in the correct order. The stage parameter (CoreStage.update) ensures '
              'systems run at the right time relative to input processing and rendering. Note the '
              'difference: annotation-based systems are functions (movementSystem), while class-based '
              'systems are instantiated (MovementSystem()).\n\n'
              '• Spawns initial entities. The player entity is created with its starting position, '
              'marker component, and color.\n\n'
              'Notice the separation of concerns: createInputPlugin() handles input configuration '
              'separately from game logic. This means you could swap input schemes (touch vs keyboard) '
              'without touching the game plugin.\n\n'
              'Plugins can depend on other plugins. GridGamePlugin expects InputPlugin to be added first '
              'because it reads ActionState. This dependency is documented but not enforced at compile '
              'time—if InputPlugin is missing, getResource<ActionState>() returns null and the system '
              'safely skips execution.\n\n'
              'For larger games, you might have plugins for each major system: AudioPlugin, PhysicsPlugin, '
              'UIPlugin, etc. Each encapsulates its own setup while sharing the same world.',
          inheritanceCode: _pluginCode,
          annotationCode: _pluginAnnotationCode,
        ),
        const SizedBox(height: 32),

        // Widget integration section
        _buildCodeSection(
          theme,
          title: '7. Flutter Integration',
          description:
              'The game widget bridges Flutter\'s widget world and Fledge\'s two-world ECS architecture. '
              'The key insight is that the game loop has three distinct phases.\n\n'
              'The game loop phases:\n\n'
              '1. app.tick() - Runs game logic systems in the Main World (movement, spawning, collection)\n\n'
              '2. extractors.extractAll() - Copies and transforms data from Main World to Render World\n\n'
              '3. setState() - Triggers Flutter repaint, painter queries Render World\n\n'
              'Key architectural points:\n\n'
              '• RenderWorld is created alongside the App and persists for the game\'s lifetime\n\n'
              '• Extractors are registered once during setup, then run every frame\n\n'
              '• The painter receives the RenderWorld (not the main World!)\n\n'
              '• Score comes from ExtractedScore in the render world, not GameScore in the main world\n\n'
              'This separation means the Flutter widget layer only ever sees render-ready data. '
              'It doesn\'t know about GridPosition, Player components, or game logic—just pixels and colors.',
          code: _widgetCode,
        ),
        const SizedBox(height: 32),

        // Main entry point section
        _buildCodeSection(
          theme,
          title: '8. Application Entry Point',
          description:
              'The main() function establishes the application\'s foundation. The App is created once '
              'and shared throughout the widget tree—this is crucial for maintaining consistent state.\n\n'
              '• App creation - We create a single App instance and add core plugins that persist for '
              'the application\'s lifetime: WindowPlugin for window management, TimePlugin for delta time, '
              'and InputPlugin for input handling.\n\n'
              '• Initial tick - The first app.tick() initializes all systems. This is necessary before '
              'Flutter starts because some systems (like WindowPlugin) need to run before rendering.\n\n'
              '• Passing the App - The App is passed to the root widget, which passes it through navigation '
              'to screens that need it. This pattern ensures there\'s ONE App instance, ONE World, and ONE '
              'set of resources throughout the application.\n\n'
              'Notice that game-specific plugins (GridGamePlugin) are NOT added here. They\'re added when '
              'entering the game screen. This keeps the main setup focused on infrastructure that\'s always '
              'needed, while game logic is loaded only when playing.\n\n'
              'For games with loading screens or asset preloading, you\'d extend this pattern: create the App, '
              'tick once to initialize, load assets asynchronously, then start the Flutter widget tree.',
          code: _mainCode,
        ),
        const SizedBox(height: 32),

        // Screen navigation section
        _buildCodeSection(
          theme,
          title: '9. Screen Navigation',
          description:
              'This section demonstrates the recommended pattern for mixing Flutter UI with ECS gameplay. '
              'The key insight: use Flutter for what it\'s good at (UI, navigation, animations) and ECS '
              'for what it\'s good at (game state, systems, entities).\n\n'
              '• SplashScreen / TitleScreen - These are pure Flutter widgets. No ECS logic needed—they\'re '
              'just UI. They receive the App but don\'t run its tick loop. This keeps splash screens simple '
              'and lets you use Flutter\'s animation system for transitions.\n\n'
              '• GameScreen - This is where ECS takes over. It adds the game plugin (registering game-specific '
              'resources and systems), creates an AnimationController for the game loop, and calls app.tick() '
              'every frame. The setState() after each tick triggers a rebuild so CustomPaint can redraw.\n\n'
              '• The game loop pattern - AnimationController with an hour-long duration and repeat() gives us '
              'a continuous tick. Each tick: (1) app.tick() runs all ECS systems, (2) setState() triggers '
              'Flutter rebuild, (3) CustomPaint\'s shouldRepaint checks for changes.\n\n'
              'This architecture supports common game patterns:\n'
              '• Pause menus: Stop the AnimationController, show Flutter dialog, resume when dismissed\n'
              '• Scene transitions: Navigate to loading screen, swap plugins, navigate to new game screen\n'
              '• Game over: Navigate back to title screen, the game state persists in the App if needed\n\n'
              'The App is the bridge between screens. Pass it through navigation, and any screen can access '
              'the same world, read resources, or add new plugins.',
          code: _screensCode,
        ),
      ],
    );
  }

  Widget _buildCodeSection(
    ThemeData theme, {
    required String title,
    required String description,
    required String code,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        CodeBlock(
          code: code,
          language: 'dart',
          isDark: theme.brightness == Brightness.dark,
        ),
      ],
    );
  }

  /// Builds a code section with tabs for switching between inheritance and annotation forms.
  Widget _buildTabbedCodeSection(
    ThemeData theme, {
    required String title,
    required String description,
    required String inheritanceCode,
    required String annotationCode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TabbedCodeBlock(
          tabs: [
            CodeTab(label: 'Annotations', code: annotationCode),
            CodeTab(label: 'Inheritance', code: inheritanceCode),
          ],
          language: 'dart',
          isDark: theme.brightness == Brightness.dark,
        ),
      ],
    );
  }

}

// Code snippets for the walkthrough
const _componentsCode = '''
import 'dart:ui';

/// Grid position component - stores discrete tile coordinates.
///
/// This is the logical position in the grid (0-9 for a 10x10 grid).
/// The rendering system converts this to pixel coordinates.
class GridPosition {
  int x;
  int y;

  GridPosition(this.x, this.y);

  @override
  String toString() => 'GridPosition(\$x, \$y)';

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Marker component for the player entity.
class Player {
  const Player();
}

/// Marker component for collectible items.
class Collectible {
  /// Points awarded when collected.
  final int points;

  const Collectible([this.points = 10]);
}

/// Marker component for background tiles.
class Tile {
  const Tile();
}

/// Visual appearance component - the color to render.
class TileColor {
  Color color;

  TileColor(this.color);
}''';

const _resourcesCode = '''
/// Game actions enum - defines all input actions.
enum GameActions { move }

/// Grid configuration resource.
///
/// Defines the size and scale of the game grid.
class GridConfig {
  /// Number of tiles horizontally.
  final int width;

  /// Number of tiles vertically.
  final int height;

  /// Size of each tile in pixels.
  final double tileSize;

  /// Gap between tiles in pixels.
  final double gap;

  const GridConfig({
    this.width = 10,
    this.height = 10,
    this.tileSize = 28,
    this.gap = 2,
  });

  /// Total pixel width of the grid.
  double get totalWidth => width * (tileSize + gap) - gap;

  /// Total pixel height of the grid.
  double get totalHeight => height * (tileSize + gap) - gap;
}

/// Game score resource.
class GameScore {
  int value = 0;

  void add(int points) => value += points;

  void reset() => value = 0;
}

/// Movement timer resource - controls movement rate for grid-based movement.
///
/// Converts continuous input into discrete grid steps at a controlled rate.
class MovementTimer {
  double _elapsed = 0;

  /// Delay before first repeat.
  final double initialDelay = 0.15;

  /// Interval between movements while held.
  final double repeatInterval = 0.1;

  /// Whether initial move has happened.
  bool _initialMoveDone = false;

  /// Updates timer and returns true if movement should occur.
  bool tick(double delta, bool hasInput) {
    if (!hasInput) {
      _elapsed = 0;
      _initialMoveDone = false;
      return false;
    }

    // Immediate movement on first press
    if (!_initialMoveDone) {
      _initialMoveDone = true;
      _elapsed = 0;
      return true;
    }

    _elapsed += delta;
    if (_elapsed >= repeatInterval) {
      _elapsed -= repeatInterval;
      return true;
    }
    return false;
  }
}

/// Spawn timer resource - controls collectible spawning rate.
class SpawnTimer {
  double elapsed = 0;
  final double interval;

  SpawnTimer([this.interval = 2.0]);

  /// Returns true if it's time to spawn and resets the timer.
  bool tick(double delta) {
    elapsed += delta;
    if (elapsed >= interval) {
      elapsed -= interval;
      return true;
    }
    return false;
  }

  void reset() => elapsed = 0;
}''';

const _systemsCode = '''
import 'dart:math';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

/// System that moves the player based on input.
///
/// Reads the ActionState resource (from InputPlugin), updates the Player's
/// GridPosition, and clamps to grid bounds. Uses MovementTimer to convert
/// continuous input into discrete grid steps.
class MovementSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'movement',
        writes: {ComponentId.of<GridPosition>()},
        reads: {ComponentId.of<Player>()},
        resourceReads: {ActionState, MovementTimer, GridConfig, Time},
      );

  @override
  Future<void> run(World world) async {
    final actions = world.getResource<ActionState>();
    final timer = world.getResource<MovementTimer>();
    final config = world.getResource<GridConfig>();
    final time = world.getResource<Time>();
    if (actions == null || timer == null || config == null || time == null) {
      return;
    }

    // Get movement vector from input (arrow keys or WASD)
    final (dx, dy) = actions.vector2Value(ActionId.fromEnum(GameActions.move));
    final hasInput = dx != 0 || dy != 0;

    // Check if movement should occur this frame
    if (!timer.tick(time.delta, hasInput)) return;

    // Convert to grid direction (-1, 0, or 1)
    final gridDx = dx > 0.5 ? 1 : (dx < -0.5 ? -1 : 0);
    final gridDy = dy > 0.5 ? 1 : (dy < -0.5 ? -1 : 0);

    // Find and move the player
    for (final (_, pos) in world
        .query1<GridPosition>(filter: const With<Player>())
        .iter()) {
      pos.x = (pos.x + gridDx).clamp(0, config.width - 1);
      pos.y = (pos.y + gridDy).clamp(0, config.height - 1);
    }
  }
}

/// System that spawns collectibles periodically.
///
/// Uses the SpawnTimer resource to control spawn rate.
/// Spawns items at random empty tiles.
class SpawnSystem extends System {
  final Random _random = Random();

  @override
  SystemMeta get meta => SystemMeta(
        name: 'spawn',
        reads: {
          ComponentId.of<GridPosition>(),
          ComponentId.of<Player>(),
          ComponentId.of<Collectible>(),
        },
        resourceReads: {SpawnTimer, Time, GridConfig},
      );

  @override
  Future<void> run(World world) async {
    final timer = world.getResource<SpawnTimer>();
    final time = world.getResource<Time>();
    final config = world.getResource<GridConfig>();
    if (timer == null || time == null || config == null) return;

    // Check if it's time to spawn
    if (!timer.tick(time.delta)) return;

    // Find occupied positions
    final occupied = <(int, int)>{};
    for (final (_, pos) in world.query1<GridPosition>().iter()) {
      occupied.add((pos.x, pos.y));
    }

    // Find empty positions
    final empty = <(int, int)>[];
    for (var x = 0; x < config.width; x++) {
      for (var y = 0; y < config.height; y++) {
        if (!occupied.contains((x, y))) {
          empty.add((x, y));
        }
      }
    }

    // Spawn at random empty position
    if (empty.isNotEmpty) {
      final pos = empty[_random.nextInt(empty.length)];
      world.spawn()
        ..insert(GridPosition(pos.\$1, pos.\$2))
        ..insert(const Collectible())
        ..insert(TileColor(const Color(0xFFFFD700))); // Gold color
    }
  }
}

/// System that detects player/item collision and handles collection.
///
/// When player position matches a collectible position:
/// - Despawns the collectible
/// - Increments the score
class CollectionSystem extends System {
  @override
  SystemMeta get meta => SystemMeta(
        name: 'collection',
        reads: {
          ComponentId.of<GridPosition>(),
          ComponentId.of<Player>(),
          ComponentId.of<Collectible>(),
        },
        resourceWrites: {GameScore},
      );

  @override
  Future<void> run(World world) async {
    final score = world.getResource<GameScore>();
    if (score == null) return;

    // Find player position
    GridPosition? playerPos;
    for (final (_, pos) in world
        .query1<GridPosition>(filter: const With<Player>())
        .iter()) {
      playerPos = pos;
      break;
    }
    if (playerPos == null) return;

    // Check collectibles for overlap
    final toCollect = <Entity>[];
    for (final (entity, pos, collectible) in world
        .query2<GridPosition, Collectible>()
        .iter()) {
      if (pos.x == playerPos.x && pos.y == playerPos.y) {
        toCollect.add(entity);
        score.add(collectible.points);
      }
    }

    // Despawn collected items
    for (final entity in toCollect) {
      world.despawn(entity);
    }
  }
}''';

const _extractionCode = '''
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';

/// A simplified render world for the grid game.
///
/// This demonstrates the two-world architecture where:
/// - The main World contains game logic (GridPosition, Player, etc.)
/// - The RenderWorld contains GPU-optimized render data (ExtractedGridEntity)
class RenderWorld {
  final World _world = World();

  /// Clears all entities but preserves resources.
  void clear() => _world.clear();

  /// Spawns a new entity in the render world.
  EntityCommands spawn() => _world.spawn();

  /// Queries for entities with a single component type.
  Query1<T> query1<T>({QueryFilter? filter}) =>
      _world.query1<T>(filter: filter);

  /// Gets a resource from the render world.
  T? getResource<T>() => _world.getResource<T>();

  /// Inserts a resource into the render world.
  void insertResource<T>(T resource) => _world.insertResource(resource);
}

/// Entity type for rendering differentiation.
enum GridEntityType { player, collectible, tile }

/// Extracted render data for a grid entity.
///
/// Contains pre-computed pixel coordinates and all data needed for rendering,
/// with no references to game logic components.
class ExtractedGridEntity {
  final double pixelX;
  final double pixelY;
  final double size;
  final Color color;
  final GridEntityType entityType;

  const ExtractedGridEntity({
    required this.pixelX,
    required this.pixelY,
    required this.size,
    required this.color,
    required this.entityType,
  });

  Rect get rect => Rect.fromLTWH(pixelX, pixelY, size, size);
}

/// Base class for extractors that copy data between worlds.
abstract class Extractor {
  void extract(World mainWorld, RenderWorld renderWorld);
}

/// Registry of extractors to run each frame.
class Extractors {
  final List<Extractor> _extractors = [];

  void register(Extractor extractor) => _extractors.add(extractor);

  void extractAll(World mainWorld, RenderWorld renderWorld) {
    renderWorld.clear();  // Clear entities each frame
    for (final extractor in _extractors) {
      extractor.extract(mainWorld, renderWorld);
    }
  }
}

/// Extractor that transforms grid entities into render-ready data.
class GridEntityExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final config = mainWorld.getResource<GridConfig>();
    if (config == null) return;

    for (final (entity, gridPos, tileColor)
        in mainWorld.query2<GridPosition, TileColor>().iter()) {
      // Convert grid position to pixel position
      final pixelX = gridPos.x * (config.tileSize + config.gap);
      final pixelY = gridPos.y * (config.tileSize + config.gap);

      // Determine entity type from marker components
      GridEntityType entityType;
      if (mainWorld.has<Player>(entity)) {
        entityType = GridEntityType.player;
      } else if (mainWorld.has<Collectible>(entity)) {
        entityType = GridEntityType.collectible;
      } else {
        entityType = GridEntityType.tile;
      }

      // Spawn extracted entity in render world
      renderWorld.spawn().insert(ExtractedGridEntity(
        pixelX: pixelX,
        pixelY: pixelY,
        size: config.tileSize,
        color: tileColor.color,
        entityType: entityType,
      ));
    }
  }
}''';

const _extractionAnnotationCode = '''
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
import 'package:fledge_render/fledge_render.dart';

// Generated code - run: dart run build_runner build
part 'extraction.g.dart';

/// A simplified render world for the grid game.
class RenderWorld {
  final World _world = World();
  void clear() => _world.clear();
  EntityCommands spawn() => _world.spawn();
  Query1<T> query1<T>({QueryFilter? filter}) => _world.query1<T>(filter: filter);
  T? getResource<T>() => _world.getResource<T>();
  void insertResource<T>(T resource) => _world.insertResource(resource);
}

/// Entity type for rendering differentiation.
enum GridEntityType { player, collectible, tile }

/// Extracted render data for a grid entity.
///
/// Combines @component annotation with ExtractedData mixin.
/// For entities needing draw ordering, add SortableExtractedData:
///
/// ```dart
/// @component
/// class ExtractedSprite with ExtractedData, SortableExtractedData {
///   @override
///   final int sortKey;
///   // ...
/// }
/// ```
@component
class ExtractedGridEntity with ExtractedData {
  final double pixelX;
  final double pixelY;
  final double size;
  final Color color;
  final GridEntityType entityType;

  const ExtractedGridEntity({
    required this.pixelX,
    required this.pixelY,
    required this.size,
    required this.color,
    required this.entityType,
  });

  Rect get rect => Rect.fromLTWH(pixelX, pixelY, size, size);
}

/// Base class for extractors that copy data between worlds.
abstract class Extractor {
  void extract(World mainWorld, RenderWorld renderWorld);
}

/// Registry of extractors to run each frame.
class Extractors {
  final List<Extractor> _extractors = [];
  void register(Extractor extractor) => _extractors.add(extractor);
  void extractAll(World mainWorld, RenderWorld renderWorld) {
    renderWorld.clear();
    for (final extractor in _extractors) {
      extractor.extract(mainWorld, renderWorld);
    }
  }
}

/// Extractor that transforms grid entities into render-ready data.
class GridEntityExtractor extends Extractor {
  @override
  void extract(World mainWorld, RenderWorld renderWorld) {
    final config = mainWorld.getResource<GridConfig>();
    if (config == null) return;

    for (final (entity, gridPos, tileColor)
        in mainWorld.query2<GridPosition, TileColor>().iter()) {
      final pixelX = gridPos.x * (config.tileSize + config.gap);
      final pixelY = gridPos.y * (config.tileSize + config.gap);

      GridEntityType entityType;
      if (mainWorld.has<Player>(entity)) {
        entityType = GridEntityType.player;
      } else if (mainWorld.has<Collectible>(entity)) {
        entityType = GridEntityType.collectible;
      } else {
        entityType = GridEntityType.tile;
      }

      renderWorld.spawn().insert(ExtractedGridEntity(
        pixelX: pixelX,
        pixelY: pixelY,
        size: config.tileSize,
        color: tileColor.color,
        entityType: entityType,
      ));
    }
  }
}''';

const _painterCode = '''
import 'dart:ui';

import 'package:flutter/material.dart' hide Color;

/// Custom painter that renders from the Render World.
///
/// Key insight: This painter queries ONLY the RenderWorld.
/// It never sees GridPosition, Player, or other game components.
/// All data is pre-computed and GPU-ready.
class GridGamePainter extends CustomPainter {
  final RenderWorld renderWorld;

  int _lastStateHash = 0;

  GridGamePainter(this.renderWorld);

  @override
  void paint(Canvas canvas, Size size) {
    final config = renderWorld.getResource<ExtractedGridConfig>();
    if (config == null) return;

    final paint = Paint()..style = PaintingStyle.fill;

    _drawGridBackground(canvas, config, paint);
    _drawEntities(canvas, paint);
  }

  /// Draws all extracted entities.
  /// Note: We query ExtractedGridEntity - pixel positions already computed!
  void _drawEntities(Canvas canvas, Paint paint) {
    for (final (_, extracted) in renderWorld.query1<ExtractedGridEntity>().iter()) {
      paint.color = extracted.color;

      switch (extracted.entityType) {
        case GridEntityType.player:
          _drawPlayer(canvas, extracted.rect, paint);
        case GridEntityType.collectible:
          _drawCollectible(canvas, extracted, paint);
        case GridEntityType.tile:
          _drawTile(canvas, extracted.rect, paint);
      }
    }
  }

  void _drawPlayer(Canvas canvas, Rect rect, Paint paint) {
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rRect, paint);

    paint
      ..color = const Color(0xFF00AA00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rRect, paint);
    paint.style = PaintingStyle.fill;
  }

  void _drawCollectible(Canvas canvas, ExtractedGridEntity extracted, Paint paint) {
    final center = extracted.rect.center;
    final radius = extracted.size / 2 - 2;

    canvas.drawCircle(Offset(center.dx, center.dy), radius, paint);

    paint.color = const Color(0xFFFFE55C);
    canvas.drawCircle(
      Offset(center.dx - radius / 3, center.dy - radius / 3),
      radius / 4,
      paint,
    );
  }

  void _drawTile(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );
  }

  void _drawGridBackground(Canvas canvas, ExtractedGridConfig config, Paint paint) {
    paint.color = const Color(0xFF1A1A2E);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, config.totalWidth, config.totalHeight),
      paint,
    );

    paint.color = const Color(0xFF252540);
    for (var x = 0; x < config.width; x++) {
      for (var y = 0; y < config.height; y++) {
        final px = x * (config.tileSize + config.gap);
        final py = y * (config.tileSize + config.gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(px, py, config.tileSize, config.tileSize),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridGamePainter oldDelegate) {
    final newHash = _computeStateHash();
    if (newHash != _lastStateHash) {
      _lastStateHash = newHash;
      return true;
    }
    return false;
  }

  int _computeStateHash() {
    var hash = 0;
    for (final (entity, extracted) in renderWorld.query1<ExtractedGridEntity>().iter()) {
      hash ^= entity.hashCode ^
          extracted.pixelX.toInt() ^
          (extracted.pixelY.toInt() << 8);
    }
    final score = renderWorld.getResource<ExtractedScore>()?.value ?? 0;
    hash ^= score << 24;
    return hash;
  }
}''';

const _pluginCode = '''
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

/// Plugin that sets up the Grid Game.
///
/// Configures resources and systems for the game, and spawns
/// the initial player entity.
///
/// Note: This plugin expects InputPlugin to be added first for input handling.
///
/// ## Usage
///
/// ```dart
/// final app = App()
///   ..addPlugin(TimePlugin())
///   ..addPlugin(createInputPlugin())  // InputPlugin with bindings
///   ..addPlugin(GridGamePlugin());
///
/// // Run game loop
/// await app.tick();
/// ```
class GridGamePlugin implements Plugin {
  /// Grid configuration (optional, uses defaults if not provided).
  final GridConfig config;

  GridGamePlugin({this.config = const GridConfig()});

  @override
  void build(App app) {
    // Insert game-specific resources
    // (InputPlugin provides ActionState for input handling)
    app
        .insertResource(config)
        .insertResource(GameScore())
        .insertResource(MovementTimer())
        .insertResource(SpawnTimer(2.0));

    // Add systems in execution order
    app
        .addSystem(MovementSystem(), stage: CoreStage.update)
        .addSystem(SpawnSystem(), stage: CoreStage.update)
        .addSystem(CollectionSystem(), stage: CoreStage.update);

    // Spawn player at center
    app.world.spawn()
      ..insert(GridPosition(config.width ~/ 2, config.height ~/ 2))
      ..insert(const Player())
      ..insert(TileColor(const Color(0xFF00DD00))); // Bright green
  }

  @override
  void cleanup() {}
}

/// Creates the InputPlugin with game input bindings.
///
/// Binds arrow keys and WASD to movement, gamepad left stick and D-pad.
InputPlugin createInputPlugin() {
  final inputMap = InputMap.builder()
      .bindArrows(ActionId.fromEnum(GameActions.move))
      .bindWasd(ActionId.fromEnum(GameActions.move))
      .bindLeftStick(ActionId.fromEnum(GameActions.move))
      .bindDpad(ActionId.fromEnum(GameActions.move))
      .build();

  return InputPlugin.simple(
    context: InputContext(name: 'gameplay', map: inputMap),
  );
}''';

const _widgetCode = '''
import 'package:flutter/material.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;

/// Game widget demonstrating the two-world architecture.
///
/// Key insight: The game loop has THREE phases:
/// 1. app.tick() - Run game logic (Main World)
/// 2. extractors.extractAll() - Copy to Render World
/// 3. setState() - Trigger repaint (queries Render World)
class GridGameWidget extends StatefulWidget {
  /// The shared App instance created in main().
  final App app;

  const GridGameWidget({super.key, required this.app});

  @override
  State<GridGameWidget> createState() => _GridGameWidgetState();
}

class _GridGameWidgetState extends State<GridGameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  // Two-world architecture: separate worlds for logic and rendering
  late RenderWorld _renderWorld;
  late Extractors _extractors;

  App get _app => widget.app;  // Use the shared App from main()
  World get _world => _app.world;

  @override
  void initState() {
    super.initState();
    _setupRenderWorld();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )
      ..addListener(_gameLoop)
      ..repeat();
  }

  void _setupRenderWorld() {
    // The App and its plugins were created in main() - we just set up rendering here

    // Create the render world (separate from main world)
    _renderWorld = RenderWorld();

    // Set up extractors that copy data from main world to render world
    _extractors = Extractors()
      ..register(GridConfigExtractor())
      ..register(ScoreExtractor())
      ..register(GridEntityExtractor());
  }

  void _gameLoop() {
    // 1. Run game logic systems (main world)
    _app.tick();

    // 2. Extract: Copy data from main world to render world
    _extractors.extractAll(_world, _renderWorld);

    // 3. Trigger repaint (painter will query render world)
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Read from render world (extracted data) for display
    final config = _renderWorld.getResource<ExtractedGridConfig>();
    final score = _renderWorld.getResource<ExtractedScore>()?.value ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          // Pass render world to painter (not main world!)
          painter: GridGamePainter(_renderWorld),
          size: Size(config?.totalWidth ?? 298, config?.totalHeight ?? 298),
        ),
        const SizedBox(height: 16),
        Text('Score: \$score', style: const TextStyle(color: Color(0xFFFFD700))),
      ],
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}''';

const _mainCode = '''
import 'package:flutter/material.dart';
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_window/fledge_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create the App ONCE at startup with ALL plugins
  final app = App()
    ..addPlugin(WindowPlugin.borderless(title: 'Grid Collector'))
    ..addPlugin(TimePlugin())
    ..addPlugin(createInputPlugin())  // Input handling with bindings
    ..addPlugin(GridGamePlugin());     // Game-specific components and systems

  // Initialize window and input systems
  await app.tick();

  // Pass the shared App to the Flutter widget tree
  runApp(GameApp(app: app));
}

class GameApp extends StatelessWidget {
  final App app;
  const GameApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grid Collector',
      theme: ThemeData.dark(),
      // Pass the App through to your game widget
      home: GridGameWidget(app: app),
    );
  }
}
''';

const _screensCode = '''
// Splash Screen - pure Flutter, no ECS needed
class SplashScreen extends StatefulWidget {
  final App app;
  const SplashScreen({super.key, required this.app});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), _goToTitle);
  }

  void _goToTitle() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TitleScreen(app: widget.app)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('FLEDGE', style: TextStyle(fontSize: 48)),
      ),
    );
  }
}

// Title Screen - pure Flutter with navigation to game
class TitleScreen extends StatelessWidget {
  final App app;
  const TitleScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Grid Collector', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => GameScreen(app: app)),
              ),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}

// Game Screen - adds game plugin and runs the ECS game loop
class GameScreen extends StatefulWidget {
  final App app;
  const GameScreen({super.key, required this.app});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    // Add game-specific plugin to the shared App
    widget.app.addPlugin(GridGamePlugin());

    _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))
      ..addListener(() {
        widget.app.tick();  // Run ECS systems
        setState(() {});    // Trigger repaint
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use GridGameWidget which wraps content with InputWidget
    return Scaffold(
      body: GridGameWidget(app: widget.app),
    );
  }
}
''';

// Annotation-based code versions for the tabbed code blocks
const _componentsAnnotationCode = '''
import 'dart:ui';

import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';

// Generated code - run: dart run build_runner build
part 'components.g.dart';

/// Grid position component - stores discrete tile coordinates.
///
/// This is the logical position in the grid (0-9 for a 10x10 grid).
/// The rendering system converts this to pixel coordinates.
@component
class GridPosition {
  int x;
  int y;

  GridPosition(this.x, this.y);

  @override
  String toString() => 'GridPosition(\$x, \$y)';

  @override
  bool operator ==(Object other) =>
      other is GridPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Marker component for the player entity.
@component
class Player {
  const Player();
}

/// Marker component for collectible items.
@component
class Collectible {
  /// Points awarded when collected.
  final int points;

  const Collectible([this.points = 10]);
}

/// Marker component for background tiles.
@component
class Tile {
  const Tile();
}

/// Visual appearance component - the color to render.
@component
class TileColor {
  Color color;

  TileColor(this.color);
}''';

const _systemsAnnotationCode = '''
import 'dart:math';
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_ecs_annotations/fledge_ecs_annotations.dart';
import 'package:fledge_input/fledge_input.dart';

// Generated code - run: dart run build_runner build
part 'systems.g.dart';

/// System that moves the player based on input.
///
/// With annotations, metadata is inferred from the function signature.
/// The generator analyzes which components and resources are accessed.
@system
Future<void> movementSystem(World world) async {
  final actions = world.getResource<ActionState>();
  final timer = world.getResource<MovementTimer>();
  final config = world.getResource<GridConfig>();
  final time = world.getResource<Time>();
  if (actions == null || timer == null || config == null || time == null) {
    return;
  }

  // Get movement vector from input (arrow keys or WASD)
  final (dx, dy) = actions.vector2Value(ActionId.fromEnum(GameActions.move));
  final hasInput = dx != 0 || dy != 0;

  // Check if movement should occur this frame
  if (!timer.tick(time.delta, hasInput)) return;

  // Convert to grid direction (-1, 0, or 1)
  final gridDx = dx > 0.5 ? 1 : (dx < -0.5 ? -1 : 0);
  final gridDy = dy > 0.5 ? 1 : (dy < -0.5 ? -1 : 0);

  // Find and move the player
  for (final (_, pos) in world
      .query1<GridPosition>(filter: const With<Player>())
      .iter()) {
    pos.x = (pos.x + gridDx).clamp(0, config.width - 1);
    pos.y = (pos.y + gridDy).clamp(0, config.height - 1);
  }
}

/// System that spawns collectibles periodically.
///
/// Uses the SpawnTimer resource to control spawn rate.
/// Spawns items at random empty tiles.
@system
Future<void> spawnSystem(World world) async {
  final random = Random();
  final timer = world.getResource<SpawnTimer>();
  final time = world.getResource<Time>();
  final config = world.getResource<GridConfig>();
  if (timer == null || time == null || config == null) return;

  // Check if it's time to spawn
  if (!timer.tick(time.delta)) return;

  // Find occupied positions
  final occupied = <(int, int)>{};
  for (final (_, pos) in world.query1<GridPosition>().iter()) {
    occupied.add((pos.x, pos.y));
  }

  // Find empty positions
  final empty = <(int, int)>[];
  for (var x = 0; x < config.width; x++) {
    for (var y = 0; y < config.height; y++) {
      if (!occupied.contains((x, y))) {
        empty.add((x, y));
      }
    }
  }

  // Spawn at random empty position
  if (empty.isNotEmpty) {
    final pos = empty[random.nextInt(empty.length)];
    world.spawn()
      ..insert(GridPosition(pos.\$1, pos.\$2))
      ..insert(const Collectible())
      ..insert(TileColor(const Color(0xFFFFD700))); // Gold color
  }
}

/// System that detects player/item collision and handles collection.
///
/// When player position matches a collectible position:
/// - Despawns the collectible
/// - Increments the score
@system
Future<void> collectionSystem(World world) async {
  final score = world.getResource<GameScore>();
  if (score == null) return;

  // Find player position
  GridPosition? playerPos;
  for (final (_, pos) in world
      .query1<GridPosition>(filter: const With<Player>())
      .iter()) {
    playerPos = pos;
    break;
  }
  if (playerPos == null) return;

  // Check collectibles for overlap
  final toCollect = <Entity>[];
  for (final (entity, pos, collectible) in world
      .query2<GridPosition, Collectible>()
      .iter()) {
    if (pos.x == playerPos.x && pos.y == playerPos.y) {
      toCollect.add(entity);
      score.add(collectible.points);
    }
  }

  // Despawn collected items
  for (final entity in toCollect) {
    world.despawn(entity);
  }
}''';

const _pluginAnnotationCode = '''
import 'dart:ui';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';

// Import generated code from build_runner
// Run: dart run build_runner build
import 'components.g.dart';  // Generated component wrappers
import 'systems.g.dart';     // Contains movementSystem, spawnSystem, collectionSystem

/// Plugin that sets up the Grid Game.
///
/// When using annotations, systems are generated as functions that wrap
/// FunctionSystem. Import the generated .g.dart file and reference them
/// by name (movementSystem) rather than instantiating classes (MovementSystem()).
class GridGamePlugin implements Plugin {
  final GridConfig config;

  GridGamePlugin({this.config = const GridConfig()});

  @override
  void build(App app) {
    // Insert game-specific resources
    app
        .insertResource(config)
        .insertResource(GameScore())
        .insertResource(MovementTimer())
        .insertResource(SpawnTimer(2.0));

    // Add annotation-generated systems (functions, not class instances)
    // These are generated from @system annotated functions in systems.dart
    app
        .addSystem(movementSystem, stage: CoreStage.update)
        .addSystem(spawnSystem, stage: CoreStage.update)
        .addSystem(collectionSystem, stage: CoreStage.update);

    // Spawn player at center
    app.world.spawn()
      ..insert(GridPosition(config.width ~/ 2, config.height ~/ 2))
      ..insert(const Player())
      ..insert(TileColor(const Color(0xFF00DD00)));
  }

  @override
  void cleanup() {}
}

/// Creates the InputPlugin with game input bindings.
InputPlugin createInputPlugin() {
  final inputMap = InputMap.builder()
      .bindArrows(ActionId.fromEnum(GameActions.move))
      .bindWasd(ActionId.fromEnum(GameActions.move))
      .bindLeftStick(ActionId.fromEnum(GameActions.move))
      .bindDpad(ActionId.fromEnum(GameActions.move))
      .build();

  return InputPlugin.simple(
    context: InputContext(name: 'gameplay', map: inputMap),
  );
}''';
