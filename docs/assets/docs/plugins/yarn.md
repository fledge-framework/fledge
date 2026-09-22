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

Tags attach metadata to a line for the game to react to:

```yarn
Sara: I'm so happy! #excited #wave
```

**Tag grammar.** Tags match `#(\w+)` — a `#` followed by one or more
letters, digits or underscores. The tag ends at the first character
that isn't one of those, so a colon or a dot terminates the tag:

- `#energy_2` → one tag `energy_2`.
- `#energy:2` → one tag `energy`; the `:2` is not part of the tag.
- `#quest.step1` → one tag `quest`.

Games that need composite values should use underscores
(`#quest_step_1`) or split into multiple tags (`#quest #step_1`).

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

Expressions use a real recursive-descent parser with standard precedence (low → high):

| Precedence | Operators | Description |
|------------|-----------|-------------|
| 1 (lowest) | `or` | Logical OR (short-circuits) |
| 2 | `and` | Logical AND (short-circuits) |
| 3 | `not` | Logical NOT |
| 4 | `==` `!=` `<` `<=` `>` `>=` | Comparisons |
| 5 | `+` `-` | Addition / subtraction (also string concat when either side is a string) |
| 6 | `*` `/` `%` | Multiplication / division / modulo |
| 7 | unary `-` `+` | Negation |
| 8 (highest) | `(` `)` | Parentheses for grouping |

Examples:

```yarn
<<if $count > 1 + 2 * 3>>        // evaluates to 7 (multiplication first)
<<if ($hp + 10) * 2 <= $maxHp>>  // parentheses force order
<<if $hasKey and not $doorLocked>>
```

Arithmetic works everywhere — conditions, `<<set>>`, and inline expressions. Malformed expressions return `false` from conditions / no-op from `<<set>>` so a typo doesn't crash dialogue mid-run. Use `ExpressionEvaluator` directly if you want hard errors.

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
    case DialogueRunnerState.line:
      final line = runner.currentDialogueLine!;
      print('${line.character}: ${line.text}');
      runner.advance();
      break;

    case DialogueRunnerState.choices:
      for (var i = 0; i < runner.currentChoices.length; i++) {
        print('$i: ${runner.currentChoices[i].text}');
      }
      // Player selects a choice
      runner.selectChoice(playerSelection);
      break;
  }
}
```

> **Breaking change in v0.3.0.** The runner-state enum was renamed from
> `DialogueState` to `DialogueRunnerState` to make room for the new
> `DialogueState` resource (see below). Update `switch` cases and any
> `runner.state == ...` checks in the same PR you bump `fledge_yarn`.

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

## Event-driven dialogue layer

Since v0.3.0 `fledge_yarn` ships an event-driven layer on top of
`DialogueRunner` — no per-game wrapper needed. `DialogueCorePlugin`
adds a `DialogueState` resource (typewriter, current line, pending
choices, hold state), a set of request events (start, advance, choose,
skip, stop, hold-release), notification events (started, line shown,
choices ready, choice made, ended), and two systems that drive the
runner from those events.

### Setup

```dart
final app = App()
  ..addPlugin(YarnPlugin())            // provides YarnProject etc.
  ..addPlugin(DialogueCorePlugin());   // adds DialogueState + systems
```

Register your custom Yarn commands on `CommandHandler` as usual.

### Starting and advancing dialogue

Every mutation is an event, sent from any system:

```dart
world.eventWriter<DialogueStartRequested>().send(
  DialogueStartRequested('greeting', context: npcId),
);
```

Read the presentation-facing state from anywhere:

```dart
final state = world.getResource<DialogueState>()!;
if (state.isActive) {
  print(state.visibleText); // typewriter progress
}
```

Advance and choose:

```dart
world.eventWriter<DialogueAdvanceRequested>().send(
  const DialogueAdvanceRequested(),
);

world.eventWriter<DialogueChoiceSelected>().send(
  const DialogueChoiceSelected(0),
);
```

### Holding commands

A holding command pauses the dialogue until the game releases it — a
minigame, a cutscene, a timed beat. Register a handler and hand back a
token:

```dart
final commands = world.getResource<CommandHandler>()!;
registerHoldingCommand(commands, world, 'rhythm_segment', (arguments) {
  world.eventWriter<StartRhythmSegment>().send(
    StartRhythmSegment(arguments),
  );
  return 'rhythm'; // token that identifies this hold
});
```

Yarn:

```yarn
Host: Cue up the rhythm.
<<rhythm_segment easy>>
Host: Nice work.
```

When the minigame is done, release the hold:

```dart
world.eventWriter<DialogueHoldReleased>().send(
  const DialogueHoldReleased('rhythm'),
);
```

Holds use the pausing command callback, so commands between the holding
command and the next line do **not** run until release.

### Dialogue box widget

`DialogueBoxWidget` reads a `DialogueState` and reports taps through
callbacks — style it with `DialogueBoxTheme`:

```dart
DialogueBoxWidget(
  state: world.getResource<DialogueState>()!,
  onAdvance: () => world.eventWriter<DialogueAdvanceRequested>()
      .send(const DialogueAdvanceRequested()),
  onChoiceSelected: (i) => world.eventWriter<DialogueChoiceSelected>()
      .send(DialogueChoiceSelected(i)),
)
```

### Run conditions

Gate gameplay systems while dialogue is up:

```dart
app.addSystem(
  npcSteeringSystem,
  schedule: Schedules.update,
  runCondition: unlessDialogueActive,
);
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
| `DialogueRunner` | Runtime execution engine (`nodeHistory`, `reset()`) |
| `DialogueLine` | A line of dialogue with character and text |
| `Choice` | A selectable choice option |
| `YarnNode` | A parsed dialogue node (`hasTag()`, `getHeader()`) |

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
