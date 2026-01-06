# fledge_yarn

[Yarn Spinner](https://yarnspinner.dev/) dialogue system for [Fledge](https://fledge-framework.dev) games. Parse `.yarn` files and run interactive dialogues with branching narratives.

[![pub package](https://img.shields.io/pub/v/fledge_yarn.svg)](https://pub.dev/packages/fledge_yarn)

## Features

- **Yarn Parsing**: Load `.yarn` files with full syntax support
- **Dialogue Runtime**: Step through dialogue with choices and branching
- **Variables**: Store and evaluate dialogue state
- **Commands**: Execute custom game commands from dialogue
- **Conditionals**: Branch dialogue based on conditions
- **ECS Integration**: Plugin and resources for Fledge games

## Installation

```yaml
dependencies:
  fledge_yarn: ^0.1.0
```

## Quick Start

### 1. Create a Yarn File

```yarn
title: greeting
---
Sara: Hey there! Welcome to town.
Sara: How can I help you today?
-> I'm looking for work.
    Sara: You've come to the right place!
    <<set $lookingForWork = true>>
-> Just exploring.
    Sara: Enjoy your stay!
===
```

### 2. Load and Run Dialogue

```dart
import 'package:fledge_yarn/fledge_yarn.dart';

// Parse Yarn content
final project = YarnProject();
project.parse(yarnContent);

// Create storage for variables
final storage = VariableStorage();

// Run dialogue
final runner = DialogueRunner(
  project: project,
  variableStorage: storage,
);

runner.startNode('greeting');

while (runner.canContinue) {
  switch (runner.state) {
    case DialogueState.line:
      final line = runner.currentDialogueLine!;
      print('${line.character}: ${line.text}');
      runner.advance();
      break;

    case DialogueState.choices:
      for (var i = 0; i < runner.currentChoices.length; i++) {
        print('$i: ${runner.currentChoices[i].text}');
      }
      // Player selects a choice
      runner.selectChoice(playerSelection);
      break;
  }
}
```

### 3. ECS Integration

```dart
final app = App()
  ..addPlugin(YarnPlugin());

// Load dialogue files
final project = app.world.getResource<YarnProject>()!;
project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));

// Create a runner when needed
final runner = app.world.createDialogueRunner();
runner?.startNode('sara_greeting');
```

## Yarn Syntax

### Nodes

```yarn
title: my_node
tags: important quest
---
// Node content goes here
===
```

### Dialogue Lines

```yarn
Sara: Hello there!        // Character speaking
This is narration.        // No character prefix
Sara: How are you? #happy // With tags
```

### Choices

```yarn
What do you want to do?
-> Go left
    You went left.
-> Go right
    You went right.
-> Stay here <<if $canStay>>
    You stayed.
```

### Commands

```yarn
<<set $gold = 100>>           // Set variable
<<set $gold += 50>>           // Modify variable
<<jump other_node>>           // Jump to another node
<<give_item sword>>           // Custom command
<<stop>>                      // End dialogue
```

### Conditionals

```yarn
<<if $hasKey>>
    You unlock the door.
<<else>>
    The door is locked.
<<endif>>
```

### Variables

```yarn
<<set $name = "Alex">>
<<set $gold = 100>>
<<set $hasKey = true>>

<<if $gold >= 50>>
    You can afford it!
<<endif>>
```

## Custom Commands

Register handlers for game-specific commands:

```dart
final commands = world.getResource<CommandHandler>()!;

commands.register('give_item', (command, args) {
  if (args.isNotEmpty) {
    inventory.addItem(args[0]);
  }
  return true;
});

commands.register('friendship', (command, args) {
  if (args.isNotEmpty) {
    final change = int.tryParse(args[0]) ?? 0;
    relationshipManager.addFriendship(currentNpc, change);
  }
  return true;
});
```

Then use in Yarn:

```yarn
<<give_item sword>>
<<friendship 15>>
```

## Variables API

```dart
final storage = VariableStorage();

// Set values
storage.setNumber('gold', 100);
storage.setBool('hasKey', true);
storage.setString('name', 'Alex');

// Get values
final gold = storage.getNumber('gold');      // 100
final hasKey = storage.getBool('hasKey');    // true
final name = storage.getString('name');      // "Alex"

// Evaluate conditions
final canBuy = storage.evaluateCondition('\$gold >= 50'); // true

// Serialize for save/load
final json = storage.toJson();
storage.loadFromJson(json);
```

## Runner Callbacks

```dart
final runner = DialogueRunner(
  project: project,
  variableStorage: storage,
  onLine: (line) {
    // Display dialogue line
    dialogueBox.showText(line.character, line.text);
  },
  onChoices: (choices) {
    // Display choices
    dialogueBox.showChoices(choices);
  },
  onCommand: (command, args) {
    // Handle commands not registered with CommandHandler
    print('Command: $command $args');
  },
  onDialogueEnd: () {
    // Clean up dialogue UI
    dialogueBox.hide();
  },
);
```

## Documentation

See the [Dialogue Guide](https://fledge-framework.dev/docs/plugins/yarn) for detailed documentation.

## Related Packages

- [fledge_ecs](https://pub.dev/packages/fledge_ecs) - Core ECS framework
- [fledge_input](https://pub.dev/packages/fledge_input) - Input handling
- [fledge_audio](https://pub.dev/packages/fledge_audio) - Audio playback

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
