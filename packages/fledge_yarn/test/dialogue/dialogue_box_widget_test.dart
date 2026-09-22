import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialogue_harness.dart';

// The core DialogueBoxWidget (presentation only: reads DialogueState,
// reports taps through callbacks).

void main() {
  late DialogueHarness h;
  late int advances;
  late List<int> selected;

  setUp(() {
    h = DialogueHarness();
    advances = 0;
    selected = [];
  });

  Future<void> pumpBox(
    WidgetTester tester, {
    String? Function(String)? speakerLabel,
    Widget? headerTrailing,
    DialoguePortraitBuilder? portraitBuilder,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            child: DialogueBoxWidget(
              state: h.state,
              speakerLabel: speakerLabel,
              headerTrailing: headerTrailing,
              portraitBuilder: portraitBuilder,
              onAdvance: () => advances++,
              onChoiceSelected: selected.add,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('nothing without an active dialogue', (tester) async {
    await pumpBox(tester);
    expect(find.byKey(DialogueBoxWidget.boxKey), findsNothing);
  });

  testWidgets('shows the speaker from the line and the typed text', (
    tester,
  ) async {
    await h.start('intro');
    await h.tick(0.1);
    await pumpBox(tester);
    expect(
      tester.widget<Text>(find.byKey(DialogueBoxWidget.speakerKey)).data,
      'Guide',
    );
    expect(find.text('Hell'), findsOneWidget);
    expect(find.text('Continue'), findsNothing, reason: 'still typing');

    await h.tick(1);
    await pumpBox(tester);
    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('speakerLabel resolves the display name; narration has no '
      'speaker', (tester) async {
    await h.start('intro');
    await pumpBox(tester, speakerLabel: (c) => c.toUpperCase());
    expect(find.text('GUIDE'), findsOneWidget);

    h = DialogueHarness();
    await h.start('narration');
    await pumpBox(tester);
    expect(find.byKey(DialogueBoxWidget.speakerKey), findsNothing);
  });

  testWidgets('portrait slot and header trailing widget', (tester) async {
    await h.start('intro');
    await pumpBox(
      tester,
      headerTrailing: const Text('meta'),
      portraitBuilder: (context, line) =>
          Text('portrait:${line.character}', key: const ValueKey('p')),
    );
    expect(find.text('meta'), findsOneWidget);
    expect(find.text('portrait:Guide'), findsOneWidget);
  });

  testWidgets('tapping the box reports an advance', (tester) async {
    await h.start('intro');
    await pumpBox(tester);
    await tester.tap(find.byKey(DialogueBoxWidget.boxKey));
    expect(advances, 1);
  });

  testWidgets('with a choice pending: options with the highlight; tapping '
      'one reports it, tapping the box does not advance', (tester) async {
    await h.start('skip_chain');
    await h.request(const DialogueSkipRequested());
    await h.request(const DialogueCursorMoved(1));
    await pumpBox(tester);
    expect(find.text('Three.'), findsOneWidget);
    expect(find.text('Go on'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.byKey(DialogueChoiceList.optionKey(0)));
    expect(selected, [0]);
    await tester.tap(find.text('Three.'));
    expect(advances, 0);

    h = DialogueHarness();
    await h.start('intro');
    await h.advanceLine();
    await h.advanceLine();
    await h.request(const DialogueCursorMoved(1));
    await pumpBox(tester);
    // The highlighted option has the cursor arrow.
    final arrow = find.byIcon(Icons.arrow_right);
    expect(arrow, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(DialogueChoiceList.optionKey(1)),
        matching: arrow,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Say nothing'));
    expect(selected, [0, 2]);
  });

  testWidgets('a tap sent as DialogueAdvanceRequested advances the '
      'dialogue (what a game screen does)', (tester) async {
    await h.start('intro');
    await h.tick(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogueBoxWidget(
            state: h.state,
            onAdvance: () => h.send(const DialogueAdvanceRequested()),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(DialogueBoxWidget.boxKey));
    await h.tick();
    expect(h.state.currentLine!.text, 'Pick one.');
  });
}
