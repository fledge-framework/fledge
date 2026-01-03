import 'input_context.dart';
import '../action/input_map.dart';

/// Registry for input contexts, supporting state-based activation.
///
/// Contexts can be registered for specific game states, and the active
/// context is automatically updated when the state changes.
class InputContextRegistry {
  /// All registered contexts by name.
  final Map<String, InputContext> _contexts = {};

  /// Mapping from state type + value to context name.
  final Map<_StateKey, String> _stateContexts = {};

  /// Currently active context name.
  String? _activeContextName;

  /// Manually activated contexts (stack).
  final List<String> _manualStack = [];

  /// Register a context.
  void register(InputContext context) {
    _contexts[context.name] = context;
  }

  /// Register a context that activates for a specific game state.
  void registerForState<S extends Enum>(InputContext context, S state) {
    _contexts[context.name] = context;
    _stateContexts[_StateKey(S, state.index)] = context.name;
  }

  /// Get a registered context by name.
  InputContext? getContext(String name) => _contexts[name];

  /// Get the currently active input map.
  InputMap? get activeMap {
    final name = _activeContextName;
    if (name == null) return null;
    return _contexts[name]?.map;
  }

  /// Get the currently active context.
  InputContext? get activeContext {
    final name = _activeContextName;
    if (name == null) return null;
    return _contexts[name];
  }

  /// Get the name of the currently active context.
  String? get activeContextName => _activeContextName;

  /// Manually activate a context (pushes to stack).
  void push(String contextName) {
    if (_contexts.containsKey(contextName)) {
      _manualStack.add(contextName);
      _updateActive();
    }
  }

  /// Pop the top manual context.
  void pop() {
    if (_manualStack.isNotEmpty) {
      _manualStack.removeLast();
      _updateActive();
    }
  }

  /// Clear all manually pushed contexts.
  void clearManualStack() {
    _manualStack.clear();
    _updateActive();
  }

  /// Update active context based on a game state.
  void updateFromState<S extends Enum>(S state) {
    final contextName = _stateContexts[_StateKey(S, state.index)];
    if (contextName != null && _manualStack.isEmpty) {
      _activeContextName = contextName;
    } else if (_manualStack.isEmpty && contextName == null) {
      // State has no binding, keep current or use default
    }
  }

  void _updateActive() {
    if (_manualStack.isNotEmpty) {
      _activeContextName = _manualStack.last;
    }
  }

  /// Set a default context when no state-specific context matches.
  void setDefault(String contextName) {
    if (_contexts.containsKey(contextName) && _activeContextName == null) {
      _activeContextName = contextName;
    }
  }

  /// Force set the active context (bypasses state binding).
  void setActive(String contextName) {
    if (_contexts.containsKey(contextName)) {
      _activeContextName = contextName;
    }
  }

  /// Get all registered context names.
  Iterable<String> get contextNames => _contexts.keys;
}

/// Internal key for state lookups.
class _StateKey {
  final Type type;
  final int index;

  _StateKey(this.type, this.index);

  @override
  bool operator ==(Object other) =>
      other is _StateKey && other.type == type && other.index == index;

  @override
  int get hashCode => Object.hash(type, index);
}
