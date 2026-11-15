import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:test/test.dart';

/// `<<wait>>` is a Yarn built-in the game handles: with a handler
/// registered it reaches it (and a pausing one pauses the runner); with
/// none it's a no-op.
void main() {
  YarnProject project() => YarnProject()
    ..parse('''
title: start
---
<<wait 2>>
Character: After the wait.
===
''');

  test('a game handler for wait is called, and can pause', () {
    final calls = <List<String>>[];
    final commands = CommandHandler()
      ..registerPausing('wait', (command, arguments) {
        calls.add(arguments);
        return true;
      });
    DialogueLine? line;
    final runner = DialogueRunner(
      project: project(),
      variableStorage: VariableStorage(),
      commandHandler: commands,
      onLine: (l) => line = l,
    );
    runner.startNode('start');
    expect(calls, [
      ['2'],
    ]);
    expect(runner.state, DialogueRunnerState.paused);
    expect(line, isNull);
  });

  test('without a handler, wait does nothing', () {
    DialogueLine? line;
    final runner = DialogueRunner(
      project: project(),
      variableStorage: VariableStorage(),
      commandHandler: CommandHandler(),
      onLine: (l) => line = l,
    );
    runner.startNode('start');
    expect(line?.text, 'After the wait.');
  });
}
