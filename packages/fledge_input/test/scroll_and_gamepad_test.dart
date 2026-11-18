import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

const _next = ActionId('next');
const _prev = ActionId('prev');

/// A world with raw input, an [ActionState] and [map] active.
World _world(InputMap map) {
  final world = World()
    ..insertResource(KeyboardState())
    ..insertResource(MouseState())
    ..insertResource(GamepadState())
    ..insertResource(ActionState())
    ..insertResource(
      InputContextRegistry()
        ..register(InputContext(name: 'play', map: map))
        ..push('play'),
    );
  return world;
}

void _resolve(World world) => ActionResolutionSystem().run(world);

void main() {
  group('scroll bindings', () {
    final map = InputMap.builder()
        .bindScroll(ScrollDirection.down, _next)
        .bindScroll(ScrollDirection.up, _prev)
        .build();

    test('each wheel step is one press', () async {
      final world = _world(map);
      world.getResource<MouseState>()!
        ..onScroll(0, 100)
        ..onScroll(0, 100);
      _resolve(world);
      final actions = world.getResource<ActionState>()!;
      expect(actions.justPressed(_next), isTrue);
      expect(actions.getButton(_next)!.presses, 2);
      expect(actions.fixedPressCount(_next), 2);
      expect(actions.justPressed(_prev), isFalse);
      expect(actions.fixedPressCount(_prev), 0);
    });

    test('a step that arrives between frames survives the frame', () async {
      // The real order: events land between ticks, then the tick polls,
      // resolves and, in `last`, ends the frame.
      final app = App()
        ..addPlugin(
          InputPlugin.simple(
            context: InputContext(name: 'play', map: map),
          ),
        );
      final mouse = app.world.getResource<MouseState>()!;
      final actions = app.world.getResource<ActionState>()!;
      await app.tick();
      mouse.onScroll(0, 100);
      await app.tick();
      expect(actions.justPressed(_next), isTrue);
      expect(actions.getButton(_next)!.presses, 1);
      // The next frame starts from zero.
      await app.tick();
      expect(actions.isPressed(_next), isFalse);
    });

    test('presses add up over frames until a fixed step', () async {
      final world = _world(map);
      final mouse = world.getResource<MouseState>()!;
      final actions = world.getResource<ActionState>()!;
      Future<void> frame() async {
        mouse.beginFrame();
        _resolve(world);
        mouse.endFrame();
      }

      mouse.onScroll(0, -50);
      await frame();
      mouse.onScroll(0, -50);
      await frame();
      expect(actions.fixedPressCount(_prev), 2);
      actions.clearFixedLatch();
      await frame();
      expect(actions.isPressed(_prev), isFalse);
      expect(actions.fixedPressCount(_prev), 0);
    });

    test('a key and a wheel step on one action', () async {
      final world = _world(
        InputMap.builder()
            .bindKey(LogicalKeyboardKey.tab, _next)
            .bindScroll(ScrollDirection.down, _next)
            .build(),
      );
      world.getResource<KeyboardState>()!.keyDown(LogicalKeyboardKey.tab);
      world.getResource<MouseState>()!.onScroll(0, 10);
      _resolve(world);
      expect(world.getResource<ActionState>()!.fixedPressCount(_next), 2);
    });
  });

  group('gamepad normalization', () {
    GamepadEvent event(String key, double value, {KeyType? type}) =>
        GamepadEvent(
          gamepadId: 'pad',
          timestamp: 0,
          type: type ?? KeyType.button,
          key: key,
          value: value,
        );

    test('standard keys are snake_case', () {
      expect(standardButtonKey(GamepadButton.leftBumper), 'left_bumper');
      expect(standardButtonKey(GamepadButton.dpadUp), 'dpad_up');
      expect(standardAxisKey(GamepadAxis.rightStickX), 'right_stick_x');
    });

    test('raw Windows keys reach bindings to standard names', () async {
      final world = _world(
        InputMap.builder()
            .bindGamepadButton('right_bumper', _next)
            .bindGamepadButton('left_bumper', _prev)
            .build(),
      );
      world.getResource<GamepadState>()!.applyEvent(
        event('rightShoulder', 1),
        GamepadNormalizer.forPlatform(GamepadPlatform.windows),
      );
      _resolve(world);
      final actions = world.getResource<ActionState>()!;
      expect(actions.justPressed(_next), isTrue);
      expect(actions.isPressed(_prev), isFalse);
    });

    test('the raw key is kept, and stick Y points down', () {
      final pads = GamepadState()
        ..applyEvent(
          event('leftThumbstickY', 1, type: KeyType.analog),
          GamepadNormalizer.forPlatform(GamepadPlatform.windows),
        );
      expect(pads.getAxis('leftThumbstickY'), 1);
      expect(pads.getAxis('left_stick_y'), closeTo(-1, 1e-9));
    });
  });
}
