import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BindingSource JSON', () {
    const sources = <BindingSource>[
      KeyboardBinding(LogicalKeyboardKey.keyE),
      KeyboardBinding(LogicalKeyboardKey.shiftLeft),
      MouseButtonBinding.right,
      MouseAxisBinding(MouseAxis.scrollY),
      MouseScrollBinding.down,
      GamepadButtonBinding.leftBumper,
      GamepadButtonBinding('a', gamepadId: 'pad-2'),
      GamepadAxisBinding('left_stick_y', inverted: true),
      GamepadStickBinding.left,
      GamepadStickBinding(GamepadStick.right, gamepadId: 'pad-2'),
    ];

    test('every source round-trips', () {
      for (final source in sources) {
        expect(BindingSource.fromJson(source.toJson()), source);
      }
    });

    test('unknown or malformed entries read as null', () {
      expect(BindingSource.fromJson({'type': 'telepathy'}), isNull);
      expect(BindingSource.fromJson({'type': 'key'}), isNull);
      expect(
        BindingSource.fromJson({'type': 'scroll', 'direction': 'inward'}),
        isNull,
      );
      expect(
        BindingSource.fromJson({'type': 'gamepad_stick', 'stick': 'middle'}),
        isNull,
      );
    });
  });

  group('rebinding', () {
    const use = ActionId('use');
    const move = ActionId('move');

    test('bind and bindComposite take any source', () {
      final map = InputMap.builder()
          .bind(const KeyboardBinding(LogicalKeyboardKey.keyF), use)
          .bindComposite(
            move,
            up: const KeyboardBinding(LogicalKeyboardKey.keyI),
            down: const KeyboardBinding(LogicalKeyboardKey.keyK),
            left: const KeyboardBinding(LogicalKeyboardKey.keyJ),
            right: const KeyboardBinding(LogicalKeyboardKey.keyL),
          )
          .build();
      expect(map.actionTypes[use], ActionType.button);
      expect(map.actionTypes[move], ActionType.vector2);
      expect(
        map.compositeBindings.single.up,
        const KeyboardBinding(LogicalKeyboardKey.keyI),
      );
    });

    test('replaceMap swaps a context\'s map and the next frame uses it', () {
      final app = App()
        ..addPlugin(
          InputPlugin.simple(
            context: InputContext(
              name: 'play',
              map: InputMap.builder()
                  .bindKey(LogicalKeyboardKey.keyE, use)
                  .build(),
              cursorMode: CursorMode.hidden,
            ),
            enableGamepad: false,
          ),
        );
      final world = app.world;
      final registry = world.getResource<InputContextRegistry>()!;
      expect(
        registry.replaceMap(
          'play',
          InputMap.builder().bindKey(LogicalKeyboardKey.keyF, use).build(),
        ),
        isTrue,
      );
      expect(registry.replaceMap('missing', const InputMap()), isFalse);
      expect(registry.activeContext!.cursorMode, CursorMode.hidden);
      expect(
        registry.activeMap!.bindings.single.source,
        const KeyboardBinding(LogicalKeyboardKey.keyF),
      );
    });
  });
}
