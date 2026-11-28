# Dialogue (Yarn)

`fledge_yarn` runs branching dialogue written in
[Yarn Spinner](https://yarnspinner.dev/)'s script format. It has two layers:

- **`YarnPlugin`**: the parser and runtime. It holds the parsed nodes
  (`YarnProject`), the dialogue variables (`VariableStorage`) and your custom
  commands (`CommandHandler`).
- **`DialogueCorePlugin`**: the event-driven layer most games use. It runs
  the active dialogue from request events (start, continue, choose, skip,
  stop), keeps a `DialogueState` resource with a typewriter effect for your
  UI, announces what happened with notification events, and can hold the
  dialogue while a cutscene or minigame plays.

A ready-made `DialogueBoxWidget` draws the current line and choices.

## What you need

```yaml
dependencies:
  fledge_yarn: ^0.7.1
```

- Flutter 3.50+ (Dart `^3.14`): the package depends on Flutter for its
  widgets, even if you only use the runtime. Desktop first (Windows, macOS,
  Linux); web and mobile are best-effort.
- `YarnPlugin` before `DialogueCorePlugin`. Adding `DialogueCorePlugin`
  without it throws a `StateError`.
- `WallTimePlugin`, for the typewriter. It types by `WallTime.delta`; with no
  `WallTime` resource the delta is 0 and lines never finish typing on their
  own (a continue request still completes them).

<!-- snippet-setup
class StartMinigame {
  final String name;
  const StartMinigame(this.name);
}

class WaitTimer {
  double remaining = 0;
}

class Inventory {
  final items = <String>[];
}
-->

## Quick start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter/services.dart';

const greeting = '''
title: sara_greeting
---
Sara: Hey there! Welcome to town.
-> I'm looking for work.
    Sara: You've come to the right place!
    <<set \$lookingForWork = true>>
-> Just exploring.
    Sara: Enjoy your stay!
===
''';

Future<App> buildApp() async {
  final app = App()
    ..addPlugin(WallTimePlugin())
    ..addPlugin(YarnPlugin(initialContent: greeting))
    ..addPlugin(DialogueCorePlugin());

  // More files can be added at any time.
  final project = app.world.getResource<YarnProject>()!;
  project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));

  // Talk to Sara (from an interaction system, usually).
  app.world.eventWriter<DialogueStartRequested>().send(
    const DialogueStartRequested('sara_greeting', context: 'sara'),
  );
  return app;
}
```

`rootBundle` needs `WidgetsFlutterBinding.ensureInitialized()` (or
`runApp`) first. Tick the app from a widget, as in
[Rendering](/docs/rendering/overview#driving-the-app-from-a-widget), and draw
the dialogue with the [dialogue box widget](#the-dialogue-box-widget).

## Writing Yarn

```text
title: shopkeeper
tags: npc town
---
// Comments start with two slashes.
<<declare $gold = 100>>
Shopkeeper: Welcome! You have {$gold} gold. #greeting
-> Buy the sword <<if $gold >= 50>>
    <<set $gold -= 50>>
    <<give_item sword>>
    Shopkeeper: Fine choice.
-> Just looking.
    <<jump goodbye>>
