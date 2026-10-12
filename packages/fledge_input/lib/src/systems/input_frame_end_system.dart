import 'package:fledge_ecs/fledge_ecs.dart';

import '../raw/keyboard_state.dart';
import '../raw/mouse_state.dart';
import '../raw/gamepad_state.dart';

/// System that clears input transition flags at the end of each frame.
///
/// Must run AFTER ActionResolutionSystem and any other systems that need
/// to read justPressed/justReleased state.
class InputFrameEndSystem implements System {
  /// The `SystemMeta.name` of [InputFrameEndSystem]. Games that order
  /// their own systems relative to this one use it in `before:` /
  /// `after:`.
  static const String systemName = 'inputFrameEnd';

  @override
  SystemMeta get meta => const SystemMeta(
    name: systemName,
    resourceWrites: {KeyboardState, MouseState, GamepadState},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    // Clear transition flags after all systems have read input
    world.getResource<KeyboardState>()?.endFrame();
    world.getResource<MouseState>()?.endFrame();
    world.getResource<GamepadState>()?.endFrame();

    return Future.value();
  }
}
