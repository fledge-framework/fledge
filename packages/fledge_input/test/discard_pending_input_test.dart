import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _use = ActionId('use');

void main() {
  test('input that arrived while the world was paused is dropped, held '
      'keys stay held', () {
    final world = World()
      ..insertResource(KeyboardState())
      ..insertResource(MouseState())
      ..insertResource(GamepadState())
      ..insertResource(
        ActionState()..set(_use, const ButtonValue(ButtonPhase.justPressed)),
      );
    final keys = world.getResource<KeyboardState>()!;
    // On the menu, with no frames ending: E tapped, Shift pressed and held.
    keys
      ..keyDown(LogicalKeyboardKey.keyE)
      ..keyUp(LogicalKeyboardKey.keyE)
      ..keyDown(LogicalKeyboardKey.shiftLeft);
    expect(keys.justPressed(LogicalKeyboardKey.keyE), isTrue);

    discardPendingInput(world);

    expect(keys.justPressed(LogicalKeyboardKey.keyE), isFalse);
    expect(keys.justReleased(LogicalKeyboardKey.keyE), isFalse);
    expect(keys.isPressed(LogicalKeyboardKey.shiftLeft), isTrue);
    expect(keys.justPressed(LogicalKeyboardKey.shiftLeft), isFalse);
    final actions = world.getResource<ActionState>()!;
    expect(actions.justPressed(_use), isFalse);
    expect(actions.fixedJustPressed(_use), isFalse);
  });
}
