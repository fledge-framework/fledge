import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fledge_docs/demos/grid_game/grid_game_widget.dart';
import 'package:fledge_docs/demos/grid_game/components.dart';
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_input/fledge_input.dart';

void main() {
  testWidgets(
    'demo pauses without focus, resumes when overlay tapped, '
    'and unbound keys bubble to ancestor handlers',
    (tester) async {
      // Mimic demo_page.dart: an ancestor Focus(autofocus: true) for
      // page-level keyboard shortcuts wraps the game widget. This grabs
      // primary focus before the GridGameWidget's InputWidget can.
      var outerShortcutInvocations = 0;
      await tester.pumpWidget(MaterialApp(
        home: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.keyK) {
              outerShortcutInvocations++;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            body: Center(child: const GridGameWidget()),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      final InputWidget inputWidget =
          tester.widget<InputWidget>(find.byType(InputWidget));
      final World world = inputWidget.world;
      final FocusNode gameFocus = inputWidget.focusNode!;

      int playerY() {
        for (final (_, pos) in world
            .query1<GridPosition>(filter: const With<Player>())
            .iter()) {
          return pos.y;
        }
        throw StateError('player entity not found');
      }

      final startY = playerY();

      // Paused state: ancestor Focus has focus, overlay should be visible,
      // and arrow keys should not move the player.
      expect(gameFocus.hasFocus, isFalse,
          reason: 'game should not have focus on initial mount');
      expect(find.text('Click to play'), findsOneWidget,
          reason: 'pause overlay must be shown when unfocused');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      expect(playerY(), startY, reason: 'paused game should ignore arrow keys');

      // Tap the overlay to resume — it should request focus and hide.
      await tester.tap(find.text('Click to play'));
      await tester.pump();
      expect(gameFocus.hasFocus, isTrue,
          reason: 'tapping overlay must transfer focus to the game');
      expect(find.text('Click to play'), findsNothing,
          reason: 'overlay must disappear after resuming');

      // Now arrow keys move the player.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      expect(playerY(), lessThan(startY),
          reason: 'arrow up should move the player up after resume');

      // Unbound keys still bubble up to ancestor shortcut handlers while the
      // game has focus (verified via the page-level Ctrl+K-style handler).
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      expect(outerShortcutInvocations, 1,
          reason: 'non-game keys must bubble to ancestor Focus handlers');
    },
  );

  testWidgets(
    'clicking a focused canvas does not pause the game — SelectionArea '
    'must not steal focus on re-click',
    (tester) async {
      // Mirror the live docs scaffold: a `SelectionArea` wraps the page so
      // prose is selectable. The outer `Focus(autofocus: true)` is what
      // prevents InputWidget's own autofocus from succeeding on mount,
      // so we can then deterministically tap-to-focus and verify a
      // subsequent click does NOT lose focus. Without the InputWidget
      // gesture-arena fix, SelectionArea's SelectableRegion would win
      // the second tap, steal focus, and the game would re-pause.
      await tester.pumpWidget(MaterialApp(
        home: Focus(
          autofocus: true,
          onKeyEvent: (_, __) => KeyEventResult.ignored,
          child: SelectionArea(
            child: Scaffold(
              body: Center(child: const GridGameWidget()),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      final InputWidget inputWidget =
          tester.widget<InputWidget>(find.byType(InputWidget));
      final gameFocus = inputWidget.focusNode!;

      // Paused at this point — outer Focus has primary focus.
      expect(gameFocus.hasFocus, isFalse);
      expect(find.text('Controls: ← ↑ ↓ →'), findsOneWidget);

      // Tap to grab focus.
      await tester.tap(find.byType(CustomPaint).first);
      await tester.pump();
      expect(gameFocus.hasFocus, isTrue,
          reason: 'first tap should transfer focus to the game');

      // Second click on the same canvas while focused — must be a
      // no-op focus-wise. This is the scenario the InputWidget
      // gesture-arena fix guards against.
      await tester.tap(find.byType(CustomPaint).first);
      await tester.pump();
      expect(gameFocus.hasFocus, isTrue,
          reason: 'clicking a focused canvas must not lose focus');
    },
  );
}
