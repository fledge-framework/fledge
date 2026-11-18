import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
