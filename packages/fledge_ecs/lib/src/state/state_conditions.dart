import '../system/run_condition.dart';
import '../world.dart';
import 'state_machine.dart';

/// Run condition that returns true when in the specified state.
///
/// ```dart
/// final system = FunctionSystem(
///   'movement',
///   runIf: InState<GameState>(GameState.playing).condition,
///   run: (world) { /* ... */ },
/// );
/// ```
class InState<S extends Enum> {
  /// The state value to check for.
  final S state;

  /// Creates a condition that checks for the given state.
  const InState(this.state);

  /// The run condition that can be passed to a system.
  RunCondition get condition => (world) {
        final stateResource = world.getResource<State<S>>();
        return stateResource?.isIn(state) ?? false;
      };
}

/// Run condition that returns true when just entering the specified state.
///
/// This is useful for one-time initialization when entering a state.
///
/// ```dart
/// final system = FunctionSystem(
///   'initPlayState',
///   runIf: OnEnterState<GameState>(GameState.playing).condition,
///   run: (world) {
///     // Initialize game state
///   },
/// );
/// ```
class OnEnterState<S extends Enum> {
  /// The state value to check for.
  final S state;

  /// Creates a condition that triggers when entering the given state.
  const OnEnterState(this.state);

  /// The run condition that can be passed to a system.
  RunCondition get condition => (world) {
        final stateResource = world.getResource<State<S>>();
        return stateResource?.justEnteredState(state) ?? false;
      };
}

/// Run condition that returns true when just exiting the specified state.
///
/// This is useful for cleanup when leaving a state.
///
/// ```dart
/// final system = FunctionSystem(
///   'cleanupPlayState',
///   runIf: OnExitState<GameState>(GameState.playing).condition,
///   run: (world) {
///     // Cleanup game state
///   },
/// );
/// ```
class OnExitState<S extends Enum> {
  /// The state value to check for.
  final S state;

  /// Creates a condition that triggers when exiting the given state.
  const OnExitState(this.state);

  /// The run condition that can be passed to a system.
  RunCondition get condition => (world) {
        final stateResource = world.getResource<State<S>>();
        return stateResource?.justExitedState(state) ?? false;
      };
}

/// Helper class for creating state-related run conditions.
///
/// Provides convenient factory methods for common state conditions.
class StateConditions {
  StateConditions._();

  /// Creates a condition that returns true when in any of the given states.
  static RunCondition inAny<S extends Enum>(List<S> states) {
    return (world) {
      final stateResource = world.getResource<State<S>>();
      if (stateResource == null) return false;
      return states.contains(stateResource.current);
    };
  }

  /// Creates a condition that returns true when NOT in the given state.
  static RunCondition notIn<S extends Enum>(S state) {
    return (world) {
      final stateResource = world.getResource<State<S>>();
      return stateResource != null && !stateResource.isIn(state);
    };
  }

  /// Creates a condition that returns true when a state transition is pending.
  static RunCondition transitionPending<S extends Enum>() {
    return (world) {
      final stateResource = world.getResource<State<S>>();
      return stateResource?.isPending ?? false;
    };
  }
}

/// Extension on World for convenient state access.
extension WorldStateExtension on World {
  /// Gets the current value of a state.
  ///
  /// Returns null if the state type is not registered.
  S? getState<S extends Enum>() {
    return getResource<State<S>>()?.current;
  }

  /// Sets the next state value, triggering a transition.
  ///
  /// The transition will be applied on the next frame.
  void setState<S extends Enum>(S state) {
    getResource<State<S>>()?.set(state);
  }

  /// Returns true if currently in the given state.
  bool isInState<S extends Enum>(S state) {
    return getResource<State<S>>()?.isIn(state) ?? false;
  }
}
