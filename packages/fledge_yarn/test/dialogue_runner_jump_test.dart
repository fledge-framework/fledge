import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:test/test.dart';

/// Batch 8 #31 — a `<<jump>>` to a missing node used to leave the
/// previous line visible while incrementing the line index. Now the
/// runner logs the miss and ends the dialogue.
void main() {
  test('jump to a missing node ends the dialogue and clears the line', () {
    final project = YarnProject();
    project.parse('''
title: start
---
Character: This line should not remain visible.
<<jump nowhere>>
Character: This line is unreachable.
===
''');

    DialogueLine? lastLine;
    bool ended = false;
    final runner = DialogueRunner(
      project: project,
      variableStorage: VariableStorage(),
      onLine: (line) => lastLine = line,
      onDialogueEnd: () => ended = true,
    );

    expect(runner.startNode('start'), isTrue);
    // The first line is shown. Advance to hit the jump.
    expect(runner.state, DialogueRunnerState.line);
    expect(lastLine?.text, isNotNull);
    runner.advance();

    // Post-jump: the runner cleared the current line, ended the
    // dialogue, and fired onDialogueEnd exactly once.
    expect(runner.state, DialogueRunnerState.ended);
    expect(runner.currentDialogueLine, isNull);
    expect(ended, isTrue);
  });
}
