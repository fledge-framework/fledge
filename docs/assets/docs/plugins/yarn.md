# Yarn Dialogue

The `fledge_yarn` plugin provides a Yarn Spinner dialogue system for branching narratives in Fledge games. Parse `.yarn` files and run interactive dialogues with choices, variables, and custom commands.

## Installation

Add `fledge_yarn` to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_yarn: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';

void main() async {
  final app = App()
    .addPlugin(YarnPlugin());

  // Initialize
  await app.tick();

  // Load dialogue files
  final project = app.world.getResource<YarnProject>()!;
  project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));

  // Create a runner when starting dialogue
  final runner = app.world.createDialogueRunner()!;
  runner.startNode('greeting');

  runApp(MyGameApp(app: app));
}
```

## Creating Yarn Files

Yarn files use a simple, readable format for writing dialogue:

```yarn
title: greeting
tags: npc tutorial
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

### Node Structure

Each dialogue node has:
- **title**: Unique identifier for the node
- **tags**: Optional metadata (space-separated)
- **content**: Dialogue lines, choices, commands between `---` and `===`

## Dialogue Lines

### Character Lines

```yarn
Sara: Hello there!        // Character speaking
```

### Narration

```yarn
The sun was setting over the village.  // No character prefix
```

### With Tags

```yarn
Sara: I'm so happy! #emotion:happy #animation:wave
```

## Choices

Choices let players make decisions that affect the dialogue:

```yarn
What do you want to do?
-> Go left
    You went left and found a treasure chest.
-> Go right
    You went right and encountered a monster.
-> Stay here <<if $canStay>>
    You decided to wait.
```

### Conditional Choices

Choices can be hidden based on conditions:

```yarn
-> Buy the sword <<if $gold >= 50>>
    You purchased the sword!
    <<set $gold -= 50>>
```

## Commands

Commands execute game logic from within dialogue:

### Built-in Commands

```yarn
<<set $gold = 100>>           // Set a variable
<<set $gold += 50>>           // Modify a variable
<<jump other_node>>           // Jump to another node
<<stop>>                      // End dialogue immediately
```

### Custom Commands

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
    relationships.addFriendship(currentNpc, change);
  }
  return true;
});
```

Then use in Yarn:

```yarn
<<give_item sword>>
<<friendship 15>>
```

## Conditionals

Branch dialogue based on conditions:

```yarn
<<if $hasKey>>
    You unlock the door and step through.
<<elseif $hasLockpick>>
    You carefully pick the lock.
<<else>>
    The door is locked tight.
<<endif>>
```

### Supported Operators

| Operator | Description |
|----------|-------------|
| `==` | Equals |
| `!=` | Not equals |
| `<` | Less than |
| `<=` | Less than or equal |
| `>` | Greater than |
| `>=` | Greater than or equal |
| `and` | Logical AND |
| `or` | Logical OR |
| `not` | Logical NOT |

## Variables

### Setting Variables

```yarn
<<set $name = "Alex">>      // String
<<set $gold = 100>>         // Number
<<set $hasKey = true>>      // Boolean
<<set $gold += 50>>         // Add to number
<<set $gold -= 25>>         // Subtract from number
```

### Variable Storage API

```dart
final storage = world.getResource<VariableStorage>()!;

// Set values
storage.setNumber('gold', 100);
storage.setBool('hasKey', true);
storage.setString('name', 'Alex');

// Get values
final gold = storage.getNumber('gold');      // 100
final hasKey = storage.getBool('hasKey');    // true
final name = storage.getString('name');      // "Alex"

// Serialize for save/load
final json = storage.toJson();
storage.loadFromJson(json);
```

## Running Dialogue

### Creating a Runner

```dart
final runner = world.createDialogueRunner();
runner?.startNode('greeting');
```

### Stepping Through Dialogue

```dart
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

### Runner Callbacks

