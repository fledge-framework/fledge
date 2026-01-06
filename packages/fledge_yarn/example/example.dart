// ignore_for_file: avoid_print
import 'package:fledge_yarn/fledge_yarn.dart';

/// Example demonstrating basic Yarn dialogue usage.
void main() {
  // Sample Yarn dialogue content
  const yarnContent = '''
title: greeting
---
Sara: Hello! Welcome to the village.
Sara: How can I help you today?
-> I'm looking for work.
    Sara: Great! Talk to the mayor.
-> Just passing through.
    Sara: Safe travels!
===
''';

  // Parse the Yarn content
  final project = YarnProject();
  project.parse(yarnContent);

  // Create variable storage
  final storage = VariableStorage();

  // Create and start dialogue runner
  final runner = DialogueRunner(
    project: project,
    variableStorage: storage,
  );

  runner.startNode('greeting');

  // Step through the dialogue
  while (runner.canContinue) {
    switch (runner.state) {
      case DialogueState.line:
        final line = runner.currentDialogueLine!;
        if (line.character != null) {
          print('${line.character}: ${line.text}');
        } else {
          print(line.text);
        }
        runner.advance();
        break;

      case DialogueState.choices:
        print('\nChoices:');
        for (var i = 0; i < runner.currentChoices.length; i++) {
          print('  $i: ${runner.currentChoices[i].text}');
        }
        // Select first choice for demo
        runner.selectChoice(0);
        break;

      default:
        break;
    }
  }

  print('\nDialogue complete!');
}
