import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../widgets/code_block.dart';
import '../widgets/doc_sidebar.dart';
import '../widgets/search_dialog.dart';
import '../services/search_service.dart';
import '../demos/grid_game/grid_game_widget.dart';

/// Demo page showing an interactive Fledge ECS example.
///
/// Displays a playable grid game alongside code explanations
/// showing how to recreate it as a desktop application.
class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

/// Section definition for the table of contents.
class _Section {
  final String id;
  final String title;
  final int level;

  const _Section(this.id, this.title, {this.level = 2});
}

/// All sections in the demo page for TOC navigation.
const _sections = [
  _Section('try-it-out', 'Try It Out'),
  _Section('how-it-works', 'How It Works'),
  _Section('components', '1. Components', level: 3),
  _Section('resources', '2. Resources', level: 3),
  _Section('systems', '3. Systems', level: 3),
  _Section('extraction', '4. Extraction', level: 3),
  _Section('rendering', '5. Rendering', level: 3),
  _Section('flutter-integration', '6. Flutter Integration', level: 3),
];

const _demoSource = 'lib/demos/grid_game';

class _DemoPageState extends State<DemoPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  final FocusNode _keyboardFocusNode = FocusNode();
  String? _activeSectionId;

  @override
  void initState() {
    super.initState();
    // Initialize section keys
    for (final section in _sections) {
      _sectionKeys[section.id] = GlobalKey();
    }
    _activeSectionId = _sections.first.id;
    _scrollController.addListener(_onScroll);
    // Pre-load search index in background
    SearchService.instance.loadIndex();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    showSearchDialog(context);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Ctrl+K or Cmd+K to open search
    final isCtrlOrCmd =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openSearch();
      return KeyEventResult.handled;
    }

    // "/" to open search (when not in a text field)
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
      if (focusedWidget is! EditableText) {
        _openSearch();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onScroll() {
    if (_sectionKeys.isEmpty) return;

    String? newActiveId;
    double closestDistance = double.infinity;

    for (final entry in _sectionKeys.entries) {
      final key = entry.value;
      final context = key.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final position = box.localToGlobal(Offset.zero);
      final distance = position.dy - 100;

      if (distance <= 0 && distance.abs() < closestDistance) {
        closestDistance = distance.abs();
        newActiveId = entry.key;
      } else if (newActiveId == null &&
          distance > 0 &&
          distance < closestDistance) {
        closestDistance = distance;
        newActiveId = entry.key;
      }
    }

    if (newActiveId != null && newActiveId != _activeSectionId) {
      setState(() {
        _activeSectionId = newActiveId;
      });
    }
  }

  void _scrollToSection(String sectionId) {
    final key = _sectionKeys[sectionId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      setState(() {
        _activeSectionId = sectionId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 1200;
    final isMediumScreen = screenWidth >= 768;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: SelectionArea(
        child: Scaffold(
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
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              _SearchButton(onPressed: _openSearch),
              const SizedBox(width: 8),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sidebar (visible on medium+ screens)
              if (isMediumScreen)
                SizedBox(
                  width: 280,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: theme.dividerColor),
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
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideScreen ? 64 : 32,
                    vertical: 32,
                  ),
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
              // Table of contents (visible on wide screens)
              if (isWideScreen)
                SizedBox(
                  width: 240,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: _buildTableOfContents(theme),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableOfContents(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'On this page',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: _sections.map((section) {
              final isActive = section.id == _activeSectionId;

              return Padding(
                padding: EdgeInsets.only(
                  left: (section.level - 2) * 12.0,
                  bottom: 4,
                ),
                child: InkWell(
                  onTap: () => _scrollToSection(section.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? FledgeTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isActive
                              ? FledgeTheme.primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      section.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? FledgeTheme.primaryColor
                            : theme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.7,
                              ),
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
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
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
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
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.8,
                    ),
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
          key: _sectionKeys['try-it-out'],
          'Try It Out',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: const GridGameWidget()),
      ],
    );
  }

  Widget _buildCodeWalkthrough(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: _sectionKeys['how-it-works'],
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
          '6. Connect everything with Flutter (Widget)\n\n'
          'Every listing below is the demo\'s actual source file.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        _buildCodeSection(
          theme,
          sectionId: 'components',
          title: '1. Components',
          description:
              'The first step in designing an ECS game is identifying what data belongs '
              'on individual entities. Ask yourself: "Does each instance of this thing need '
              'its own copy of this data?" If yes, it\'s a component.\n\n'
              '• GridPosition - Every entity on the grid needs its own position. The player '
              'is at (5, 5) while a collectible might be at (2, 7).\n\n'
              '• Player / Collectible / Tile - "Marker components" with no data. They act '
              'like tags: a system can query for "all entities with GridPosition AND Player" '
              'to find only the player.\n\n'
              '• TileColor - Each entity has its own color, so power-ups or damage flashes '
              'can change it without touching the renderer.\n\n'
              'Not components: the grid size, spawn rate and score. They don\'t belong to any '
              'one entity, so they are Resources.',
          source: '$_demoSource/components.dart',
        ),
        const SizedBox(height: 32),
        _buildCodeSection(
          theme,
          sectionId: 'resources',
          title: '2. Resources',
          description:
              'Resources are singletons: exactly one instance, shared by every system. '
              'The question: "Is there only ONE of this in the entire game?"\n\n'
              '• GridConfig - one grid, one size, read by every system that needs it.\n\n'
              '• GameScore - one score, written by the collection system and read by the UI.\n\n'
              '• MoveTimer / SpawnTimer - game-wide timing that keeps its state across frames, '
              'so systems can ask "should I act this frame?" instead of re-implementing '
              'delta-time accumulation.\n\n'
              '• ActionState (from InputPlugin) - the current input, resolved from bindings. '
              'Systems read actions, not keys.',
          source: '$_demoSource/resources.dart',
        ),
        const SizedBox(height: 32),
        _buildCodeSection(
          theme,
          sectionId: 'systems',
          title: '3. Systems and the Plugin',
          description:
              'Systems are where behavior lives, and each does one thing:\n\n'
              '• MovementSystem moves the player from input and clamps it to the grid.\n\n'
              '• SpawnSystem creates collectibles on empty tiles when its timer fires.\n\n'
              '• CollectionSystem picks up collectibles under the player and adds to the score.\n\n'
              'Systems communicate through world state, not calls: MovementSystem updates '
              'GridPosition and CollectionSystem reads it. Each SystemMeta declares what the system '
              'reads and writes, and because movement writes GridPosition that the other two read, '
              'they declare after: [MovementSystem.systemName]. Without that, their order would '
              'fall back to registration order, which App.checkScheduleOrdering() reports.\n\n'
              'All three are synchronous: a system only needs to be async when it truly awaits.\n\n'
              'GridGamePlugin bundles the input bindings, resources, systems and the starting '
              'player entity, so the widget adds one plugin.',
          source: '$_demoSource/systems.dart',
        ),
        const SizedBox(height: 32),
        _buildCodeSection(
          theme,
          sectionId: 'extraction',
          title: '4. Extraction (Two-World Architecture)',
          description:
              'Game state lives in the main world; drawing reads a separate render world that is '
              'cleared and rebuilt every frame. Extractors copy what the painter needs:\n\n'
              '• ExtractedGridEntity - render-ready data with pre-computed pixel positions, so the '
              'painter does no grid math.\n\n'
              '• GridEntityExtractor - queries GridPosition + TileColor in the main world and spawns '
              'ExtractedGridEntity in the render world.\n\n'
              '• GridConfigExtractor / ScoreExtractor - copy the resources the painter and HUD show.\n\n'
              'RenderPlugin provides the Extractors registry and runs every registered extractor in '
              'Schedules.extract, after all game logic in the frame.',
          source: '$_demoSource/extraction.dart',
        ),
        const SizedBox(height: 32),
        _buildCodeSection(
          theme,
          sectionId: 'rendering',
          title: '5. Rendering from the Render World',
          description:
              'The painter only ever sees the render world: it draws ExtractedGridEntity values '
              'and never queries GridPosition, Player or GridConfig.\n\n'
              'shouldRepaint compares a hash of the extracted state, so frames where nothing '
              'changed are not repainted.\n\n'
              'Most games don\'t write a painter: FledgeRenderView draws the sprites that '
              'fledge_render_2d\'s SpriteExtractor extracts. A custom painter like this one is '
              'for drawing that isn\'t sprites.',
          source: '$_demoSource/grid_game_painter.dart',
        ),
        const SizedBox(height: 32),
        _buildCodeSection(
          theme,
          sectionId: 'flutter-integration',
          title: '6. Flutter Integration',
          description:
              'The widget owns the App, registers the extractors, and drives the frame loop '
              'with an AnimationController: each tick runs app.tick() (game logic, then '
              'extraction) and setState() repaints from the render world.\n\n'
              'The loop only runs while the game has focus, so the page stays usable around it. '
              'In a standalone game you would create the App once in main() and pass it in; this '
              'demo builds its own because it is embedded in the docs.',
          source: '$_demoSource/grid_game_widget.dart',
        ),
      ],
    );
  }

  Widget _buildCodeSection(
    ThemeData theme, {
    required String title,
    required String description,
    required String source,
    String? sectionId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: sectionId != null ? _sectionKeys[sectionId] : null,
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
        Text(
          source.replaceFirst('lib/', 'docs/lib/'),
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        FutureBuilder<String>(
          future: _sources[source] ??= rootBundle.loadString(source),
          builder: (context, snapshot) => CodeBlock(
            code: snapshot.data ?? '',
            language: 'dart',
            isDark: theme.brightness == Brightness.dark,
          ),
        ),
      ],
    );
  }

  /// Demo source files, loaded once from the asset bundle.
  static final Map<String, Future<String>> _sources = {};
}

/// Search button with keyboard shortcut hint.
class _SearchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SearchButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 600;

    if (!isWide) {
      // Just show icon on small screens
      return IconButton(
        icon: const Icon(Icons.search_rounded),
        onPressed: onPressed,
        tooltip: 'Search (Ctrl+K)',
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.dividerColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'Search docs...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Ctrl K',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Code snippets for the walkthrough
