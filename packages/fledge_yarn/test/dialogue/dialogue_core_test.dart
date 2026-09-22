import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialogue_harness.dart';

// The generic dialogue core (lib/src/dialogue/) on its own: YarnPlugin +
// DialogueCorePlugin, driven only by request events.

void main() {
  late DialogueHarness h;
  setUp(() => h = DialogueHarness());

  group('a conversation', () {
    test('start -> lines -> choice -> end, with the events in order', () async {
      await h.start('intro', context: 'guide-npc');
      expect(h.state.isActive, isTrue);
      expect(h.state.startNode, 'intro');
      expect(h.state.nodeName, 'intro');
      expect(h.state.context, 'guide-npc');
      expect(h.state.currentLine!.character, 'Guide');
      expect(h.state.currentLine!.text, 'Hello there!');
      expect(h.state.currentLine!.tags, ['greeting']);

      await h.advanceLine();
      expect(h.state.currentLine!.text, 'Pick one.');
      await h.advanceLine();
      expect(h.state.isWaitingForChoice, isTrue);
      expect(
        h.state.currentLine!.text,
        'Pick one.',
        reason: 'the leading line stays up under the choice',
      );
      expect(h.state.choices.map((c) => c.text), [
        'Warm reply',
        'Cold reply',
        'Say nothing',
      ]);

      await h.request(const DialogueChoiceSelected(0));
      expect(h.commandLog, ['warm']);
      expect(h.state.currentLine!.text, 'Nice.');
      await h.advanceLine();
      expect(h.state.isActive, isFalse);
      expect(h.variables.getBool('intro_done'), isTrue);
      expect(h.commandLog, ['warm', 'end']);

      await h.tick(); // see the last tick's notifications
      expect(h.trace, [
        'started:intro',
        'line:Guide: Hello there!',
        'line:Guide: Pick one.',
        'choices:3',
        'made:0',
        'line:Guide: Nice.',
        'ended:intro',
      ]);
      final ended = h.events.whereType<DialogueEnded>().single;
      expect(ended.context, 'guide-npc');
      expect(ended.skipped, isFalse);
      final made = h.events.whereType<DialogueChoiceMade>().single;
      expect(made.text, 'Warm reply');
      expect(made.tags, ['warm', 'energy_2']);
    });

    test('a line without a speaker has no character', () async {
      await h.start('narration');
      expect(h.state.currentLine!.character, isNull);
      expect(h.state.currentLine!.text, 'Just narration here.');
    });

    test('a node that opens with a choice has no leading line', () async {
      await h.start('opens_with_choice');
      expect(h.state.isWaitingForChoice, isTrue);
      expect(h.state.currentLine, isNull);
      expect(h.state.visibleText, '');
      expect(h.state.choices, hasLength(2));
    });

    test('a start request while a dialogue is active is refused', () async {
      await h.start('intro');
      await h.start('narration');
      expect(h.state.startNode, 'intro');
      expect(h.state.currentLine!.text, 'Hello there!');
      // Two in one tick: the first wins.
      await h.request(const DialogueSkipRequested()); // -> at the choice
      await h.request(const DialogueChoiceSelected(1));
      await h.request(const DialogueSkipRequested()); // -> end
      expect(h.state.isActive, isFalse);
      h
        ..send(const DialogueStartRequested('narration'))
        ..send(const DialogueStartRequested('intro'));
      await h.tick();
      expect(h.state.startNode, 'narration');
      await h.tick();
      expect(h.events.whereType<DialogueStarted>().map((e) => e.node), [
        'intro',
        'narration',
      ]);
    });

    test('an unknown node is refused', () async {
      await h.start('no_such_node');
      expect(h.state.isActive, isFalse);
    });

    test('requests sent in the tick a dialogue starts are ignored (they '
        'predate it)', () async {
      h
        ..send(const DialogueStartRequested('intro'))
        ..send(const DialogueAdvanceRequested())
        ..send(const DialogueSkipRequested());
      await h.tick();
      expect(h.state.currentLine!.text, 'Hello there!');
      expect(h.state.visibleCharacterCount, 0);
    });
  });

  group('typewriter', () {
    test('types at charactersPerSecond on the time source\'s delta', () async {
      await h.start('intro'); // 'Hello there!' (12 characters) at 40 cps
      expect(h.state.visibleText, '');
      expect(h.state.isLineComplete, isFalse);
      await h.tick(0.1); // 4 characters
      expect(h.state.visibleText, 'Hell');
      expect(h.state.typewriterProgress, closeTo(4 / 12, 1e-9));
      await h.tick(0.1);
      expect(h.state.visibleText, 'Hello th');
      await h.tick(1);
      expect(h.state.visibleText, 'Hello there!');
      expect(h.state.isLineComplete, isTrue);
    });

    test(
      'the first advance completes the line, the next one advances',
      () async {
        await h.start('intro');
        await h.tick(0.05);
        expect(h.state.isLineComplete, isFalse);
        await h.request(const DialogueAdvanceRequested());
        expect(h.state.visibleText, 'Hello there!');
        expect(h.state.currentLine!.text, 'Hello there!');
        await h.request(const DialogueAdvanceRequested());
        expect(h.state.currentLine!.text, 'Pick one.');
        expect(h.state.visibleText, '', reason: 'a new line types from 0');
      },
    );

    test('several advances in one tick count as one', () async {
      await h.start('intro');
      h
        ..send(const DialogueAdvanceRequested())
        ..send(const DialogueAdvanceRequested());
      await h.tick();
      expect(h.state.currentLine!.text, 'Hello there!');
      expect(h.state.isLineComplete, isTrue);
    });

    test('charactersPerSecond <= 0 shows lines at once', () async {
      h = DialogueHarness(charactersPerSecond: 0);
      await h.start('intro');
      expect(h.state.isLineComplete, isTrue);
      expect(h.state.visibleText, 'Hello there!');
    });

    test('a pluggable time source', () async {
      final app = App()
        ..insertResource(_FakeClock())
        ..addPlugin(YarnPlugin())
        ..addPlugin(
          DialogueCorePlugin(
            timeSource: DialogueTimeSource(
              resource: _FakeClock,
              delta: (world) => world.getResource<_FakeClock>()!.seconds,
            ),
          ),
        );
      app.world.getResource<YarnProject>()!.parse(
        readYarn('test/dialogue/fixtures/core.yarn'),
      );
      app.world.eventWriter<DialogueStartRequested>().send(
        const DialogueStartRequested('intro'),
      );
      await app.tick();
      app.world.getResource<_FakeClock>()!.seconds = 0.25; // 10 characters
      await app.tick();
      expect(app.world.getResource<DialogueState>()!.visibleText, 'Hello ther');
    });
  });

  group('choices', () {
    Future<void> toChoice() async {
      await h.start('intro');
      await h.advanceLine();
      await h.advanceLine();
      expect(h.state.isWaitingForChoice, isTrue);
    }

    test('carry their tags; the #timeout option is exposed', () async {
      await toChoice();
      expect(h.state.choices[0].tags, ['warm', 'energy_2']);
      expect(h.state.choices[0].hasTag('#warm'), isTrue);
      expect(h.state.choices[1].tags, ['cold']);
      expect(h.state.choices.every((c) => c.isAvailable), isTrue);
      expect(h.state.timeoutChoiceIndex, 2);
      await h.tick();
      final ready = h.events.whereType<DialogueChoicesReady>().single;
      expect(ready.timeoutChoiceIndex, 2);
    });

    test('no #timeout option: timeoutChoiceIndex is null', () async {
      await h.start('skip_chain');
      await h.request(const DialogueSkipRequested());
      expect(h.state.isWaitingForChoice, isTrue);
      expect(h.state.timeoutChoiceIndex, isNull);
    });

    test('DialogueChoiceSelected from any sender (e.g. a timer system) '
        'selects the option', () async {
      await toChoice();
      // An ECS system in `update`, like a choice timer.
      h.app.addSystem(_TimeoutPicker(), schedule: Schedules.update);
      await h.ticks(2);
      expect(h.state.currentLine!.text, '...');
      await h.tick();
      final made = h.events.whereType<DialogueChoiceMade>().single;
      expect(made.index, 2);
      expect(made.tags, ['timeout']);
    });

    test('out-of-range selections are ignored; only the first valid one '
        'per tick applies', () async {
      await toChoice();
      await h.request(const DialogueChoiceSelected(7));
      expect(h.state.isWaitingForChoice, isTrue);
      h
        ..send(const DialogueChoiceSelected(-1))
        ..send(const DialogueChoiceSelected(1))
        ..send(const DialogueChoiceSelected(0));
      await h.tick();
      expect(h.state.currentLine!.text, 'Oh.');
    });

    test('the cursor wraps; advance takes the highlighted option', () async {
      await toChoice();
      expect(h.state.cursorIndex, 0);
      await h.request(const DialogueCursorMoved(-1));
      expect(h.state.cursorIndex, 2);
      await h.request(const DialogueCursorMoved(1));
      await h.request(const DialogueCursorMoved(1));
      expect(h.state.cursorIndex, 1);
      await h.request(const DialogueAdvanceRequested());
      expect(h.state.currentLine!.text, 'Oh.');
      expect(h.state.cursorIndex, 0);
    });

    test('a cursor move and an advance in one tick: the move applies '
        'first', () async {
      await toChoice();
      h
        ..send(const DialogueCursorMoved(1))
        ..send(const DialogueAdvanceRequested());
      await h.tick();
      expect(h.state.currentLine!.text, 'Oh.');
    });
  });

  group('skip', () {
    test('passes over the remaining lines, runs every command and <<set>>, '
        'and stops at the next choice', () async {
      await h.start('skip_chain');
      await h.request(const DialogueSkipRequested());
      expect(h.commandLog, ['a']);
      expect(h.variables.getNumber('mid'), 1);
      expect(h.state.isWaitingForChoice, isTrue);
      expect(h.state.currentLine!.text, 'Three.');
      expect(h.state.isLineComplete, isTrue);
      expect(h.variables.hasVariable('chain_done'), isFalse);
    });

    test('with a choice pending it does nothing (Esc at a choice)', () async {
      await h.start('skip_chain');
      await h.request(const DialogueSkipRequested());
      await h.request(const DialogueSkipRequested());
      await h.request(const DialogueSkipRequested());
      expect(h.state.isActive, isTrue);
      expect(h.state.isWaitingForChoice, isTrue);
      expect(h.state.currentLine!.text, 'Three.');
      expect(h.variables.hasVariable('chain_done'), isFalse);
    });

    test('after the choice, runs the trailing commands and <<set>> and '
        'ends (skipped)', () async {
      await h.start('skip_chain');
      await h.request(const DialogueSkipRequested());
      await h.request(const DialogueChoiceSelected(0));
      expect(h.state.currentLine!.text, 'After.');
      await h.request(const DialogueSkipRequested());
      expect(h.state.isActive, isFalse);
      expect(h.commandLog, ['a', 'b']);
      expect(h.variables.getBool('chain_done'), isTrue);
      await h.tick();
      expect(h.trace, [
        'started:skip_chain',
        'line:Guide: One.',
        'choices:1',
        'made:0',
        'line:Guide: After.',
        'ended*:skip_chain',
      ]);
    });

    test('a skip in the same tick as other requests wins', () async {
      await h.start('skip_chain');
      h
        ..send(const DialogueAdvanceRequested())
        ..send(const DialogueSkipRequested());
      await h.tick();
      expect(h.state.isWaitingForChoice, isTrue);
      expect(h.state.cursorIndex, 0);
    });
  });

  group('<<declare>>', () {
    test('seeds a variable that has no value', () async {
      await h.start('declared');
      expect(h.state.isActive, isFalse, reason: 'nothing to show');
      expect(h.variables.getBool('seed_flag'), isTrue);
      expect(h.variables.getNumber('seed_count'), 5);
    });

    test('never overwrites an existing value', () async {
      h.variables
        ..setBool('seed_flag', false)
        ..setNumber('seed_count', 42);
      await h.start('declared');
      expect(h.variables.getBool('seed_flag'), isFalse);
      expect(h.variables.getNumber('seed_count'), 42);
    });

    test('handles the `as Type` form and ignores malformed ones', () {
      final storage = h.variables;
      expect(
        declareCommand(storage, ['\$typed', '=', '3', 'as', 'Number']),
        isTrue,
      );
      expect(storage.getNumber('typed'), 3);
      expect(declareCommand(storage, ['nonsense']), isTrue);
      expect(storage.variableNames, ['typed']);
    });
  });

  group('run conditions', () {
    test(
      'dialogueActive / unlessDialogueActive follow DialogueState',
      () async {
        expect(dialogueActive(h.world), isFalse);
        expect(unlessDialogueActive(h.world), isTrue);
        await h.start('intro');
        expect(dialogueActive(h.world), isTrue);
        expect(unlessDialogueActive(h.world), isFalse);
        expect(dialogueActive(World()), isFalse, reason: 'no DialogueState');
        expect(unlessDialogueActive(World()), isTrue);
      },
    );
  });

  test('DialogueCorePlugin needs YarnPlugin first', () {
    expect(() => App().addPlugin(DialogueCorePlugin()), throwsStateError);
  });
}

class _FakeClock {
  double seconds = 0;
}

/// Picks the pending choice's #timeout option, like a choice timer would.
class _TimeoutPicker implements System {
  @override
  SystemMeta get meta => const SystemMeta(
    name: '_TimeoutPicker',
    resourceReads: {DialogueState},
    eventWrites: {DialogueChoiceSelected},
    after: dialogueCoreSystemNames,
  );

  @override
  RunCondition? get runCondition => dialogueActive;

  @override
  bool shouldRun(World world) => dialogueActive(world);

  @override
  Future<void> run(World world) {
    final index = world.getResource<DialogueState>()!.timeoutChoiceIndex;
    if (index != null) {
      world.eventWriter<DialogueChoiceSelected>().send(
        DialogueChoiceSelected(index),
      );
    }
    return Future.value();
  }
}
