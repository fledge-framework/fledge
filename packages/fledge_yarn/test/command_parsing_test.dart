import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dialogue/dialogue_harness.dart';

DialogueRunner _run(
  String body, {
  CommandHandler? commands,
  VariableStorage? storage,
  void Function()? onEnd,
}) {
  final project = YarnProject()..parse('title: start\n---\n$body\n===\n');
  final runner = DialogueRunner(
    project: project,
    variableStorage: storage ?? VariableStorage(),
    commandHandler: commands,
    onDialogueEnd: onEnd,
  );
  runner.startNode('start');
  return runner;
}

void main() {
  group('<<set>> string values', () {
    test('keep spaces', () {
      final storage = VariableStorage();
      _run(r'<<set $name = "Alex Smith">>', storage: storage);
      expect(storage.getValue('name'), 'Alex Smith');
    });

    test('keep escaped quotes', () {
      final storage = VariableStorage();
      _run(r'<<set $quote = "She said \"hi\" twice">>', storage: storage);
      expect(storage.getValue('quote'), 'She said "hi" twice');
    });

    test('stay strings when they look like other literals', () {
      final storage = VariableStorage();
      _run('<<set \$flag = "true">>\n<<set \$n = "5">>', storage: storage);
      expect(storage.getValue('flag'), 'true');
      expect(storage.getValue('n'), '5');
    });

    test('keep runs of spaces', () {
      final storage = VariableStorage();
      _run(r'<<set $s = "a  b">>', storage: storage);
      expect(storage.getValue('s'), 'a  b');
    });

    test('a malformed set reports failure instead of applying', () {
      final storage = VariableStorage();
      expect(storage.executeSet(r'$x = = 1'), isFalse);
      expect(storage.hasVariable('x'), isFalse);
      expect(storage.executeSet(r'$x = 1'), isTrue);
    });
  });

  test('<<declare>> keeps string defaults with spaces', () async {
    final h = DialogueHarness(yarnFiles: const []);
    h.project.parse('''
title: declare
---
<<declare \$name = "Alex Smith" as String>>
Done.
===
''');
    await h.start('declare');
    expect(h.variables.getValue('name'), 'Alex Smith');
  });

  group('generic command arguments', () {
    late List<List<String>> calls;
    late CommandHandler commands;
    setUp(() {
      calls = [];
      commands = CommandHandler()
        ..register('say', (command, args) {
          calls.add(args);
          return true;
        });
    });

    test('quoted runs stay together without their quotes', () {
      _run(r'<<say "hello there" world "" "a \"b\"">>', commands: commands);
      expect(calls.single, ['hello there', 'world', '', 'a "b"']);
    });
  });

  group('<<stop>>', () {
    test('calls onDialogueEnd once', () {
      var ended = 0;
      final runner = _run('Before.\n<<stop>>\nAfter.', onEnd: () => ended++);
      runner.advance();
      expect(runner.state, DialogueRunnerState.ended);
      expect(ended, 1);
    });

    test('a handler calling stop() ends it once too', () {
      var ended = 0;
      late DialogueRunner runner;
      final commands = CommandHandler()
        ..register('quit', (_, _) {
          runner.stop();
          return true;
        });
      final project = YarnProject()
        ..parse('title: start\n---\n<<quit>>\nAfter.\n===\n');
      runner = DialogueRunner(
        project: project,
        variableStorage: VariableStorage(),
        commandHandler: commands,
        onDialogueEnd: () => ended++,
      );
      runner.startNode('start');
      expect(runner.state, DialogueRunnerState.ended);
      expect(ended, 1);
    });

    test('a later run of the same runner processes commands normally', () {
      var ended = 0;
      final storage = VariableStorage();
      final runner = _run('<<stop>>', storage: storage, onEnd: () => ended++);
      runner.project.parse('title: second\n---\n<<set \$x = 1>>\nLine.\n===\n');
      runner.startNode('second');
      expect(storage.getValue('x'), 1);
      expect(runner.state, DialogueRunnerState.line);
      expect(ended, 1);
    });
  });

  group('built-in keywords are case-sensitive (Yarn Spinner)', () {
    test('<<Stop>> is a custom command, not the built-in', () {
      final seen = <String>[];
      final commands = CommandHandler()
        ..register('stop', (command, args) {
          seen.add(command);
          return true;
        });
      final runner = _run('<<Stop>>\nStill here.', commands: commands);
      expect(seen, ['Stop'], reason: 'name passed as written');
      expect(runner.state, DialogueRunnerState.line);
      expect(runner.currentDialogueLine?.text, 'Still here.');
    });

    test('<<SET>> does not assign', () {
      final storage = VariableStorage();
      _run(
        r'<<SET $x = 1>>'
        '\nLine.',
        storage: storage,
      );
      expect(storage.hasVariable('x'), isFalse);
    });

    test('<<stop>> in lowercase is the built-in', () {
      final runner = _run('<<stop>>\nNever.');
      expect(runner.state, DialogueRunnerState.ended);
    });

    test('<<Declare>> is not the built-in declare', () async {
      final h = DialogueHarness(yarnFiles: const []);
      h.project.parse('''
title: d
---
<<Declare \$x = 1>>
Done.
===
''');
      await h.start('d');
      expect(h.variables.hasVariable('x'), isFalse);
    });

    test('custom command names still match case-insensitively', () {
      final seen = <String>[];
      final commands = CommandHandler()
        ..register('give_item', (command, args) {
          seen.add('$command ${args.join(' ')}');
          return true;
        });
      _run('<<Give_Item sword>>\nLine.', commands: commands);
      expect(seen, ['Give_Item sword']);
    });
  });
}
