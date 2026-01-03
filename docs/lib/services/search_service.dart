import 'package:flutter/services.dart';

import '../app/router.dart';

/// A search result from the documentation.
class SearchResult {
  /// Section path (e.g., 'guides', 'api').
  final String section;

  /// Page path (e.g., 'systems', 'entity').
  final String page;

  /// Page title.
  final String title;

  /// Section title.
  final String sectionTitle;

  /// Snippet of text containing the match.
  final String snippet;

  /// The matched text (for highlighting).
  final String matchedText;

  /// Relevance score (higher is better).
  final int score;

  const SearchResult({
    required this.section,
    required this.page,
    required this.title,
    required this.sectionTitle,
    required this.snippet,
    required this.matchedText,
    required this.score,
  });

  /// URL path for navigation.
  String get path => '/docs/$section/$page';
}

/// Indexed document for search.
class _IndexedDoc {
  final String section;
  final String sectionTitle;
  final String page;
  final String title;
  final String content;
  final String contentLower;

  _IndexedDoc({
    required this.section,
    required this.sectionTitle,
    required this.page,
    required this.title,
    required this.content,
  }) : contentLower = content.toLowerCase();
}

/// Service for searching documentation content.
class SearchService {
  static SearchService? _instance;

  final List<_IndexedDoc> _index = [];
  bool _isLoaded = false;
  bool _isLoading = false;

  SearchService._();

  /// Get the singleton instance.
  static SearchService get instance {
    _instance ??= SearchService._();
    return _instance!;
  }

  /// Whether the search index is loaded.
  bool get isLoaded => _isLoaded;

  /// Load and index all documentation content.
  Future<void> loadIndex() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;

    try {
      for (final section in DocNavigation.sections) {
        // Skip demos section
        if (section.path == 'demos') continue;

        for (final page in section.pages) {
          try {
            final assetPath = 'assets/docs/${section.path}/${page.path}.md';
            final content = await rootBundle.loadString(assetPath);

            _index.add(_IndexedDoc(
              section: section.path,
              sectionTitle: section.title,
              page: page.path,
              title: page.title,
              content: _stripMarkdown(content),
            ));
          } catch (e) {
            // Skip missing files
          }
        }
      }
      _isLoaded = true;
    } finally {
      _isLoading = false;
    }
  }

  /// Search the documentation for the given query.
  ///
  /// Returns a list of results sorted by relevance.
  List<SearchResult> search(String query) {
    if (!_isLoaded || query.trim().isEmpty) return [];

    final queryLower = query.toLowerCase().trim();
    final queryWords = queryLower.split(RegExp(r'\s+'));
    final results = <SearchResult>[];

    for (final doc in _index) {
      int score = 0;
      String? bestSnippet;
      String? matchedText;

      // Title match (highest priority)
      if (doc.title.toLowerCase().contains(queryLower)) {
        score += 100;
        matchedText = query;
      }

      // Check each word
      for (final word in queryWords) {
        if (word.length < 2) continue;

        // Title word match
        if (doc.title.toLowerCase().contains(word)) {
          score += 50;
        }

        // Content match
        final contentIndex = doc.contentLower.indexOf(word);
        if (contentIndex != -1) {
          score += 10;

          // Extract snippet around the match
          if (bestSnippet == null) {
            bestSnippet = _extractSnippet(doc.content, contentIndex, word.length);
            matchedText = word;
          }
        }
      }

      // Full phrase match in content (bonus)
      if (doc.contentLower.contains(queryLower)) {
        score += 30;
        final phraseIndex = doc.contentLower.indexOf(queryLower);
        bestSnippet = _extractSnippet(doc.content, phraseIndex, queryLower.length);
        matchedText = query;
      }

      if (score > 0) {
        results.add(SearchResult(
          section: doc.section,
          page: doc.page,
          title: doc.title,
          sectionTitle: doc.sectionTitle,
          snippet: bestSnippet ?? _extractSnippet(doc.content, 0, 0),
          matchedText: matchedText ?? query,
          score: score,
        ));
      }
    }

    // Sort by score (descending)
    results.sort((a, b) => b.score.compareTo(a.score));

    // Limit results
    return results.take(20).toList();
  }

  /// Strip markdown formatting for plain text search.
  String _stripMarkdown(String markdown) {
    return markdown
        // Remove code blocks
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        // Remove inline code
        .replaceAll(RegExp(r'`[^`]+`'), ' ')
        // Remove headers markers
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        // Remove links but keep text
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        // Remove bold/italic
        .replaceAll(RegExp(r'\*+([^*]+)\*+'), r'$1')
        .replaceAll(RegExp(r'_+([^_]+)_+'), r'$1')
        // Remove images
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        // Remove table formatting
        .replaceAll(RegExp(r'\|'), ' ')
        .replaceAll(RegExp(r'-{3,}'), ' ')
        // Collapse whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extract a snippet of text around a match position.
  String _extractSnippet(String content, int matchIndex, int matchLength) {
    const snippetRadius = 80;

    int start = matchIndex - snippetRadius;
    int end = matchIndex + matchLength + snippetRadius;

    // Adjust bounds
    if (start < 0) start = 0;
    if (end > content.length) end = content.length;

    // Try to start/end at word boundaries
    if (start > 0) {
      final spaceIndex = content.indexOf(' ', start);
      if (spaceIndex != -1 && spaceIndex < matchIndex) {
        start = spaceIndex + 1;
      }
    }
    if (end < content.length) {
      final spaceIndex = content.lastIndexOf(' ', end);
      if (spaceIndex != -1 && spaceIndex > matchIndex + matchLength) {
        end = spaceIndex;
      }
    }

    String snippet = content.substring(start, end).trim();

    // Add ellipsis
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';

    return snippet;
  }
}
