/// Game state machine for tracking application states.
///
/// States allow you to organize systems by application phase (menu, playing,
/// paused, etc.) and run specific systems only when in certain states.
///
/// ```dart
/// enum GameState { menu, playing, paused }
///
/// // Create a state and add it to the app
/// app.addState<GameState>(GameState.menu);
///
/// // Add systems that only run in specific states
/// app.addSystemInState(movementSystem, GameState.playing);
/// ```
library;

export 'state_machine.dart';
export 'state_conditions.dart';
