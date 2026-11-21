import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gamepad_source.dart';

void main() {
  group('families', () {
    test('by vendor id first, then by name', () {
      final cases = <(String, int?, GamepadFamily)>[
        ('Xbox Wireless Controller', null, GamepadFamily.xbox),
        ('Xbox 360 Controller for Windows', null, GamepadFamily.xbox),
        ('DualSense Wireless Controller', null, GamepadFamily.playStation),
        ('Wireless Controller', null, GamepadFamily.playStation),
        ('PS4 Controller', null, GamepadFamily.playStation),
        ('Pro Controller', null, GamepadFamily.nintendo),
        ('Joy-Con (L/R)', null, GamepadFamily.nintendo),
        ('8BitDo Ultimate', null, GamepadFamily.generic),
        // The vendor settles it, whatever the name.
        ('Controller', 0x054C, GamepadFamily.playStation),
        ('Controller', 0x057E, GamepadFamily.nintendo),
        ('Controller', 0x045E, GamepadFamily.xbox),
      ];
      for (final (name, vendor, family) in cases) {
        expect(
          detectGamepadFamily(name, vendorId: vendor),
          family,
          reason: '$name / $vendor',
        );
      }
    });

    test('labels per family; Nintendo labels follow position', () {
      expect(gamepadButtonLabel('a', GamepadFamily.xbox), 'A');
      expect(gamepadButtonLabel('a', GamepadFamily.playStation), 'Cross');
      expect(gamepadButtonLabel('a', GamepadFamily.nintendo), 'B');
      expect(gamepadButtonLabel('b', GamepadFamily.nintendo), 'A');
      expect(gamepadButtonLabel('left_bumper', GamepadFamily.xbox), 'LB');
      expect(
        gamepadButtonLabel('left_bumper', GamepadFamily.playStation),
        'L1',
      );
      expect(gamepadButtonLabel('right_trigger', GamepadFamily.nintendo), 'ZR');
      expect(gamepadButtonLabel('start', GamepadFamily.playStation), 'Options');
      expect(gamepadButtonLabel('start', GamepadFamily.nintendo), '+');
      expect(gamepadButtonLabel('back', GamepadFamily.generic), 'View');
      expect(gamepadButtonLabel('dpad_up', GamepadFamily.nintendo), 'D-pad up');
      expect(
        gamepadStickLabel(GamepadStick.left, GamepadFamily.xbox),
        'Left stick',
      );
    });
  });

  group('the device in use', () {
    late World world;
    late FakeGamepadSource source;
    late ActiveInputDevice device;
    late FocusNode node;

    Future<void> pumpInput(
      WidgetTester tester, {
      bool claimFocus = true,
      FocusNode? other,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              Expanded(
                child: InputWidget(
                  world: world,
                  gamepadSource: source,
                  focusNode: node,
                  claimFocus: claimFocus,
                  ignoreGamepadWhenInactive: true,
                  child: const SizedBox.expand(),
                ),
              ),
              if (other != null)
                Focus(
                  focusNode: other,
                  child: const SizedBox(width: 10, height: 10),
                ),
            ],
          ),
        ),
      );
      await tester.pump();
    }

    setUp(() {
      source = FakeGamepadSource();
      device = ActiveInputDevice();
      node = FocusNode();
      world = World()
        ..insertResource(KeyboardState())
        ..insertResource(MouseState())
        ..insertResource(GamepadState())
        ..insertResource(device)
        ..insertResource(GamepadRumble(device: device));
    });

    tearDown(() => node.dispose());

    testWidgets('a key, a pad, a real mouse move: each takes over', (
      tester,
    ) async {
      source.pads = [
        const GamepadInfo(
          id: 'p1',
          name: 'DualSense Wireless Controller',
          vendorId: 0x054C,
        ),
      ];
      await pumpInput(tester);
      final changes = <InputDeviceKind>[];
      device.addListener(() => changes.add(device.kind));

      source.button('p1', 'a', true);
      await tester.pump();
      expect(device.kind, InputDeviceKind.gamepad);
      expect(device.gamepadId, 'p1');
      expect(device.family, GamepadFamily.playStation);

      // Resting stick drift doesn't count; a push does (no change here).
      source.axis('p1', 'left_stick_x', 0.2);
      await tester.pump();
      expect(changes, [InputDeviceKind.gamepad]);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      expect(device.kind, InputDeviceKind.keyboard);
      expect(device.family, GamepadFamily.playStation, reason: 'kept');

      source.button('p1', 'b', true);
      await tester.pump();
      expect(device.kind, InputDeviceKind.gamepad);

      // A mouse nudged by the desk stays the pad's; a real move takes over.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(50, 50));
      await mouse.moveBy(const Offset(3, 0));
      expect(device.kind, InputDeviceKind.gamepad);
      await mouse.moveBy(const Offset(20, 0));
      expect(device.kind, InputDeviceKind.mouse);
    });

    testWidgets('a virtual pointer driven by a pad stays the pad\'s', (
      tester,
    ) async {
      await pumpInput(tester);
      source.button('p1', 'a', true);
      await tester.pump();
      device.gamepadPointerDevices.add(77);
      // Synthetic mouse events from device 77, as a virtual pointer sends.
      void send(PointerEvent event) =>
          GestureBinding.instance.handlePointerEvent(event);
      const kind = PointerDeviceKind.mouse;
      send(
        const PointerAddedEvent(
          device: 77,
          kind: kind,
          position: Offset(10, 10),
        ),
      );
      send(
        const PointerHoverEvent(
          device: 77,
          kind: kind,
          position: Offset(210, 10),
          delta: Offset(200, 0),
        ),
      );
      send(
        const PointerDownEvent(
          pointer: 900,
          device: 77,
          kind: kind,
          position: Offset(210, 10),
        ),
      );
      send(
        const PointerUpEvent(
          pointer: 900,
          device: 77,
          kind: kind,
          position: Offset(210, 10),
        ),
      );
      send(
        const PointerRemovedEvent(
          device: 77,
          kind: kind,
          position: Offset(210, 10),
        ),
      );
      await tester.pump();
      expect(device.kind, InputDeviceKind.gamepad);
    });

    testWidgets('rumble goes to the pad in use, through the source', (
      tester,
    ) async {
      await pumpInput(tester);
      final rumble = world.getResource<GamepadRumble>()!;
      // The keyboard in use: a pad on the desk stays still.
      rumble.play(const RumbleEffect(low: 0.5));
      expect(source.rumbles, isEmpty);
      expect(rumble.recent, isEmpty);

      source.button('p1', 'a', true);
      await tester.pump();
      rumble.play(const RumbleEffect(low: 0.5, high: 0.2));
      await tester.pump();
      expect(source.rumbles, [('p1', 0.5, 0.2)]);
      expect(rumble.recent.single.$2, 'p1');

      rumble.enabled = false;
      rumble.play(const RumbleEffect(low: 1));
      await tester.pump();
      expect(source.rumbles, hasLength(1));

      // Gone with the widget.
      await tester.pumpWidget(const SizedBox());
      expect(rumble.handler, isNull);
    });

    testWidgets('claimFocus false leaves focus with an overlay through hover '
        'and clicks; true takes it back', (tester) async {
      final other = FocusNode();
      addTearDown(other.dispose);
      await pumpInput(tester, claimFocus: false, other: other);
      expect(node.hasFocus, isFalse);
      other.requestFocus();
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(100, 100));
      await mouse.moveTo(const Offset(120, 100));
      await mouse.down(const Offset(120, 100));
      await mouse.up();
      await tester.pump();
      expect(other.hasFocus, isTrue);
      expect(node.hasFocus, isFalse);

      await pumpInput(tester, other: other);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('a key let go while unfocused isn\'t stuck when focus comes '
        'back', (tester) async {
      final other = FocusNode();
      addTearDown(other.dispose);
      await pumpInput(tester, other: other);
      final keyboard = world.getResource<KeyboardState>()!;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      expect(keyboard.isPressed(LogicalKeyboardKey.keyD), isTrue);

      // A menu takes the focus; the key is let go there.
      other.requestFocus();
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      expect(keyboard.isPressed(LogicalKeyboardKey.keyD), isTrue);

      node.requestFocus();
      await tester.pump();
      expect(keyboard.isPressed(LogicalKeyboardKey.keyD), isFalse);
    });

    testWidgets('alt-tabbed away, pads are ignored and let go', (tester) async {
      await pumpInput(tester);
      final pads = world.getResource<GamepadState>()!;
      source.button('p1', 'a', true);
      await tester.pump();
      expect(pads.isButtonPressed('a'), isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(pads.isButtonPressed('a'), isFalse);
      source.button('p1', 'b', true);
      await tester.pump();
      expect(pads.isButtonPressed('b'), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      source.button('p1', 'x', true);
      await tester.pump();
      expect(pads.isButtonPressed('x'), isTrue);
    });
  });

  test(
    'KeyboardState.sync releases stale keys and adopts held ones quietly',
    () {
      final keyboard = KeyboardState()
        ..keyDown(LogicalKeyboardKey.keyA)
        ..endFrame();
      keyboard.sync({LogicalKeyboardKey.keyB});
      expect(keyboard.justReleased(LogicalKeyboardKey.keyA), isTrue);
      expect(keyboard.isPressed(LogicalKeyboardKey.keyB), isTrue);
      expect(keyboard.justPressed(LogicalKeyboardKey.keyB), isFalse);
    },
  );
}
