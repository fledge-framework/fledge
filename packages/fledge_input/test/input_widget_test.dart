import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gamepad_source.dart';

void main() {
  testWidgets('a press records its position even without a prior hover', (
    tester,
  ) async {
    final world = World()..insertResource(MouseState());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: InputWidget(
              world: world,
              enableGamepad: false,
              child: const ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(InputWidget));
    final mouse = world.getResource<MouseState>()!;

    // A touch tap has no hover before it.
    final gesture = await tester.startGesture(
      origin + const Offset(30, 40),
      kind: PointerDeviceKind.touch,
    );
    expect((mouse.x, mouse.y), (30.0, 40.0));
    expect(mouse.isButtonPressed(0), isTrue);

    await gesture.up();
    expect((mouse.x, mouse.y), (30.0, 40.0));
    expect(mouse.isButtonPressed(0), isFalse);
  });

  testWidgets('a visible cursor is the one the app shows around the game', (
    tester,
  ) async {
    final world = World()..insertResource(MouseState());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          child: InputWidget(
            world: world,
            enableGamepad: false,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(InputWidget)),
    );
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.precise,
    );
  });

  Future<(World, Offset)> pumpMouse(WidgetTester tester) async {
    final world = World()..insertResource(MouseState());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InputWidget(
          world: world,
          enableGamepad: false,
          child: const ColoredBox(color: Color(0xFF000000)),
        ),
      ),
    );
    return (world, tester.getCenter(find.byType(InputWidget)));
  }

  for (final (name, bit, index) in [
    ('back', kBackMouseButton, 3),
    ('forward', kForwardMouseButton, 4),
    ('middle', kMiddleMouseButton, 1),
  ]) {
    testWidgets('the $name mouse button is let go on release', (tester) async {
      final (world, at) = await pumpMouse(tester);
      final mouse = world.getResource<MouseState>()!;
      // A pointer id that isn't a button index, so the release can't be
      // read as one.
      final pointer = TestPointer(17, PointerDeviceKind.mouse, null, bit);
      await tester.sendEventToBinding(pointer.down(at));
      expect(mouse.isButtonPressed(index), isTrue);
      await tester.sendEventToBinding(pointer.up());
      expect(mouse.isButtonPressed(index), isFalse);
    });
  }

  testWidgets('a second button pressed mid-drag is pressed and let go', (
    tester,
  ) async {
    final (world, at) = await pumpMouse(tester);
    final mouse = world.getResource<MouseState>()!;
    final pointer = TestPointer(1, PointerDeviceKind.mouse, null, 0);
    await tester.sendEventToBinding(pointer.down(at, buttons: kPrimaryButton));
    // The back button joins while the left is held: a move with more bits.
    await tester.sendEventToBinding(
      pointer.move(at, buttons: kPrimaryButton | kBackMouseButton),
    );
    expect(mouse.isButtonPressed(0), isTrue);
    expect(mouse.isButtonPressed(3), isTrue);
    await tester.sendEventToBinding(pointer.move(at, buttons: kPrimaryButton));
    expect(mouse.isButtonPressed(3), isFalse);
    await tester.sendEventToBinding(pointer.up());
    expect(mouse.isButtonPressed(0), isFalse);
  });

  testWidgets('InputPlugin(enableGamepad: false) stops gamepad polling', (
    tester,
  ) async {
    final source = FakeGamepadSource();
    final world = World()
      ..insertResource(MouseState())
      ..insertResource(GamepadState())
      ..insertResource(const InputSettings(enableGamepad: false));
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
    expect(source.events_.hasListener, isFalse);
  });

  testWidgets('a context switch applies its cursor without a rebuild', (
    tester,
  ) async {
    final app = App()
      ..addPlugin(
        InputPlugin(
          contexts: [
            InputContext(name: 'menu', map: InputMap.builder().build()),
            InputContext(
              name: 'gameplay',
              map: InputMap.builder().build(),
              cursorMode: CursorMode.hidden,
            ),
          ],
          defaultContext: 'menu',
          enableGamepad: false,
        ),
      );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InputWidget(world: app.world, child: const SizedBox.expand()),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(InputWidget)),
    );
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      isNot(SystemMouseCursors.none),
    );

    app.world.getResource<InputContextRegistry>()!.setActive('gameplay');
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.none,
    );
  });
}
