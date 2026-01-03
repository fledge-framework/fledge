import 'package:fledge_ecs/fledge_ecs.dart';

import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_state.dart';

/// System that updates raw input state at the start of each frame.
///
/// Must run before ActionResolutionSystem. Updates the "previous frame"
/// state for justPressed/justReleased detection.
class InputPollingSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
        name: 'inputPolling',
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
