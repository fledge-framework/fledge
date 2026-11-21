import 'dart:math' as math;

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

const _move = ActionId('move');
const _fire = ActionId('fire');

/// A world with raw input, an [ActionState] and [map] active.
World _world(InputMap map) => World()
  ..insertResource(KeyboardState())
  ..insertResource(MouseState())
  ..insertResource(GamepadState())
  ..insertResource(ActionState())
  ..insertResource(
    InputContextRegistry()
      ..register(InputContext(name: 'play', map: map))
      ..push('play'),
  );

/// One frame: resolve, then end the frame as `last` does.
void _frame(World world, [ActionResolutionSystem? system]) {
  (system ?? ActionResolutionSystem()).run(world);
  world.getResource<KeyboardState>()!.endFrame();
  world.getResource<GamepadState>()!.endFrame();
}

void _stick(World world, double x, double y, {String pad = 'pad'}) {
  world.getResource<GamepadState>()!.getOrCreate(pad, pad)
    ..setAxisValue('left_stick_x', x)
    ..setAxisValue('left_stick_y', y);
}

Vector2Value _vec(World world) =>
    world.getResource<ActionState>()!.getVector2(_move)!;

double _len(Vector2Value v) => math.sqrt(v.x * v.x + v.y * v.y);

void main() {
  group('sticks', () {
    final map = InputMap.builder()
        .bindLeftStick(_move, deadzone: 0.2)
        .bindWasd(_move)
        .build();

    test('bindLeftStick is one stick binding on a vector2 action', () {
      expect(
        map.bindings.where((b) => b.action == _move).map((b) => b.source),
        [GamepadStickBinding.left],
      );
      expect(map.actionTypes[_move], ActionType.vector2);
    });

    test('noise inside the radial deadzone reads exactly zero', () {
      final world = _world(map);
      // 0.13 on each axis is past a square 0.1 deadzone, but its length
      // (0.18) is inside the radial 0.2 one.
      _stick(world, 0.13, 0.13);
      _frame(world);
      expect(_vec(world).x, 0);
      expect(_vec(world).y, 0);
    });

    test('past the deadzone it rescales smoothly, the same every way', () {
      final world = _world(map);
      // Halfway between the deadzone (0.2) and full tilt (0.95).
      const mid = 0.2 + (0.95 - 0.2) / 2;
      for (final angle in [0.0, 0.7, 2.0, 4.0]) {
        _stick(world, mid * math.cos(angle), mid * math.sin(angle));
        _frame(world);
        expect(_len(_vec(world)), closeTo(0.5, 1e-9), reason: '$angle');
      }
      // Just past the edge it starts near zero, not with a jump.
      _stick(world, 0.21, 0);
      _frame(world);
      expect(_vec(world).x, closeTo(0.01 / 0.75, 1e-9));
    });

    test('a full diagonal is length 1, and so is the rim', () {
      final world = _world(map);
      _stick(world, 1, 1);
      _frame(world);
      expect(_len(_vec(world)), closeTo(1, 1e-9));
      _stick(world, 0.96, 0);
      _frame(world);
      expect(_vec(world).x, closeTo(1, 1e-9));
    });

    test('stick y is down, like the keyboard', () {
      final world = _world(map);
      _stick(world, 0, 1);
      _frame(world);
      expect(_vec(world).y, closeTo(1, 1e-9));
    });
  });

  group('the vector2 clamp', () {
    test('a keyboard diagonal is (0.707, 0.707)', () {
      final world = _world(InputMap.builder().bindWasd(_move).build());
      world.getResource<KeyboardState>()!
        ..keyDown(LogicalKeyboardKey.keyD)
        ..keyDown(LogicalKeyboardKey.keyS);
      _frame(world);
      expect(_vec(world).x, closeTo(math.sqrt1_2, 1e-9));
      expect(_vec(world).y, closeTo(math.sqrt1_2, 1e-9));
    });

    test('keys and a stick together never pass full tilt', () {
      final world = _world(
        InputMap.builder().bindWasd(_move).bindLeftStick(_move).build(),
      );
      world.getResource<KeyboardState>()!.keyDown(LogicalKeyboardKey.keyD);
      _stick(world, 1, 0);
      _frame(world);
      expect(_vec(world).x, closeTo(1, 1e-9));
    });

    test('opted out, values are summed as they are', () {
      final world = _world(
        InputMap.builder().bindWasd(_move).withUnclampedVector2(_move).build(),
      );
      world.getResource<KeyboardState>()!
        ..keyDown(LogicalKeyboardKey.keyD)
        ..keyDown(LogicalKeyboardKey.keyS);
      _frame(world);
      expect((_vec(world).x, _vec(world).y), (1.0, 1.0));
    });
  });

  group('an axis as a button (triggers)', () {
    InputMap map() => InputMap.builder()
        .bindGamepadAxisAsButton('right_trigger', _fire)
        .build();

    void trigger(World world, double value) => world
        .getResource<GamepadState>()!
        .getOrCreate('pad', 'pad')
        .setAxisValue('right_trigger', value);

    test('pressed past the press point, once; held; let go', () {
      final world = _world(map());
      final system = ActionResolutionSystem();
      final actions = world.getResource<ActionState>()!;
      trigger(world, 0.3);
      _frame(world, system);
      expect(actions.isPressed(_fire), isFalse);
      trigger(world, 0.8);
      _frame(world, system);
      expect(actions.justPressed(_fire), isTrue);
      expect(actions.fixedPressCount(_fire), 1);
      _frame(world, system);
      expect(actions.isHeld(_fire), isTrue);
      expect(actions.justPressed(_fire), isFalse);
      trigger(world, 0);
      _frame(world, system);
      expect(actions.justReleased(_fire), isTrue);
      expect(actions.fixedPressCount(_fire), 1);
    });

    test('resting near the line doesn\'t chatter (hysteresis)', () {
      final world = _world(map());
      final system = ActionResolutionSystem();
      final actions = world.getResource<ActionState>()!;
      trigger(world, 0.55);
      _frame(world, system);
      expect(actions.justPressed(_fire), isTrue);
      // Wobbling just under the press point still holds.
      for (final v in [0.48, 0.52, 0.45, 0.5]) {
        trigger(world, v);
        _frame(world, system);
        expect(actions.isPressed(_fire), isTrue, reason: '$v');
      }
      trigger(world, 0.38);
      _frame(world, system);
      expect(actions.justReleased(_fire), isTrue);
    });

    test('bind() takes its type from the source', () {
      final built = InputMap.builder()
          .bind(GamepadStickBinding.left, _move)
          .bind(const GamepadAxisBinding('left_trigger'), const ActionId('t'))
          .bind(GamepadButtonBinding.a, _fire)
          .build();
      expect(built.actionTypes[_move], ActionType.vector2);
      expect(built.actionTypes[const ActionId('t')], ActionType.axis);
      expect(built.actionTypes[_fire], ActionType.button);
    });
  });

  group('composites', () {
    test('half-axes count by how far they\'re pushed', () {
      final world = _world(
        InputMap.builder()
            .bindComposite(
              _move,
              up: const GamepadAxisBinding('left_stick_y', inverted: true),
              down: GamepadAxisBinding.leftStickY,
              left: const GamepadAxisBinding('left_stick_x', inverted: true),
              right: GamepadAxisBinding.leftStickX,
            )
            .build(),
      );
      _stick(world, 0.6, -0.4);
      _frame(world);
      expect(_vec(world).x, closeTo(0.6, 1e-9));
      expect(_vec(world).y, closeTo(-0.4, 1e-9));
      // Inside the deadzone: nothing.
      _stick(world, 0.05, 0);
      _frame(world);
      expect(_vec(world).x, 0);
    });

    test('the d-pad still reads as buttons', () {
      final world = _world(InputMap.builder().bindDpad(_move).build());
      world
          .getResource<GamepadState>()!
          .getOrCreate('pad', 'pad')
          .setButtonPressed('dpad_left', true);
      _frame(world);
      expect(_vec(world).x, -1);
    });
  });

  test('a raw axis key that names neither half feeds no vector', () {
    final world = _world(
      InputMap.builder()
          .bind(const GamepadAxisBinding('1'), _move)
          .withActionType(_move, ActionType.vector2)
          .build(),
    );
    world
        .getResource<GamepadState>()!
        .getOrCreate('pad', 'pad')
        .setAxisValue('1', 0.9);
    _frame(world);
    expect((_vec(world).x, _vec(world).y), (0.0, 0.0));
  });
}
