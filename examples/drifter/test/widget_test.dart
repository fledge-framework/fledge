import 'package:drifter_example/components.dart';
import 'package:drifter_example/game_widget.dart';
import 'package:fledge_input/fledge_input.dart';
import 'package:fledge_render_2d/fledge_render_2d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('widget boots and exposes the HUD', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: DrifterWidget())),
    ));
    await tester.pump();
    await tester.pump();

    // The HUD shows the run + best scores regardless of focus state.
    expect(find.textContaining('Run:'), findsOneWidget);
    expect(find.textContaining('Best:'), findsOneWidget);
    expect(find.textContaining('Pickups left:'), findsOneWidget);

    // An InputWidget is in the tree and owns a FocusNode we can inspect.
    final InputWidget inputWidget =
        tester.widget<InputWidget>(find.byType(InputWidget));
    expect(inputWidget.focusNode, isNotNull);
  });

  testWidgets('losing focus shows the click-to-play overlay', (tester) async {
    // Wrap in an outer Focus(autofocus: true) so the DrifterWidget's
    // InputWidget can't claim primary focus on mount — mirrors the
    // docs-embedded scenario that made the pause behaviour necessary.
    await tester.pumpWidget(MaterialApp(
      home: Focus(
        autofocus: true,
        onKeyEvent: (_, __) => KeyEventResult.ignored,
        child: const Scaffold(body: Center(child: DrifterWidget())),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Click to play'), findsOneWidget);
  });

  testWidgets(
      'arrow key held while focused moves the player after ticks elapse',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: DrifterWidget())),
    ));
    await tester.pump();

    final InputWidget inputWidget =
        tester.widget<InputWidget>(find.byType(InputWidget));
    final world = inputWidget.world;
    final gameFocus = inputWidget.focusNode!;

    // Find the player's transform.
    Transform2D playerTransform() {
      for (final (_, t, _) in world.query2<Transform2D, Player>().iter()) {
        return t;
      }
      throw StateError('no player');
    }

    final startX = playerTransform().translation.x;

    // Focus the game (in the live app this happens on user click; in a
    // test we can call requestFocus directly).
    gameFocus.requestFocus();
    await tester.pump();
    expect(gameFocus.hasFocus, isTrue);
    expect(find.text('Click to play'), findsNothing);

    // Hold arrow-right for a few simulated frames.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

    final endX = playerTransform().translation.x;
    expect(endX, greaterThan(startX),
        reason: 'arrow-right should move the player right');
  });
}
