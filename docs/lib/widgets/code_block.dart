import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import '../app/theme.dart';

/// A styled code block widget with language header and copy button.
class CodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final bool isDark;

  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.isDark = true,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
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
    final mutedColor =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6);
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
          // Header bar with language and copy button
          Container(
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.only(topLeft: radius, topRight: radius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.language,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
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
                widget.code,
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

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
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