```dart
final runner = DialogueRunner(
  project: project,
  variableStorage: storage,
  onLine: (line) {
    dialogueBox.showText(line.character, line.text);
  },
  onChoices: (choices) {
    dialogueBox.showChoices(choices);
  },
  onCommand: (command, args) {
    print('Unhandled command: $command $args');
  },
  onDialogueEnd: () {
    dialogueBox.hide();
  },
  onNodeStart: (nodeTitle) {
    print('Starting node: $nodeTitle');
  },
);
```

## Plugin Configuration

### Default Setup

```dart
YarnPlugin()
```

### With Initial Content

```dart
YarnPlugin(
  initialContent: yarnFileContent,
  initialVariables: {
    'gold': 100,
    'hasKey': false,
  },
)
```

## Game Integration Example

Here's how to integrate yarn dialogue in a typical game:

### Dialogue State Resource

Create a game-specific wrapper around the runner:

```dart
class GameDialogueState {
  DialogueRunner? _runner;
  NpcId? currentNpcId;
  String displayText = '';
  double typewriterProgress = 0.0;

  bool get isActive => _runner != null &&
      _runner!.state != DialogueState.ended;

  void startDialogue(NpcId npcId, DialogueRunner runner, String node) {
    currentNpcId = npcId;
    _runner = runner;
    runner.startNode(node);
    _updateFromRunner();
  }

  void advance() {
    if (_runner == null) return;
    _runner!.advance();
    _updateFromRunner();
  }

  void selectChoice(int index) {
    if (_runner == null) return;
    _runner!.selectChoice(index);
    _updateFromRunner();
  }

  void _updateFromRunner() {
    if (_runner?.state == DialogueState.line) {
      final line = _runner!.currentDialogueLine!;
      displayText = line.text;
      typewriterProgress = 0.0;
    }
  }
}
```

### NPC Interaction System

```dart
@system
void npcInteractionSystem(World world) {
  final dialogue = world.getResource<GameDialogueState>();
  final project = world.getResource<YarnProject>();
  final storage = world.getResource<VariableStorage>();
  final commands = world.getResource<CommandHandler>();

  if (dialogue == null || dialogue.isActive) return;

  for (final (entity, npc, _) in world.query2<Npc, InteractionEvent>().iter()) {
    // Create runner with registered commands
    final runner = DialogueRunner(
      project: project!,
      variableStorage: storage!,
      commandHandler: commands,
    );

    // Start dialogue for this NPC
    final startNode = '${npc.id.name}_greeting';
    dialogue.startDialogue(npc.id, runner, startNode);

    world.remove<InteractionEvent>(entity);
    break;
  }
}
```

## Resources Reference

| Resource | Description |
|----------|-------------|
| `YarnProject` | Parsed yarn nodes and metadata |
| `VariableStorage` | Dialogue variable state |
| `CommandHandler` | Custom command registry |

## Classes Reference

| Class | Description |
|-------|-------------|
| `DialogueRunner` | Runtime execution engine |
| `DialogueLine` | A line of dialogue with character and text |
| `Choice` | A selectable choice option |
| `YarnNode` | A parsed dialogue node |

## Yarn Syntax Summary

| Feature | Syntax |
|---------|--------|
| Node header | `title: node_name` |
| Node tags | `tags: tag1 tag2` |
| Node start | `---` |
| Node end | `===` |
| Dialogue | `Character: Text` |
| Choice | `-> Choice text` |
| Conditional choice | `-> Text <<if $condition>>` |
| Set variable | `<<set $var = value>>` |
| Jump to node | `<<jump node_name>>` |
| If/else | `<<if $cond>>...<<else>>...<<endif>>` |
| Custom command | `<<command arg1 arg2>>` |

## See Also

- [Plugins Overview](/docs/plugins/overview) - Plugin system introduction
- [Input Handling](/docs/plugins/input) - Handle player input for dialogue navigation
- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin architecture details
