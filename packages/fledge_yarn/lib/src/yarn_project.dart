import 'yarn_node.dart';
import 'yarn_parser.dart';

/// A collection of parsed Yarn nodes.
///
/// A project can contain multiple nodes loaded from one or more `.yarn` files.
/// Use [parse] to add content and [getNode] to retrieve nodes by title.
///
/// Example:
/// ```dart
/// final project = YarnProject();
/// project.parse(await rootBundle.loadString('assets/dialogue/sara.yarn'));
/// project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));
///
/// final node = project.getNode('sara_greeting');
/// ```
class YarnProject {
  final Map<String, YarnNode> _nodes = {};

  /// All node titles in this project.
  Iterable<String> get nodeNames => _nodes.keys;

  /// Number of nodes in this project.
  int get nodeCount => _nodes.length;

  /// Parse Yarn content and add nodes to this project.
  ///
  /// Can be called multiple times to combine content from multiple files.
  /// If a node with the same title already exists, it will be overwritten.
  ///
  /// Returns the list of node titles that were added/updated.
  List<String> parse(String content) {
    final parser = YarnParser();
    final nodes = parser.parse(content);
    final titles = <String>[];

    for (final node in nodes) {
      _nodes[node.title] = node;
      titles.add(node.title);
    }

    return titles;
  }

  /// Get a node by its title.
  ///
  /// Returns null if no node with that title exists.
  YarnNode? getNode(String title) => _nodes[title];

  /// Check if a node exists.
  bool hasNode(String title) => _nodes.containsKey(title);

  /// Remove a node by title.
  ///
  /// Returns the removed node, or null if it didn't exist.
  YarnNode? removeNode(String title) => _nodes.remove(title);

  /// Clear all nodes from this project.
  void clear() => _nodes.clear();

  /// Get all nodes with a specific tag.
  List<YarnNode> getNodesWithTag(String tag) {
    return _nodes.values.where((n) => n.hasTag(tag)).toList();
  }
}
