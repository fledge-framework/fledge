import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../app/theme.dart';

class DocSidebar extends StatelessWidget {
  final String currentSection;
  final String currentPage;
  final VoidCallback? onClose;

  const DocSidebar({
    super.key,
    required this.currentSection,
    required this.currentPage,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          if (onClose != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Documentation',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: DocNavigation.sections.map((section) {
                return _SectionItem(
                  section: section,
                  isCurrentSection: section.path == currentSection,
                  currentPage: currentPage,
                  onClose: onClose,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionItem extends StatefulWidget {
  final NavSection section;
  final bool isCurrentSection;
  final String currentPage;
  final VoidCallback? onClose;

  const _SectionItem({
    required this.section,
    required this.isCurrentSection,
    required this.currentPage,
    this.onClose,
  });

  @override
  State<_SectionItem> createState() => _SectionItemState();
}

class _SectionItemState extends State<_SectionItem> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isCurrentSection;
  }

  @override
  void didUpdateWidget(_SectionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentSection && !oldWidget.isCurrentSection) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.section.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.isCurrentSection
                          ? FledgeTheme.primaryColor
                          : null,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: widget.section.pages.map((page) {
                final isActive = widget.isCurrentSection &&
                    page.path == widget.currentPage;

                return _PageItem(
                  page: page,
                  sectionPath: widget.section.path,
                  isActive: isActive,
                  onClose: widget.onClose,
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PageItem extends StatelessWidget {
  final NavPage page;
  final String sectionPath;
  final bool isActive;
  final VoidCallback? onClose;

  const _PageItem({
    required this.page,
    required this.sectionPath,
    required this.isActive,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        // Handle demos section with special path
        if (sectionPath == 'demos') {
          context.go('/demo/${page.path}');
        } else {
          context.go('/docs/$sectionPath/${page.path}');
        }
        onClose?.call();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? FledgeTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border(
                  left: BorderSide(
                    color: FledgeTheme.primaryColor,
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Text(
          page.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isActive
                ? FledgeTheme.primaryColor
                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
