import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialogue_harness.dart';

// The dialogue core's holding commands (registerHoldingCommand /
// DialogueHoldReleased) and DialogueStopRequested — the generic contribution
// to fledge_yarn (design §8.1).

DialogueHarness _harness({List<String>? requested}) {
  final h = DialogueHarness(
    yarnFiles: const ['test/dialogue/fixtures/hold.yarn'],
    charactersPerSecond: 0, // lines appear whole
  );
  registerHoldingCommand(h.commands, h.world, 'wait_for', (arguments) {
    requested?.add(arguments.join(' '));
    return arguments.isEmpty ? null : arguments.first;
  });
  return h;
}

void main() {
  group('holding commands', () {
    test(
      'hold the dialogue until released, then show what comes next',
      () async {
        final requested = <String>[];
        final h = _harness(requested: requested);
        await h.start('hold_line');
        expect(h.state.currentLine?.text, 'Before.');
        await h.request(const DialogueAdvanceRequested());

        expect(requested, ['tape']);
        expect(h.state.isActive, isTrue);
        expect(h.state.isHeld, isTrue);
        expect(h.state.holdTokens, ['tape']);
        expect(h.state.currentLine, isNull, reason: 'nothing shown while held');
        expect(h.state.isWaitingForChoice, isFalse);

        // Requests are ignored while held.
        await h.request(const DialogueAdvanceRequested());
        await h.request(const DialogueSkipRequested());
        await h.ticks(10);
        expect(h.state.isHeld, isTrue);

        // An unknown token doesn't release it.
        await h.request(const DialogueHoldReleased('other'));
        expect(h.state.isHeld, isTrue);

        await h.request(const DialogueHoldReleased('tape'));
        expect(h.state.isHeld, isFalse);
        expect(h.state.currentLine?.text, 'After.');
        await h.tick();
        expect(h.trace.last, 'line:Host: After.');
      },
    );

    test(
      'a hold inside a choice body; the choice is announced first',
      () async {
        final h = _harness();
        await h.start('hold_choice');
        await h.request(const DialogueAdvanceRequested());
        expect(h.state.isWaitingForChoice, isTrue);
        await h.request(const DialogueChoiceSelected(0));
        expect(h.state.isHeld, isTrue);
        await h.request(const DialogueHoldReleased('tape'));
        expect(h.state.currentLine?.text, 'Chose A.');
        await h.tick();
        expect(h.trace, contains('made:0'));
      },
    );

    test(
      'a hold before the end: DialogueEnded only after the release',
      () async {
        final h = _harness();
        await h.start('hold_end');
        await h.request(const DialogueAdvanceRequested());
        await h.ticks(3);
        expect(h.state.isActive, isTrue);
        expect(h.events.whereType<DialogueEnded>(), isEmpty);
        await h.request(const DialogueHoldReleased('tape'));
        expect(h.state.isActive, isFalse);
        await h.tick();
        expect(h.trace.last, 'ended:hold_end');
      },
    );

    test('skip stops at a hold', () async {
      final h = _harness();
      await h.start('hold_line');
      await h.request(const DialogueSkipRequested());
      expect(h.state.isHeld, isTrue);
      await h.request(const DialogueHoldReleased('tape'));
      expect(h.state.currentLine?.text, 'After.');
    });

    test(
      'commands after a hold do NOT run until the release (pausing runner)',
      () async {
        final h = _harness();
        await h.start('hold_then_log');
        await h.request(const DialogueAdvanceRequested());
        expect(h.state.isHeld, isTrue);
        // The pausing runner (item 31b) defers everything after the
        // holding command until release, so `<<log ran>>` has NOT run.
        expect(h.commandLog, isEmpty);
        await h.request(const DialogueHoldReleased('tape'));
        expect(h.commandLog, ['ran']);
        expect(h.state.currentLine?.text, 'Two.');
      },
    );

    test('a null token does not hold', () async {
      final h = _harness();
      await h.start('no_hold');
      await h.request(const DialogueAdvanceRequested());
      expect(h.state.isHeld, isFalse);
      expect(h.state.currentLine?.text, 'Two.');
    });
  });

  group('DialogueStopRequested', () {
    test('ends the dialogue at once (stopped), dropping a hold', () async {
      final h = _harness();
      await h.start('hold_line', context: 'ctx');
      await h.request(const DialogueAdvanceRequested());
      expect(h.state.isHeld, isTrue);
      await h.request(const DialogueStopRequested(context: 'ctx'));
      expect(h.state.isActive, isFalse);
      expect(h.state.isHeld, isFalse);
      await h.tick();
      final ended = h.events.whereType<DialogueEnded>().single;
      expect(ended.stopped, isTrue);
      expect(ended.skipped, isFalse);
      expect(ended.context, 'ctx');
      // A late release is harmless.
      await h.request(const DialogueHoldReleased('tape'));
      expect(h.state.isActive, isFalse);
    });

    test('with a context, only stops the dialogue with that context', () async {
      final h = _harness();
      await h.start('hold_line', context: 'mine');
      await h.request(const DialogueStopRequested(context: 'theirs'));
      expect(h.state.isActive, isTrue);
      await h.request(const DialogueStopRequested());
      expect(h.state.isActive, isFalse);
    });

    test('a context stop applies even on the start tick; a context-less one '
        'does not (it predates the dialogue)', () async {
      final h = _harness();
      h
        ..send(const DialogueStartRequested('hold_line', context: 'c'))
        ..send(const DialogueStopRequested());
      await h.tick();
      await h.tick();
      expect(h.state.isActive, isTrue);
      await h.request(const DialogueStopRequested());
      expect(h.state.isActive, isFalse);
    });
  });

  test('DialogueChoiceMade carries the dialogue context', () async {
    final h = _harness();
    await h.start('hold_choice', context: 42);
    await h.request(const DialogueAdvanceRequested());
    await h.request(const DialogueChoiceSelected(1));
    await h.tick();
    final made = h.events.whereType<DialogueChoiceMade>().single;
    expect(made.context, 42);
    expect(made.tags, ['timeout']);
  });
}
