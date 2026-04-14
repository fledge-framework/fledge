import 'package:drifter_example/game_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../services/search_service.dart';
import '../widgets/doc_sidebar.dart';
import '../widgets/search_dialog.dart';

/// Interactive Drifter demo page.
///
/// Lighter than `DemoPage` — no code walkthrough, just the embedded game
/// plus a pointer to `examples/drifter/` in the repo for people who want
/// the full source.
class DrifterPage extends StatefulWidget {
  const DrifterPage({super.key});

  @override
  State<DrifterPage> createState() => _DrifterPageState();
}

class _DrifterPageState extends State<DrifterPage> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SearchService.instance.loadIndex();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() => showSearchDialog(context);

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openSearch();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      final focused = FocusManager.instance.primaryFocus?.context?.widget;
      if (focused is! EditableText) {
        _openSearch();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMediumScreen = screenWidth >= 768;
    final isWideScreen = screenWidth >= 1200;

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
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _openSearch,
                tooltip: 'Search (Ctrl+K)',
              ),
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
                    currentPage: 'drifter',
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      currentPage: 'drifter',
                    ),
                  ),
                ),
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
                          const SizedBox(height: 32),
                          _buildWhatItShows(theme),
                          const SizedBox(height: 24),
                          _buildSourceLink(theme),
                          const SizedBox(height: 64),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Drifter',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'An end-to-end vertical slice integrating ECS, render, input, '
          'physics, and save',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Move the green square with the arrow keys or WASD. Touch a gold '
          "pickup to collect it — your run score goes up, and if it's the "
          'best you\'ve ever done this session, the high score follows. '
          'Walls stop you from clipping through the room.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'This is the reference for how the Fledge packages compose in a '
          'real Flutter app — every package-level feature the docs ship '
          'individually has to actually play well with the others, and this '
          'demo is where that gets proved end-to-end.',
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
                  'Web-specific caveats',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Save and load (S/L keys) silently no-op in the browser — '
                  '`fledge_save` writes to the filesystem via `path_provider`, '
                  'which is desktop-only. Everything else (movement, '
                  'collision, high score in memory, pause-on-blur) runs '
                  'normally on the web.',
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
        const Center(child: DrifterWidget()),
      ],
    );
  }

  Widget _buildWhatItShows(ThemeData theme) {
    final rows = <(String, String)>[
      (
        'fledge_ecs',
        'App + World, resources, stage ordering, marker components'
      ),
      ('fledge_render_2d', 'Transform2D, TransformPropagateSystem'),
      ('fledge_render', 'RenderPlugin + extractors to a render world'),
      (
        'fledge_input',
        'InputWidget with caller-owned FocusNode, pause-on-blur, arrow/WASD actions'
      ),
      (
        'fledge_physics + fledge_tiled',
        'Velocity, Colliders with layer bits, sensor pickups, CollisionEvents'
      ),
      (
        'fledge_save',
        'HighScore auto-discovered as a Saveable world resource (desktop only)'
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this demo exercises',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            for (final (pkg, desc) in rows)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
                  child: Text(
                    pkg,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: FledgeTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(desc, style: theme.textTheme.bodyMedium),
                ),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceLink(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Full source',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All of this — the scene setup, systems, extraction, render, '
            'and widget host — lives in `examples/drifter/` in the Fledge '
            'repository. ~500 LOC across nine files, plus a README '
            'documenting every integration gotcha that bit during the build.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
