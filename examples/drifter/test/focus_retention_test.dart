import 'package:drifter_example/game_widget.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the "click-to-pause" regression: a game embedded in a
/// docs-style scaffold (outer `Focus(autofocus:true)` for shortcuts +
/// `SelectionArea` for text selection) should keep focus on
/// subsequent clicks, not toss it back to the selection layer and
/// re-show the "Click to play" overlay.
void main() {
  testWidgets('clicking a focused canvas does not lose focus', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Focus(
        autofocus: true,
        onKeyEvent: (_, __) => KeyEventResult.ignored,
        child: SelectionArea(
          child: const Scaffold(
            body: Center(child: DrifterWidget()),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final input = tester.widget<InputWidget>(find.byType(InputWidget));
    final focus = input.focusNode!;

    // Simulate clicking the overlay to gain focus (first interaction).
    await tester.tap(find.text('Click to play'));
    await tester.pump();
    expect(focus.hasFocus, isTrue,
        reason: 'tapping overlay should transfer focus to the game');
    expect(find.text('Click to play'), findsNothing);

    // Second click on the canvas — should be a no-op focus-wise.
    await tester.tap(find.byType(CustomPaint).first);
    await tester.pump();
    expect(focus.hasFocus, isTrue,
        reason:
            'clicking inside an already-focused canvas must not lose focus');
    expect(find.text('Click to play'), findsNothing,
        reason: 'overlay should stay hidden on re-click');
  });
}
