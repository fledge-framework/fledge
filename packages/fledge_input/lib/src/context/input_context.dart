import '../action/input_map.dart';

/// An input context that can be activated based on game state.
///
/// Different contexts allow different input mappings for different
/// game states (e.g., menu vs gameplay).
class InputContext {
  /// Unique name for this context.
  final String name;

  /// The input map for this context.
  final InputMap map;

  /// Priority when multiple contexts are active (higher = preferred).
  final int priority;

  const InputContext({
    required this.name,
    required this.map,
    this.priority = 0,
  });

  @override
  String toString() => 'InputContext($name)';
}
