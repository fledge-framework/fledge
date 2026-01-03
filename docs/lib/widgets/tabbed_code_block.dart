import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import '../app/theme.dart';

/// A code block widget with tabs to switch between different code versions.
///
/// Typically used to show the same code in different styles:
/// - Inheritance-based (class extends/implements)
/// - Annotation-based (@component, @system)
class TabbedCodeBlock extends StatefulWidget {
  /// The code tabs to display.
  final List<CodeTab> tabs;

  /// The language for syntax highlighting.
  final String language;

  /// Whether to use dark theme.
  final bool isDark;

  const TabbedCodeBlock({
    super.key,
    required this.tabs,
    required this.language,
    this.isDark = true,
  });

  @override
  State<TabbedCodeBlock> createState() => _TabbedCodeBlockState();
}

/// Represents a single tab of code.
class CodeTab {
  /// The label shown on the tab.
  final String label;

  /// The code content for this tab.
  final String code;

  const CodeTab({
    required this.label,
    required this.code,
  });
}

class _TabbedCodeBlockState extends State<TabbedCodeBlock> {
  int _selectedIndex = 0;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderColor = widget.isDark
        ? FledgeTheme.secondaryColor.withValues(alpha: 0.3)
        : const Color(0xFFCBD5E1);
    final headerColor =
        widget.isDark ? FledgeTheme.phantom : const Color(0xFFE2E8F0);
    final codeColor =
        widget.isDark ? FledgeTheme.surfaceDark : const Color(0xFFF8FAFC);
    final mutedColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6);
    const radius = Radius.circular(8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar with tabs and copy button
          Container(
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.only(topLeft: radius, topRight: radius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Tab selector
                _buildTabSelector(theme, mutedColor),
                const Spacer(),
                // Language label
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    widget.language,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Copy button
                InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 14,
                          color: _copied ? Colors.green : mutedColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied!' : 'Copy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _copied ? Colors.green : mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: codeColor,
              borderRadius: const BorderRadius.only(
                  bottomLeft: radius, bottomRight: radius),
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.tabs[_selectedIndex].code,
                language: widget.language,
                theme: _buildCodeTheme(widget.isDark),
                textStyle: FledgeTheme.codeStyle,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(ThemeData theme, Color? mutedColor) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _selectedIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (widget.isDark
                        ? FledgeTheme.primaryColor.withValues(alpha: 0.2)
                        : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tab.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? (widget.isDark
                          ? FledgeTheme.primaryColor
                          : FledgeTheme.primaryColor)
                      : mutedColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.tabs[_selectedIndex].code));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  Map<String, TextStyle> _buildCodeTheme(bool isDark) {
    // Start with the base theme
    final baseTheme = isDark ? atomOneDarkTheme : atomOneLightTheme;

    // Create a copy with transparent background so the container handles it
    final modifiedTheme = Map<String, TextStyle>.from(baseTheme);

    // Override the root style to have transparent background
    if (modifiedTheme.containsKey('root')) {
      modifiedTheme['root'] = modifiedTheme['root']!.copyWith(
        backgroundColor: Colors.transparent,
      );
    }

    return modifiedTheme;
  }
}
