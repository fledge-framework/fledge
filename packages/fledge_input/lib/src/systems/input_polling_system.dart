import 'package:fledge_ecs/fledge_ecs.dart';

import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_state.dart';

/// System that updates raw input state at the start of each frame.
///
/// Runs in the [FirstSets.input] phase of `Schedules.first`.
///
/// Must run before ActionResolutionSystem. Updates the "previous frame"
/// state for justPressed/justReleased detection.
class InputPollingSystem implements System {
  /// The `SystemMeta.name` of [InputPollingSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'inputPolling';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    sets: [FirstSets.input],
    resourceWrites: {KeyboardState, MouseState, GamepadState},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    // Update frame boundaries for button state tracking
    world.getResource<KeyboardState>()?.beginFrame();
    world.getResource<MouseState>()?.beginFrame();
    world.getResource<GamepadState>()?.beginFrame();

    return Future.value();
  }
}
