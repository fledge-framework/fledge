import 'yarn_line.dart';

/// A single node in a Yarn dialogue.
///
/// Nodes are the basic unit of organization in Yarn. Each node has a title
/// and contains a sequence of lines (dialogue, choices, commands, etc.).
///
/// Example:
/// ```yarn
/// title: greeting
/// tags: start important
/// ---
/// Sara: Hello there!
/// Sara: How can I help you today?
/// ===
/// ```
class YarnNode {
  /// The unique title/identifier of this node.
  final String title;

  /// Optional tags for categorization and metadata.
  final List<String> tags;

  /// Custom headers defined in the node (key-value pairs).
  final Map<String, String> headers;

  /// The lines of content in this node.
  final List<YarnLine> lines;

  const YarnNode({
    required this.title,
    this.tags = const [],
    this.headers = const {},
    this.lines = const [],
  });

  /// Whether this node has a specific tag.
  bool hasTag(String tag) => tags.contains(tag);

  /// Get a header value by key.
  String? getHeader(String key) => headers[key];

  @override
  String toString() => 'YarnNode($title, ${lines.length} lines)';
}
