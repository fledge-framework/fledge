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

  /// The context active when nothing is pushed: the default, the current
  /// state's context, or the last [setActive].
  String? _baseContextName;

  /// Manually activated contexts (stack).
  final List<String> _manualStack = [];

  final List<void Function(InputContext? context)> _listeners = [];

  /// Calls [listener] with the new active context whenever it changes
  /// (`InputPlugin` uses this to keep `CursorState` in step with the
  /// active context's cursor mode).
  void addListener(void Function(InputContext? context) listener) =>
      _listeners.add(listener);

  /// Stops calling [listener].
  void removeListener(void Function(InputContext? context) listener) =>
      _listeners.remove(listener);

  /// Register a context.
  void register(InputContext context) {
    _contexts[context.name] = context;
  }

  /// Register a context that activates for a specific game state.
  void registerForState<S extends Enum>(InputContext context, S state) {
    _contexts[context.name] = context;
    _stateContexts[_StateKey(S, state.index)] = context.name;
  }

  /// Swap the input map of the context called [name], keeping its priority
  /// and cursor mode, e.g. after the player rebinds a key. The new map
  /// applies from the next action resolution. Returns false if there is no
  /// such context.
  bool replaceMap(String name, InputMap map) {
    final old = _contexts[name];
    if (old == null) return false;
    _contexts[name] = InputContext(
      name: old.name,
      map: map,
      priority: old.priority,
      cursorMode: old.cursorMode,
    );
    return true;
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
  ///
  /// The pushed context becomes active unless a context below it (another
  /// pushed one, or the base context) has a higher
  /// [InputContext.priority].
  void push(String contextName) {
    if (_contexts.containsKey(contextName)) {
      _manualStack.add(contextName);
      _updateActive();
    }
  }

  /// Pop the top manual context.
  ///
  /// Popping the last one falls back to the base context: the current
  /// state's context, the default, or the last [setActive].
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
  ///
  /// A state with a bound context makes it the base context; a state with
  /// none keeps the current one.
  void updateFromState<S extends Enum>(S state) {
    final contextName = _stateContexts[_StateKey(S, state.index)];
    if (contextName != null && contextName != _baseContextName) {
      _baseContextName = contextName;
      _updateActive();
    }
  }

  /// Picks the active context among the base context and the pushed ones:
  /// the highest [InputContext.priority] wins, and among equals the most
  /// recently pushed (the base context counts as the oldest).
  void _updateActive() {
    String? best;
    var bestPriority = 0;
    void consider(String? name) {
      if (name == null) return;
      final priority = _contexts[name]?.priority ?? 0;
      if (best == null || priority >= bestPriority) {
        best = name;
        bestPriority = priority;
      }
    }

    consider(_baseContextName);
    _manualStack.forEach(consider);
    _setActiveName(best);
  }

  void _setActiveName(String? name) {
    if (name == _activeContextName) return;
    _activeContextName = name;
    final context = activeContext;
    for (final listener in List.of(_listeners)) {
      listener(context);
    }
  }

  /// Set a default context when no state-specific context matches.
  void setDefault(String contextName) {
    if (_contexts.containsKey(contextName) && _baseContextName == null) {
      _baseContextName = contextName;
      _updateActive();
    }
  }

  /// Make [contextName] the base context (bypasses state binding until the
  /// state's context changes) and activate it now, over anything pushed.
  void setActive(String contextName) {
    if (_contexts.containsKey(contextName)) {
      _baseContextName = contextName;
      _setActiveName(contextName);
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
