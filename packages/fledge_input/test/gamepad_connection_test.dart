import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gamepad_source.dart';

void main() {
  late World world;
  late FakeGamepadSource source;
  late GamepadState pads;

  Future<void> pumpInput(WidgetTester tester) async {
    world = World()
      ..insertResource(KeyboardState())
      ..insertResource(MouseState())
      ..insertResource(pads = GamepadState());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InputWidget(
          world: world,
          gamepadSource: source,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => source = FakeGamepadSource());

  testWidgets('pads connected at mount are named, with their USB ids', (
    tester,
  ) async {
    source.pads = [
      const GamepadInfo(
        id: 'p1',
        name: 'Xbox Wireless Controller',
        vendorId: 0x045E,
        productId: 0x0B13,
      ),
    ];
    await pumpInput(tester);
    final pad = pads.get('p1')!;
    expect(pad.name, 'Xbox Wireless Controller');
    expect(pad.vendorId, 0x045E);
    expect(pad.connected, isTrue);
  });

  testWidgets('a pad seen first through an event is named once it connects', (
    tester,
  ) async {
    await pumpInput(tester);
    source.button('p2', 'a', true);
    await tester.pump();
    expect(pads.get('p2')!.name, 'p2');
    source.pads = [const GamepadInfo(id: 'p2', name: 'Pro Controller')];
    source.connect('p2', 'Pro Controller');
    await tester.pump();
    expect(pads.get('p2')!.name, 'Pro Controller');
  });

  testWidgets('unplugged mid-press: everything it held lets go', (
    tester,
  ) async {
    await pumpInput(tester);
    source
      ..connect('p1', 'Pad')
      ..button('p1', 'a', true)
      ..axis('p1', 'left_stick_x', 0.9);
    await tester.pump();
    pads.endFrame();
    expect(pads.isButtonPressed('a'), isTrue);
    final versionBefore = pads.version;

    source.disconnect('p1');
    await tester.pump();
    final pad = pads.get('p1')!;
    expect(pad.connected, isFalse);
    expect(pad.getButtonPhase('a'), ButtonPhase.justReleased);
    expect(pad.getAxis('left_stick_x'), 0);
    expect(pads.isButtonPressed('a'), isFalse);
    expect(pads.version, greaterThan(versionBefore));

    // Its press count doesn't vanish with it.
    expect(pads.pressCount('a'), 1);
  });

  testWidgets('a pad that comes back is connected again', (tester) async {
    await pumpInput(tester);
    source
      ..connect('p1', 'Pad')
      ..disconnect('p1');
    await tester.pump();
    expect(pads.get('p1')!.connected, isFalse);
    source.button('p1', 'b', true);
    await tester.pump();
    expect(pads.get('p1')!.connected, isTrue);
    expect(pads.isButtonPressed('b'), isTrue);
  });

  testWidgets('the widget disposes its source', (tester) async {
    await pumpInput(tester);
    await tester.pumpWidget(const SizedBox());
    expect(source.disposed, isTrue);
  });

  group('GamepadButtonWatcher', () {
    test('a press and release between looks counts once', () {
      final state = GamepadState();
      final watcher = GamepadButtonWatcher(() => state);
      state.getOrCreate('p', 'p')
        ..setButtonPressed('a', true)
        ..setButtonPressed('a', false);
      expect(watcher.takePresses('a'), 1);
      expect(watcher.takePresses('a'), 0);
    });

    test('presses before it was made, or before rebase, don\'t count', () {
      final state = GamepadState();
      final pad = state.getOrCreate('p', 'p')
        ..setButtonPressed('a', true)
        ..setButtonPressed('a', false);
      final watcher = GamepadButtonWatcher(() => state);
      expect(watcher.takePresses('a'), 0);
      pad
        ..setButtonPressed('b', true)
        ..setButtonPressed('b', false);
      watcher.rebase();
      expect(watcher.takePresses('b'), 0);
      pad.setButtonPressed('b', true);
      expect(watcher.takePresses('b'), 1);
      expect(watcher.isDown('b'), isTrue);
    });

    test('several pads add up; a removed pad never makes it negative', () {
      final state = GamepadState();
      final watcher = GamepadButtonWatcher(() => state);
      state.getOrCreate('p', 'p').setButtonPressed('a', true);
      state.getOrCreate('q', 'q').setButtonPressed('a', true);
      expect(watcher.takePresses('a'), 2);
      state.remove('q');
      expect(watcher.takePresses('a'), 0);
      expect(watcher.takePresses('a', gamepadId: 'p'), 1);
    });

    test('with no pads at all it reads nothing', () {
      final watcher = GamepadButtonWatcher(() => null);
      expect(watcher.takePresses('a'), 0);
      expect(watcher.isDown('a'), isFalse);
    });
  });
}
