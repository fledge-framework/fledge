import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:test/test.dart';

/// Batch 8 #31 — a pausing command handler holds the runner until
/// resume() is called. Statements between the pausing command and the
/// next line / choice must NOT run before resume.
void main() {
  test(
    'commands after a pausing command do not run until resume() is called',
    () {
      final project = YarnProject();
      project.parse('''
title: start
---
<<pauseHere>>
<<record afterPause>>
Character: Post-resume line.
===
''');

      final ran = <String>[];
      final commands = CommandHandler();
      commands.registerPausing('pauseHere', (command, args) {
        ran.add('pauseHere');
        return true;
      });
      commands.register('record', (command, args) {
        ran.add('record ${args.join(" ")}');
        return true;
      });

      DialogueLine? lastLine;
      final runner = DialogueRunner(
        project: project,
        variableStorage: VariableStorage(),
        commandHandler: commands,
        onLine: (line) => lastLine = line,
      );

      expect(runner.startNode('start'), isTrue);
      // Pausing command ran; nothing after it should have.
      expect(runner.state, DialogueRunnerState.paused);
      expect(ran, ['pauseHere']);
      expect(lastLine, isNull);

      // Resume: the record command and the post-resume line now run.
      runner.resume();
      expect(ran, ['pauseHere', 'record afterPause']);
      expect(runner.state, DialogueRunnerState.line);
      expect(lastLine?.text, contains('Post-resume line'));
    },
  );

  test('resume() is a no-op when not paused', () {
    final project = YarnProject();
    project.parse('''
title: start
---
Character: Only line.
===
''');
    final runner = DialogueRunner(
      project: project,
      variableStorage: VariableStorage(),
    );
    runner.startNode('start');
    expect(runner.state, DialogueRunnerState.line);
    runner.resume();
    expect(runner.state, DialogueRunnerState.line);
  });

  test(
    'CommandHandler.hasPausingHandler distinguishes pausing from regular',
    () {
      final commands = CommandHandler();
      commands.register('regular', (_, _) => true);
      commands.registerPausing('holding', (_, _) => true);
      expect(commands.hasPausingHandler('regular'), isFalse);
      expect(commands.hasPausingHandler('holding'), isTrue);
      // hasHandler still returns true for both, matching the pre-fix
      // semantic that "there is _some_ handler for this command".
      expect(commands.hasHandler('regular'), isTrue);
      expect(commands.hasHandler('holding'), isTrue);
    },
  );
}
