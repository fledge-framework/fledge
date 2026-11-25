import '../action/input_map.dart';
import '../cursor/cursor_mode.dart';

/// An input context that can be activated based on game state.
///
/// Different contexts allow different input mappings for different
/// game states (e.g., menu vs gameplay).
class InputContext {
  /// Unique name for this context.
  final String name;

  /// The input map for this context.
  final InputMap map;

  /// Priority among the contexts that could be active: the base context
  /// (default, state-bound or set with `setActive`) and every pushed one.
  /// The highest wins; among equals, the most recently pushed. A
  /// high-priority context (a cutscene, say) stays active when a
  /// lower-priority one is pushed over it.
  final int priority;

  /// Cursor mode when this context is active.
  ///
  /// - [CursorMode.visible]: Normal cursor for menus/UI
  /// - [CursorMode.hidden]: Hidden cursor but tracks position
  /// - [CursorMode.locked]: Hidden cursor with relative movement (FPS games)
  final CursorMode cursorMode;

  const InputContext({
    required this.name,
    required this.map,
    this.priority = 0,
    this.cursorMode = CursorMode.visible,
  });

  @override
  String toString() => 'InputContext($name, cursor: $cursorMode)';
}
