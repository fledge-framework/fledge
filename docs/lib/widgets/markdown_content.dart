import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import 'code_block.dart';
import 'tabbed_code_block.dart';

/// Generates a URL-friendly anchor ID from heading text.
/// "My Heading" → "my-heading"
/// "Rendering Animated Tiles" → "rendering-animated-tiles"
String generateAnchorId(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
      .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
      .replaceAll(RegExp(r'-+'), '-') // Collapse multiple hyphens
      .replaceAll(RegExp(r'^-|-$'), ''); // Trim leading/trailing hyphens
}

class MarkdownContent extends StatelessWidget {
  final String content;

  /// Map of anchor IDs to GlobalKeys for scroll targeting.
  /// If provided, headings will be wrapped with these keys.
  final Map<String, GlobalKey>? headingKeys;

  const MarkdownContent({
    super.key,
    required this.content,
    this.headingKeys,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: _buildStyleSheet(theme, isDark),
      builders: {
        'code': CodeBlockBuilder(isDark: isDark),
        'h2': HeadingBuilder(headingKeys: headingKeys, level: 2),
        'h3': HeadingBuilder(headingKeys: headingKeys, level: 3),
      },
      onTapLink: (text, href, title) {
        if (href != null) {
          _handleLink(context, href);
        }
      },
    );
  }

  void _handleLink(BuildContext context, String href) {
    // Check if this is an internal link
    if (href.startsWith('/docs/') || href.startsWith('/demo/')) {
      // Use GoRouter for internal navigation
      context.go(href);
    } else if (href.startsWith('/')) {
      // Other internal paths
      context.go(href);
    } else {
      // External link - use url_launcher
      _launchUrl(href);
    }
  }

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme, bool isDark) {
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;

    return MarkdownStyleSheet(
      h1: theme.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h1Padding: const EdgeInsets.only(top: 8, bottom: 16),
      h2: theme.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h2Padding: const EdgeInsets.only(top: 32, bottom: 12),
      h3: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h3Padding: const EdgeInsets.only(top: 24, bottom: 8),
      h4: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h4Padding: const EdgeInsets.only(top: 20, bottom: 8),
      p: theme.textTheme.bodyLarge?.copyWith(
        height: 1.7,
      ),
      pPadding: const EdgeInsets.only(bottom: 12),
      listBullet: theme.textTheme.bodyLarge,
      a: TextStyle(
        color: FledgeTheme.primaryColor,
        decoration: TextDecoration.underline,
        decorationColor: FledgeTheme.primaryColor.withValues(alpha: 0.5),
      ),
      blockquote: theme.textTheme.bodyLarge?.copyWith(
        fontStyle: FontStyle.italic,
        color: textColor.withValues(alpha: 0.8),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: FledgeTheme.primaryColor,
            width: 4,
          ),
        ),
        color: FledgeTheme.primaryColor.withValues(alpha: 0.05),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      code: FledgeTheme.codeStyle.copyWith(
        backgroundColor:
            isDark ? FledgeTheme.surfaceDark2 : Colors.grey.shade100,
        color: FledgeTheme.purpleLight,
      ),
      codeblockDecoration: const BoxDecoration(),
      codeblockPadding: EdgeInsets.zero,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      tableHead: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      tableBody: theme.textTheme.bodyMedium,
      tableBorder: TableBorder.all(
        color: theme.dividerColor,
        width: 1,
      ),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.all(8),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isDark;

  CodeBlockBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String code = element.textContent.trim();

    // Detect language from the code block
    String? language;
    bool isTabbedBlock = false;
    if (element.attributes.containsKey('class')) {
      final className = element.attributes['class'] ?? '';
      if (className.startsWith('language-')) {
        language = className.substring(9);
        // Check for "tabs" modifier (e.g., "dart-tabs" or "dart tabs")
        if (language.endsWith('-tabs')) {
          language = language.substring(0, language.length - 5);
          isTabbedBlock = true;
        }
      }
    }

    // Only use highlighting for fenced code blocks with language
    if (language != null && language.isNotEmpty) {
      // Check if this is a tabbed code block
      if (isTabbedBlock) {
        final tabs = _parseTabbedCode(code);
        if (tabs.isNotEmpty) {
          return TabbedCodeBlock(
            tabs: tabs,
            language: language,
            isDark: isDark,
          );
        }
      }

      return CodeBlock(
        code: code,
        language: language,
        isDark: isDark,
      );
    }

    return null; // Use default styling for inline code
  }

  /// Parses tabbed code block content into separate tabs.
  ///
  /// Format:
  /// ```dart-tabs
  /// // @tab Annotations
  /// code here...
  /// // @tab Classes
  /// more code...
  /// ```
  List<CodeTab> _parseTabbedCode(String code) {
    final tabs = <CodeTab>[];
    final lines = code.split('\n');

    String? currentTabLabel;
    final currentTabCode = StringBuffer();

    for (final line in lines) {
      // Check for tab marker: "// @tab TabName"
      final tabMatch = RegExp(r'^//\s*@tab\s+(.+)$').firstMatch(line.trim());
      if (tabMatch != null) {
        // Save previous tab if exists
        if (currentTabLabel != null) {
          tabs.add(CodeTab(
            label: currentTabLabel,
            code: currentTabCode.toString().trim(),
          ));
        }
        // Start new tab
        currentTabLabel = tabMatch.group(1)!.trim();
        currentTabCode.clear();
      } else if (currentTabLabel != null) {
        // Add line to current tab
        if (currentTabCode.isNotEmpty) {
          currentTabCode.writeln();
        }
        currentTabCode.write(line);
      }
    }

    // Save the last tab
    if (currentTabLabel != null && currentTabCode.isNotEmpty) {
      tabs.add(CodeTab(
        label: currentTabLabel,
        code: currentTabCode.toString().trim(),
      ));
    }

    return tabs;
  }
}

/// Custom heading builder that wraps headings with GlobalKeys for scroll targeting.
class HeadingBuilder extends MarkdownElementBuilder {
  final Map<String, GlobalKey>? headingKeys;
  final int level;

  /// Tracks how many times each base anchor ID has been seen.
  final Map<String, int> _anchorCounts = {};

  HeadingBuilder({this.headingKeys, required this.level});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent.trim();
    final baseAnchorId = generateAnchorId(text);

    // Track duplicates to generate matching anchor IDs
    final count = _anchorCounts[baseAnchorId] ?? 0;
    _anchorCounts[baseAnchorId] = count + 1;
    final anchorId = count == 0 ? baseAnchorId : '$baseAnchorId-$count';

    final key = headingKeys?[anchorId];

    // Build the heading text with optional key for scroll targeting
    if (key != null) {
      return SizedBox(
        key: key,
        width: double.infinity,
        child: Text(text, style: preferredStyle),
      );
    }

    // Return null to use default rendering if no key
    return null;
  }
}
