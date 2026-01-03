/// A state machine for tracking game/application state.
///
/// [State] manages transitions between enum values and provides
/// information about recent transitions for systems that respond
/// to state changes.
///
/// ```dart
/// enum GameState { menu, playing, paused }
///
/// final state = State<GameState>(GameState.menu);
///
/// // Check current state
/// if (state.current == GameState.playing) { ... }
///
/// // Request a transition
/// state.set(GameState.paused);
///
/// // Apply the transition (usually done by the framework)
/// state.applyTransition();
/// ```
class State<S extends Enum> {
  /// The current state value.
  S _current;

  /// The next state to transition to, if any.
  S? _next;

  /// True if the current state was just entered this frame.
  bool _justEntered = true;

  /// True if the current state is about to be exited this frame.
  bool _justExited = false;

  /// Creates a state machine with the given initial state.
  State(this._current);

  /// The current state value.
  S get current => _current;

  /// Returns true if currently in the given state.
  bool isIn(S state) => _current == state;

  /// Returns true if a transition is pending.
  bool get isPending => _next != null;

  /// Returns true if the current state was just entered this frame.
  ///
  /// This is useful for one-time initialization when entering a state.
  bool get justEntered => _justEntered;

  /// Returns true if the current state is about to exit.
  ///
  /// This is useful for cleanup before leaving a state.
  bool get justExited => _justExited;

  /// Returns true if the state was just entered AND it matches the given state.
  bool justEnteredState(S state) => _justEntered && _current == state;

  /// Returns true if the state is about to exit AND it matches the given state.
  bool justExitedState(S state) => _justExited && _current == state;

  /// Requests a transition to a new state.
  ///
  /// The transition will be applied on the next call to [applyTransition],
  /// typically at the end of the frame.
  ///
  /// If a transition is already pending, this replaces it.
  void set(S newState) {
    if (newState != _current) {
      _next = newState;
    }
  }

  /// Clears any pending transition.
  void cancelTransition() {
    _next = null;
  }

  /// Applies any pending state transition.
  ///
  /// This should be called once per frame, typically at the start or end
  /// of the frame. It updates the [justEntered] and [justExited] flags
  /// appropriately.
  void applyTransition() {
    // Clear previous frame's flags
    _justEntered = false;
    _justExited = false;

    // Apply pending transition
    if (_next != null) {
      _justExited = true;
      _current = _next!;
      _next = null;
      _justEntered = true;
    }
  }

  /// Resets the just entered/exited flags without applying a transition.
  ///
  /// This is called internally to clear flags after systems have processed them.
  void clearFlags() {
    _justEntered = false;
    _justExited = false;
  }

  @override
  String toString() => 'State<$S>(current: $_current, pending: $_next)';
}

/// Registry for managing multiple state machines by type.
///
/// This is used internally by the App to store state machines for
/// different enum types.
class StateRegistry {
  final Map<Type, Object> _states = {};

  /// Adds a state machine for the given enum type.
  void add<S extends Enum>(State<S> state) {
    _states[S] = state;
  }

  /// Gets the state machine for the given enum type.
  ///
  /// Returns null if no state machine exists for this type.
  State<S>? get<S extends Enum>() {
    return _states[S] as State<S>?;
  }

  /// Returns true if a state machine exists for the given enum type.
  bool contains<S extends Enum>() {
    return _states.containsKey(S);
  }

  /// Applies transitions for all registered state machines.
  void applyTransitions() {
    for (final state in _states.values) {
      (state as State).applyTransition();
    }
  }

  /// Clears flags for all registered state machines.
  void clearFlags() {
    for (final state in _states.values) {
      (state as State).clearFlags();
    }
  }

  /// The number of registered state machines.
  int get length => _states.length;
}