===
```

| Feature | Syntax |
|---|---|
| Node | `title: name`, optional `tags: a b` and other `key: value` headers, then `---` ... `===` |
| Line | `Character: text`, or plain `text` for narration |
| Line tags | `#tag` (letters, digits, underscore; `#a:b` is the tag `a`). `#line:id` sets `lineId` |
| Inline expression | `{$gold}`, `{$gold - 5}`. Whole numbers print without a decimal point; `\{` is a literal brace |
| Choice | `-> text`, with an optional `<<if cond>>` and tags. The body is indented 4 spaces (or a tab) deeper |
| Conditional | `<<if cond>>` ... `<<elseif cond>>` ... `<<else>>` ... `<<endif>>` |
| Variables | `<<set $x = expr>>` (or Yarn Spinner's `<<set $x to expr>>`), also `+=`, `-=`, `*=`, `/=`. Strings are quoted and may contain spaces and `\"` escapes: `<<set $name = "Alex Smith">>` |
| Jump / end | `<<jump node>>`, `<<stop>>` |
| Custom command | `<<name arg1 arg2>>` |

Expressions support numbers, strings, booleans, `null`, `$variables`,
arithmetic (`+ - * / %`, `+` also joins strings), comparisons and
`and`/`or`/`not`, with the usual precedence and parentheses. A typo doesn't
crash a scene, and none passes silently: a malformed condition counts as false
and a malformed `<<set>>` changes nothing, each logging a warning (logger
`fledge_yarn.variables`); a malformed `<<declare>>` changes nothing and logs
a warning on logger `dialogue`. `VariableStorage.executeSet` returns whether
it applied.

Not supported: Yarn functions (`visited()`, `dice()` and so on), `<<once>>`,
line groups, and smart variables. Choice text isn't interpolated. An unset
variable interpolates as `null`. A choice whose condition fails is dropped from the list; if none is left the choice
set is skipped.

### Built-in commands

| Command | Behaviour |
|---|---|
| `<<set ...>>` | Sets a variable |
| `<<jump node>>` | Continues at another node. A missing node logs and ends the dialogue |
| `<<stop>>` | Ends the dialogue (`DialogueRunner.onDialogueEnd` is called once) |
| `<<declare $x = value>>` | Registered by `DialogueCorePlugin`: sets `$x` **only if it has no value yet**, so replaying the node (or loading a save) never resets progress. An `as Type` suffix is accepted |
| `<<wait ...>>` | Does nothing unless you register a handler for `wait` (see [Holding commands](#holding-commands)) |

`declare` and `wait` are ordinary command names, so registering your own
handler overrides them.

As in Yarn Spinner, the keywords (`set`, `jump`, `stop`, `declare`, `if`,
`elseif`, `else`, `endif`) are lowercase and case-sensitive: `<<Stop>>` is
not the built-in but a custom command named `Stop`.

## The event-driven layer

### Requests

Send these from any system, or from a widget between ticks. Only the two
dialogue systems read them.

| Event | Effect |
|---|---|
| `DialogueStartRequested(node, context:)` | Starts at `node`. Refused (and logged) while another dialogue is active, or if the node doesn't exist. `context` is any value you want carried along, such as the NPC being talked to |
| `DialogueAdvanceRequested()` | "Continue": finishes typing the line, else moves to the next line; with a choice up, picks the highlighted choice. Several in one frame count as one |
| `DialogueChoiceSelected(index)` | Picks a choice. Ignored unless a choice is up and `index` is in range |
| `DialogueCursorMoved(delta)` | Moves the highlight by `delta`, wrapping (arrow keys, d-pad) |
| `DialogueCursorSet(index)` | Moves the highlight to `index` (a hovering pointer) |
| `DialogueSkipRequested()` | Fast-forwards: passes over every line, running every command and `<<set>>`, until the next choice or the end. Does nothing while a choice is up |
| `DialogueStopRequested(context:)` | Ends the dialogue now, running nothing more. With a `context`, only a dialogue started with that context stops |
| `DialogueHoldReleased(token)` | Releases a hold (see [Holding commands](#holding-commands)) |

Requests read in the frame a dialogue starts are ignored, because they were
sent before it existed. The exception is a stop naming that dialogue's
context.

### Notifications

| Event | Sent when |
|---|---|
| `DialogueStarted(node, context:)` | A dialogue started |
| `DialogueLineShown(line)` | A new line is up (not for lines a skip passes over). `line` is a `DialogueLine` with `character`, `text`, `tags` and `lineId` |
| `DialogueChoicesReady(choices)` | A choice is waiting. `timeoutChoiceIndex` is the index of a choice tagged `#timeout`, for timed choices |
| `DialogueChoiceMade(index, text:, tags:, context:)` | A choice was taken |
| `DialogueEnded(node, context:, skipped:, stopped:)` | The dialogue ended. `skipped`: fast-forwarded to the end; `stopped`: cut short by a stop request |

Requests sent by a system are read on the next frame, and notifications are
readable the frame after they're sent (see
[Events](/docs/ecs/events#timing-events-are-double-buffered)).

```dart
final giveQuest = FunctionSystem(
  'giveQuest',
  eventReads: {DialogueChoiceMade},
  run: (world) {
    for (final choice in world.eventReader<DialogueChoiceMade>().read()) {
      if (choice.context == 'sara' && choice.tags.contains('accept')) {
        // Start the quest.
      }
    }
  },
);
```

### DialogueState

The presentation-facing view of the active dialogue. Only the dialogue
systems change it; everything else reads it.

| Member | Meaning |
|---|---|
| `isActive` | A dialogue is running |
| `startNode`, `nodeName` | The node it started at, and the node running now (changes on `<<jump>>`) |
| `context` | The start request's `context` |
| `currentLine` | The line on screen; while a choice is up, the line that led to it (null if the node opened with the choice) |
| `visibleText`, `visibleCharacterCount`, `typewriterProgress`, `isLineComplete` | Typewriter progress of `currentLine` |
| `isWaitingForChoice`, `choices`, `cursorIndex` | The pending choice: a list of `DialogueChoice` (`text`, `tags`, `hasTag()`) and the highlighted index |
| `timeoutChoiceIndex` | The pending choice tagged `#timeout`, or null |
| `isHeld`, `holdTokens` | Whether a holding command is holding the dialogue, and its tokens |
| `charactersPerSecond` | Typing speed |

`DialogueChoice.isAvailable` is always true: unavailable options never reach
the list.

Gate systems on it with the `dialogueActive` run condition, or its inverse
`unlessDialogueActive` (true when there's no `DialogueState`):

```dart
final playerMovement = FunctionSystem(
  'playerMovement',
  runIf: unlessDialogueActive,
  run: (world) {
    // Freeze the player while someone is talking.
  },
);
```

A dialogue isn't saved: it doesn't survive save and load. The variables do,
separately (see [Variables and saving](#variables-and-saving)).

### Options and ordering

```dart
final plugin = DialogueCorePlugin(
  charactersPerSecond: 60, // 0 or less shows each line at once
  schedule: Schedules.update, // the default
  commandAccess: const DialogueCommandAccess(
    resourceWrites: {Inventory},
    eventWrites: {StartMinigame},
  ),
);
```

The plugin adds `DialogueStartSystem` and then `DialogueAdvanceSystem` to
`schedule`. Your command handlers run inside those systems, so declare what
they write in `commandAccess`. The systems put it on their `SystemMeta`, and
the scheduler can order them against the systems that react. Prefer handlers
that only send events; list a resource in `resourceWrites` only if a handler
writes it directly.

To order your systems around both, use `dialogueCoreSystemNames` (or the
`DialogueStartSystem.systemName` and `DialogueAdvanceSystem.systemName`
constants):

```dart
final dialogueHud = FunctionSystem(
  'dialogueHud',
  resourceReads: {DialogueState},
  after: dialogueCoreSystemNames,
  run: (world) {
    // Show the latest DialogueState this frame.
  },
);
```

`timeSource` sets where the typewriter's per-frame delta comes from. The
default, `DialogueTimeSource.wallTime`, reads `WallTime.delta`. Pass a
`DialogueTimeSource(resource: MyClock, delta: (world) => ...)` to type on
another clock.

## Commands

### Custom commands

Register handlers on the `CommandHandler` resource. A handler gets the
command name as written in the script and its arguments, split on spaces,
and returns whether it handled the command. A quoted run (`"two words"`) stays
one argument without its quotes, `""` is an empty argument, and inside quotes
`\"` and `\\` write a quote and a backslash. Custom command names match
case-insensitively (`<<Give_Item>>` reaches a `give_item` handler).

```dart
final app = App()
  ..addPlugin(YarnPlugin())
  ..addPlugin(
    DialogueCorePlugin(
      commandAccess: const DialogueCommandAccess(resourceWrites: {Inventory}),
    ),
  )
  ..insertResource(Inventory());

final world = app.world;
world.getResource<CommandHandler>()!.register('give_item', (command, args) {
  if (args.isEmpty) return false;
  world.getResource<Inventory>()!.items.add(args.first);
  return true;
});
```

A command with no handler is ignored.

### Holding commands

Some commands must wait for the game: a cutscene, a minigame, a timed pause.
`registerHoldingCommand` registers one. When the dialogue reaches it, your
callback runs; return a token to **hold** the dialogue, or null not to.

While held, `isHeld` is true, nothing is shown (`currentLine` is null, no
choices) and every request except a stop is ignored. Commands after the
holding command don't run yet. When a `DialogueHoldReleased` with every token
arrives, from any system, the dialogue continues with the next line, choice
or end.

This gives `<<wait 2>>` real meaning:

```dart
final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(YarnPlugin())
  ..addPlugin(DialogueCorePlugin())
  ..insertResource(WaitTimer());

final world = app.world;
registerHoldingCommand(world.getResource<CommandHandler>()!, world, 'wait', (
  args,
) {
  final seconds = double.tryParse(args.isEmpty ? '' : args.first);
  if (seconds == null) return null; // malformed: don't hold
  world.getResource<WaitTimer>()!.remaining = seconds;
  return 'wait';
});

app.addSystem(
  FunctionSystem(
    'waitTimer',
    resourceReads: {WallTime},
    resourceWrites: {WaitTimer},
    eventWrites: {DialogueHoldReleased},
    run: (world) {
      final timer = world.getResource<WaitTimer>()!;
      if (timer.remaining <= 0) return;
      timer.remaining -= world.getResource<WallTime>()!.delta;
      if (timer.remaining <= 0) {
        world.eventWriter<DialogueHoldReleased>().send(
          const DialogueHoldReleased('wait'),
        );
      }
    },
  ),
);
```

Usually the callback sends an event that starts the awaited thing (declare it
in `commandAccess.eventWrites`), and the system running that thing sends the
release when it's done. Several holds can be in place at once; the dialogue
resumes when all are released. A stop request drops them. A holding command
reached outside an active dialogue is logged and ignored.

Under the hood this uses the runtime's pausing handlers
(`CommandHandler.registerPausing`, `hasPausingHandler`, and
`DialogueRunner.resume()`). A plain pausing handler that pauses during a
`DialogueCorePlugin` dialogue holds it too, with the command's name (as
written in the script) as the token: send `DialogueHoldReleased('name')` to
continue. Prefer `registerHoldingCommand`, which lets you pick the token and
ignores the command outside a dialogue.

## The dialogue box widget

`DialogueBoxWidget` draws a `DialogueState`: the speaker, the typed-so-far
line, an optional portrait, the choices with the highlight, and a continue
hint. It only reports taps; you turn them into requests. It draws nothing
when no dialogue is active, or while one is held.

```dart
import 'package:fledge_ecs/fledge_ecs.dart' hide State;
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Rebuilt every frame by the widget that ticks the app.
class DialogueOverlay extends StatelessWidget {
  const DialogueOverlay({super.key, required this.app, required this.frame});

  final App app;
  final ValueListenable<int> frame;

  @override
  Widget build(BuildContext context) {
    final world = app.world;
    return ValueListenableBuilder<int>(
      valueListenable: frame,
      builder: (context, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DialogueBoxWidget(
            state: world.getResource<DialogueState>()!,
            speakerLabel: (id) => id == 'sara' ? 'Sara' : null,
            onAdvance: () => world.eventWriter<DialogueAdvanceRequested>().send(
              const DialogueAdvanceRequested(),
            ),
            onChoiceSelected: (i) => world
                .eventWriter<DialogueChoiceSelected>()
                .send(DialogueChoiceSelected(i)),
            onChoiceHovered: (i) => world.eventWriter<DialogueCursorSet>().send(
              DialogueCursorSet(i),
            ),
          ),
        ),
      ),
    );
  }
}
```

| Parameter | Meaning |
|---|---|
| `state` | The `DialogueState` to draw |
| `theme` | A `DialogueBoxTheme` |
| `speakerLabel` | Maps a line's `character` to a display name (null, or returning null: as written) |
| `portraitBuilder` | `(context, line) => Widget?`, shown left of the text |
| `headerTrailing` | A widget at the right of the speaker row, such as an affinity meter |
| `onAdvance`, `onChoiceSelected`, `onChoiceHovered` | Tap on the box (not while a choice is up), tap on a choice, pointer entering a choice |

`DialogueBoxTheme` sets colours, text styles, padding and the minimum text
height. `frameBuilder: (context, child) => ...` replaces the default
rectangle (for a nine-slice frame, say), `continueHint` sets the hint under
a finished line (null hides it), and `continueHintBuilder` draws the hint
yourself, for example with a controller button icon. `DialogueChoiceList`
is the choice list on its own, for any dialogue-styled prompt.

For keyboard or controller input, send `DialogueCursorMoved` and
`DialogueAdvanceRequested` from your input system (see
[Input](/docs/platform/input)).

## Variables and saving

`VariableStorage` holds the dialogue variables, by name with or without the
`$`:

```dart
final storage = VariableStorage()
  ..setNumber('gold', 100)
  ..setBool('hasKey', true)
  ..setString('name', 'Alex');

final gold = storage.getNumber('gold'); // 100.0
final hasKey = storage.getBool('hasKey');
final greeting = storage.interpolate('You have {\$gold} gold.');

// Save and restore.
final json = storage.toJson();
storage.loadFromJson(json); // replaces every variable
```

`getInt`, `getValue`, `hasVariable`, `setValue`, `remove`, `clear`,
`evaluateCondition` and `executeSet` round it out. `YarnPlugin` takes
`initialVariables:` to seed it. To persist variables, store `toJson()` in a
saved resource of your own (see [Save & Load](/docs/gameplay/save)); pair it
with `<<declare>>` so a loaded game keeps its values.

## Using the runner directly

Without `DialogueCorePlugin`, drive a `DialogueRunner` yourself, for
example in a tool or a test:

```dart
final project = YarnProject()
  ..parse('''
title: start
---
Narrator: Pick one.
-> Left
    You went left.
-> Right
    You went right.
===
''');

final runner = DialogueRunner(
  project: project,
  variableStorage: VariableStorage(),
  commandHandler: CommandHandler(),
);
runner.startNode('start');

while (runner.canContinue) {
  switch (runner.state) {
    case DialogueRunnerState.line:
      print(runner.currentDialogueLine);
      runner.advance();
    case DialogueRunnerState.choices:
      runner.selectChoice(0);
    default:
      break;
  }
}
```

The runner also takes `onLine`, `onChoices`, `onCommand`, `onDialogueEnd`
and `onNodeStart` callbacks, and tracks `nodeHistory`.
`world.createDialogueRunner()` builds one from the `YarnPlugin` resources.

The runner's state enum is `DialogueRunnerState` (`inactive`, `line`,
`choices`, `paused`, `ended`). Before the event-driven layer was added it
was called `DialogueState`, a name that now belongs to the resource; rename
`switch` cases and `runner.state == ...` checks when upgrading from 0.2.x.

## See also

- [Events](/docs/ecs/events)
- [States & Run Conditions](/docs/ecs/states-run-conditions)
- [Input](/docs/platform/input)
- [fledge_yarn API reference](https://pub.dev/documentation/fledge_yarn/latest/)
