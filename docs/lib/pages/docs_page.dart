import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../services/search_service.dart';
import '../widgets/doc_sidebar.dart';
import '../widgets/markdown_content.dart';
import '../widgets/search_dialog.dart';

class DocsPage extends StatefulWidget {
  final String section;
  final String page;

  const DocsPage({
    super.key,
    required this.section,
    required this.page,
  });

  @override
  State<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends State<DocsPage> {
  String? _markdownContent;
  bool _isLoading = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _headingKeys = {};
  String? _activeHeadingId;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadContent();
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
    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openSearch();
      return KeyEventResult.handled;
    }

    // "/" to open search (when not in a text field)
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      // Check if we're not in a text field
      final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
      if (focusedWidget is! EditableText) {
        _openSearch();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(DocsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section || oldWidget.page != widget.page) {
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _headingKeys.clear();
      _activeHeadingId = null;
    });

    try {
      final assetPath = 'assets/docs/${widget.section}/${widget.page}.md';
      final content = await rootBundle.loadString(assetPath);

      // Create GlobalKeys for each heading with unique anchor IDs
      final headings = _extractHeadings(content);
      for (final heading in headings) {
        _headingKeys[heading.anchorId] = GlobalKey();
      }

      setState(() {
        _markdownContent = content;
        _isLoading = false;
        if (headings.isNotEmpty) {
          _activeHeadingId = headings.first.anchorId;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Content not found: ${widget.section}/${widget.page}';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_headingKeys.isEmpty) return;

    // Find which heading is currently visible at the top of the viewport
    String? newActiveId;
    double closestDistance = double.infinity;

    for (final entry in _headingKeys.entries) {
      final key = entry.value;
      final context = key.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final position = box.localToGlobal(Offset.zero);
      final distance = position.dy - 100; // Account for app bar

      // Find the heading closest to the top (but above or at the viewport top)
      if (distance <= 0 && distance.abs() < closestDistance) {
        closestDistance = distance.abs();
        newActiveId = entry.key;
      } else if (newActiveId == null &&
          distance > 0 &&
          distance < closestDistance) {
        // If no heading is above viewport, use the first one below
        closestDistance = distance;
        newActiveId = entry.key;
      }
    }

    if (newActiveId != null && newActiveId != _activeHeadingId) {
      setState(() {
        _activeHeadingId = newActiveId;
      });
    }
  }

  void _scrollToHeading(String anchorId) {
    final key = _headingKeys[anchorId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0, // Align to top
      );
      setState(() {
        _activeHeadingId = anchorId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 1200;
    final isMediumScreen = screenWidth >= 768;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
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
                'Docs',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          actions: [
            // Search button
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
                  currentSection: widget.section,
                  currentPage: widget.page,
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
                      right: BorderSide(
                        color: theme.dividerColor,
                      ),
                    ),
                  ),
                  child: DocSidebar(
                    currentSection: widget.section,
                    currentPage: widget.page,
                  ),
                ),
              ),
            // Main content
            Expanded(
              child: _buildContent(theme, isDark, isWideScreen),
            ),
            // Table of contents (visible on wide screens)
            if (isWideScreen && _markdownContent != null)
              SizedBox(
                width: 240,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.dividerColor,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: _buildTableOfContents(theme),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark, bool isWideScreen) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/docs/getting-started/introduction'),
              child: const Text('Go to Introduction'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isWideScreen ? 64 : 24,
        vertical: 32,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownContent(
              content: _markdownContent!,
              headingKeys: _headingKeys,
            ),
            const SizedBox(height: 64),
            _buildNavigation(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTableOfContents(ThemeData theme) {
    // Extract headings from markdown for TOC
    final headings = _extractHeadings(_markdownContent ?? '');

    if (headings.isEmpty) return const SizedBox.shrink();

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
            children: headings.map((heading) {
              final isActive = heading.anchorId == _activeHeadingId;

              return Padding(
                padding: EdgeInsets.only(
                  left: (heading.level - 2) * 12.0,
                  bottom: 4,
                ),
                child: InkWell(
                  onTap: () => _scrollToHeading(heading.anchorId),
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
                      heading.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? FledgeTheme.primaryColor
                            : theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
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

  List<_Heading> _extractHeadings(String markdown) {
    final headings = <_Heading>[];
    final lines = markdown.split('\n');
    final anchorCounts = <String, int>{};

    for (final line in lines) {
      String? text;
      int? level;

      if (line.startsWith('## ')) {
        text = line.substring(3).trim();
        level = 2;
      } else if (line.startsWith('### ')) {
        text = line.substring(4).trim();
        level = 3;
      }

      if (text != null && level != null) {
        final baseAnchorId = generateAnchorId(text);
        final count = anchorCounts[baseAnchorId] ?? 0;
        anchorCounts[baseAnchorId] = count + 1;

        // Append suffix for duplicates (methods, methods-1, methods-2, etc.)
        final anchorId = count == 0 ? baseAnchorId : '$baseAnchorId-$count';
        headings.add(_Heading(level, text, anchorId));
      }
    }

    return headings;
  }

  Widget _buildNavigation(ThemeData theme) {
    final (prevPage, nextPage) = _findAdjacentPages();

    return Row(
      children: [
        if (prevPage != null)
          Expanded(
            child: _NavButton(
              direction: _NavDirection.previous,
              section: prevPage.$1,
              page: prevPage.$2,
              title: prevPage.$3,
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 16),
        if (nextPage != null)
          Expanded(
            child: _NavButton(
              direction: _NavDirection.next,
              section: nextPage.$1,
              page: nextPage.$2,
              title: nextPage.$3,
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  ((String, String, String)?, (String, String, String)?) _findAdjacentPages() {
    final allPages = <(String, String, String)>[];

    for (final section in DocNavigation.sections) {
      for (final page in section.pages) {
        allPages.add((section.path, page.path, page.title));
      }
    }

    final currentIndex = allPages.indexWhere(
      (p) => p.$1 == widget.section && p.$2 == widget.page,
    );

    if (currentIndex == -1) return (null, null);

    final prev = currentIndex > 0 ? allPages[currentIndex - 1] : null;
    final next =
        currentIndex < allPages.length - 1 ? allPages[currentIndex + 1] : null;

    return (prev, next);
  }
}

class _Heading {
  final int level;
  final String text;
  final String anchorId;

  _Heading(this.level, this.text, this.anchorId);
}

enum _NavDirection { previous, next }

class _NavButton extends StatelessWidget {
  final _NavDirection direction;
  final String section;
  final String page;
  final String title;

  const _NavButton({
    required this.direction,
    required this.section,
    required this.page,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrevious = direction == _NavDirection.previous;

    return InkWell(
      onTap: () => context.go('/docs/$section/$page'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment:
              isPrevious ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isPrevious) ...[
              Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: FledgeTheme.primaryColor,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isPrevious
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    isPrevious ? 'Previous' : 'Next',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: FledgeTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isPrevious) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: FledgeTheme.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
          border: Border.all(
            color: theme.dividerColor,
          ),
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
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
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
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
