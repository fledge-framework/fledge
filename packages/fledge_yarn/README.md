# fledge_yarn

[Yarn Spinner](https://yarnspinner.dev/) dialogue system for [Fledge](https://fledge-framework.dev) games. Parse `.yarn` files and run interactive dialogues with branching narratives.

[![pub package](https://img.shields.io/pub/v/fledge_yarn.svg)](https://pub.dev/packages/fledge_yarn)

## Installation

```yaml
dependencies:
  fledge_yarn: ^0.7.2
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter/services.dart';

Future<App> buildApp() async {
  final app = App()
    ..addPlugin(WallTimePlugin()) // drives the typewriter
    ..addPlugin(YarnPlugin()) // YarnProject, VariableStorage, CommandHandler
    ..addPlugin(DialogueCorePlugin()); // event-driven dialogue layer

  // Needs WidgetsFlutterBinding.ensureInitialized() (or runApp) first.
  final project = app.world.getResource<YarnProject>()!;
  project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));

  app.world.eventWriter<DialogueStartRequested>().send(
    const DialogueStartRequested('sara_greeting'),
  );
  return app; // tick it once per Flutter frame from your game widget
}
```

`DialogueCorePlugin` (added after `YarnPlugin`) adds a `DialogueState`
resource with a typewriter, request events (`DialogueAdvanceRequested`,
`DialogueChoiceSelected`, `DialogueSkipRequested`, `DialogueStopRequested`,
...), notification events (`DialogueLineShown`, `DialogueChoicesReady`,
`DialogueEnded`, ...), holding commands (`registerHoldingCommand`) and the
built-in `<<declare>>` command. A plain pausing handler
(`CommandHandler.registerPausing`) holds the dialogue the same way, released
by a `DialogueHoldReleased` carrying the command's name. `DialogueBoxWidget`
draws the current line and choices.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/gameplay/dialogue) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
