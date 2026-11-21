import 'package:fledge_input/fledge_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _frame = Duration(milliseconds: 16);

/// An action that takes only some directions.
class _Horizontal extends Action<GamepadDirectionIntent> {
  final List<TraversalDirection> taken = [];

  @override
  bool isEnabled(GamepadDirectionIntent intent) =>
      intent.direction == TraversalDirection.left ||
      intent.direction == TraversalDirection.right;

  @override
  Object? invoke(GamepadDirectionIntent intent) {
    taken.add(intent.direction);
    return null;
  }
}

void main() {
  late GamepadState pads;
  late SingleGamepadState pad;
  late List<FocusNode> nodes;
  late List<String> calls;

  setUp(() {
    pads = GamepadState();
    pad = pads.connect('pad', name: 'Xbox Wireless Controller');
    nodes = [for (var i = 0; i < 6; i++) FocusNode(debugLabel: 'item $i')];
    calls = [];
  });

  tearDown(() {
    for (final n in nodes) {
      n.dispose();
    }
  });

  int focused() => nodes.indexWhere((n) => n.hasFocus);

  Widget item(int i, {Map<Type, Action<Intent>> actions = const {}}) =>
      FocusableActionDetector(
        focusNode: nodes[i],
        autofocus: i == 0,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => calls.add('activate $i'),
          ),
          ...actions,
        },
        child: SizedBox(height: 40, child: Text('item $i')),
      );

  Future<void> pumpBridge(
    WidgetTester tester, {
    bool enabled = true,
    Widget Function(Widget items)? wrap,
    Map<Type, Action<Intent>> firstActions = const {},
    VirtualPointerController? pointer,
  }) async {
    final items = Column(
      children: [
        item(0, actions: firstActions),
        for (var i = 1; i < nodes.length; i++) item(i),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) => calls.add('dismiss'),
            ),
            GamepadTabIntent: CallbackAction<GamepadTabIntent>(
              onInvoke: (i) => calls.add('tab ${i.delta}'),
            ),
            GamepadPageIntent: CallbackAction<GamepadPageIntent>(
              onInvoke: (i) => calls.add('page ${i.delta}'),
            ),
            GamepadButtonIntent: CallbackAction<GamepadButtonIntent>(
              onInvoke: (i) => calls.add('button ${i.button}'),
            ),
          },
          child: GamepadFocusBridge(
            gamepads: () => pads,
            enabled: enabled,
            pointer: pointer,
            child: wrap == null ? items : wrap(items),
          ),
        ),
      ),
    );
    await tester.pump(_frame);
  }

  group('focus', () {
    testWidgets('the d-pad moves focus; a tap between frames counts', (
      tester,
    ) async {
      await pumpBridge(tester);
      expect(focused(), 0);
      pad
        ..setButtonPressed('dpad_down', true)
        ..setButtonPressed('dpad_down', false);
      await tester.pump(_frame);
      expect(focused(), 1);
      pad.setButtonPressed('dpad_down', true);
      await tester.pump(_frame);
      expect(focused(), 2);
      pad.setButtonPressed('dpad_down', false);
      await tester.pump(_frame);
      pad.setButtonPressed('dpad_up', true);
      await tester.pump(_frame);
      expect(focused(), 1);
    });

    testWidgets('a held stick moves once, then repeats after a delay', (
      tester,
    ) async {
      await pumpBridge(tester);
      pad.setAxisValue('left_stick_y', 0.9);
      await tester.pump(_frame);
      expect(focused(), 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(focused(), 1, reason: 'not yet repeating');
      await tester.pump(const Duration(milliseconds: 250));
      expect(focused(), 2);
      await tester.pump(const Duration(milliseconds: 100));
      expect(focused(), 3);
      // A wobble just under the press line still holds; let go, it stops.
      pad.setAxisValue('left_stick_y', 0.4);
      await tester.pump(const Duration(milliseconds: 100));
      pad.setAxisValue('left_stick_y', 0);
      await tester.pump(const Duration(milliseconds: 500));
      final at = focused();
      await tester.pump(const Duration(milliseconds: 500));
      expect(focused(), at);
    });

    testWidgets('A activates, B dismisses, LB/RB and the triggers page, X '
        'reaches its button', (tester) async {
      await pumpBridge(tester);
      pad
        ..setButtonPressed('a', true)
        ..setButtonPressed('b', true)
        ..setButtonPressed('right_bumper', true)
        ..setButtonPressed('x', true)
        ..setAxisValue('left_trigger', 0.9);
      await tester.pump(_frame);
      expect(calls, ['activate 0', 'dismiss', 'tab 1', 'button x', 'page -1']);
    });

    testWidgets('a widget that takes left/right keeps them; up/down still '
        'move focus', (tester) async {
      final horizontal = _Horizontal();
      await pumpBridge(
        tester,
        firstActions: {GamepadDirectionIntent: horizontal},
      );
      pad.setButtonPressed('dpad_right', true);
      await tester.pump(_frame);
      expect(horizontal.taken, [TraversalDirection.right]);
      expect(focused(), 0);
      pad
        ..setButtonPressed('dpad_right', false)
        ..setButtonPressed('dpad_down', true);
      await tester.pump(_frame);
      expect(focused(), 1);
    });

    testWidgets('disabled it does nothing; what was pressed before it was '
        'enabled isn\'t replayed', (tester) async {
      await pumpBridge(tester, enabled: false);
      pad
        ..setButtonPressed('a', true)
        ..setButtonPressed('a', false)
        ..setAxisValue('left_stick_y', 1);
      await tester.pump(_frame);
      expect(calls, isEmpty);
      expect(focused(), 0);
      // Enabled with the stick still held: nothing until it's let go.
      await pumpBridge(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, isEmpty);
      expect(focused(), 0);
      pad.setAxisValue('left_stick_y', 0);
      await tester.pump(_frame);
      pad.setButtonPressed('dpad_down', true);
      await tester.pump(_frame);
      expect(focused(), 1);
    });

    testWidgets('the right stick scrolls what the focus is in', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpBridge(
        tester,
        // Loose, so the box really is 100 high and its contents scroll.
        wrap: (items) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 100,
            child: SingleChildScrollView(controller: controller, child: items),
          ),
        ),
      );
      pad.setAxisValue('right_stick_y', 1);
      for (var i = 0; i < 10; i++) {
        await tester.pump(_frame);
      }
      expect(controller.offset, greaterThan(20));
    });
  });

  group('the virtual pointer', () {
    late VirtualPointerController pointer;

    setUp(() => pointer = VirtualPointerController());

    Future<void> pumpPointer(
      WidgetTester tester, {
      required Widget target,
    }) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) => calls.add('dismiss'),
              ),
            },
            child: GamepadFocusBridge(
              gamepads: () => pads,
              pointer: pointer,
              child: VirtualPointer(
                controller: pointer,
                child: Stack(
                  children: [Positioned(left: 500, top: 280, child: target)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(_frame);
    }

    Future<void> moveRightUntil(WidgetTester tester, double x) async {
      pad.setAxisValue('right_stick_x', 1);
      for (var i = 0; i < 120 && pointer.position.dx < x; i++) {
        await tester.pump(_frame);
      }
      pad.setAxisValue('right_stick_x', 0);
      await tester.pump(_frame);
    }

    testWidgets('R3 shows it; the stick moves it; hover enters and A clicks '
        'what\'s under it', (tester) async {
      var entered = false;
      var taps = 0;
      await pumpPointer(
        tester,
        target: MouseRegion(
          onEnter: (_) => entered = true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );
      pad.setButtonPressed('right_stick', true);
      await tester.pump(_frame);
      expect(pointer.active, isTrue);
      expect(pointer.position, const Offset(400, 300), reason: 'the middle');
      pad.setButtonPressed('right_stick', false);
      await moveRightUntil(tester, 520);
      expect(pointer.position.dx, greaterThanOrEqualTo(520));
      expect(entered, isTrue);
      // A quick tap between frames still clicks.
      pad
        ..setButtonPressed('a', true)
        ..setButtonPressed('a', false);
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(taps, 1);
    });

    testWidgets('held, A drags', (tester) async {
      var dragged = 0.0;
      await pumpPointer(
        tester,
        target: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => dragged += d.delta.dx,
          child: const SizedBox(width: 200, height: 60),
        ),
      );
      pad.setButtonPressed('right_stick', true);
      await tester.pump(_frame);
      pad.setButtonPressed('right_stick', false);
      await moveRightUntil(tester, 510);
      pad.setButtonPressed('a', true);
      await tester.pump(_frame);
      await moveRightUntil(tester, 600);
      pad.setButtonPressed('a', false);
      await tester.pump(_frame);
      expect(dragged, greaterThan(40));
    });

    testWidgets('B hides it and goes no further; so does the d-pad', (
      tester,
    ) async {
      await pumpPointer(tester, target: const SizedBox());
      pad.setButtonPressed('right_stick', true);
      await tester.pump(_frame);
      pad.setButtonPressed('right_stick', false);
      pad.setButtonPressed('b', true);
      await tester.pump(_frame);
      expect(pointer.active, isFalse);
      expect(calls, isEmpty, reason: 'B was the pointer\'s, not a dismiss');
      pad
        ..setButtonPressed('b', false)
        ..setButtonPressed('right_stick', true);
      await tester.pump(_frame);
      expect(pointer.active, isTrue);
      pad
        ..setButtonPressed('right_stick', false)
        ..setButtonPressed('dpad_left', true);
      await tester.pump(_frame);
      expect(pointer.active, isFalse);
    });
  });

  test('keys held in place: the pointer stays inside the view', () {
    final pointer = VirtualPointerController()
      ..bounds = const Rect.fromLTWH(0, 0, 100, 100)
      ..show();
    pointer.moveBy(const Offset(500, -500));
    expect(pointer.position, const Offset(99, 0));
  });
}
