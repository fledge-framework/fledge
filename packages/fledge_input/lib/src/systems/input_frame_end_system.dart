import 'package:fledge_ecs/fledge_ecs.dart';

import '../action/action_state.dart';
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
  void run(World world) {
    // Clear transition flags after all systems have read input
    world.getResource<KeyboardState>()?.endFrame();
    world.getResource<MouseState>()?.endFrame();
    world.getResource<GamepadState>()?.endFrame();
  }
}

/// Drops every press and release that arrived since the last frame ended,
/// for when the world wasn't ticking (a paused game behind a menu): key
/// events keep reaching the raw input states while no frame ends to clear
/// them, so the first tick after resuming would otherwise see a key pressed
/// on the menu as just pressed in the game. Buttons still held stay held
/// (never "just pressed"); presses waiting for a fixed step are dropped too.
///
/// Call it when the world starts ticking again, before that tick.
void discardPendingInput(World world) {
  world.getResource<KeyboardState>()?.endFrame();
  world.getResource<MouseState>()?.endFrame();
  world.getResource<GamepadState>()?.endFrame();
  world.getResource<ActionState>()
    ?..clear()
    ..clearFixedLatch();
}
