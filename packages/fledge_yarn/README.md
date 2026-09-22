# fledge_yarn

[Yarn Spinner](https://yarnspinner.dev/) dialogue system for [Fledge](https://fledge-framework.dev) games. Parse `.yarn` files and run interactive dialogues with branching narratives.

[![pub package](https://img.shields.io/pub/v/fledge_yarn.svg)](https://pub.dev/packages/fledge_yarn)

## Installation

```yaml
dependencies:
  fledge_yarn: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  final app = App()
    ..addPlugin(YarnPlugin())
    ..addPlugin(DialogueCorePlugin()); // event-driven dialogue layer

  final project = app.world.getResource<YarnProject>()!;
  project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));

  app.world.eventWriter<DialogueStartRequested>().send(
    const DialogueStartRequested('sara_greeting'),
  );

  await app.run();
}
```

`DialogueCorePlugin` adds a `DialogueState` resource, a set of request /
notification events, holding-command support (`registerHoldingCommand`),
and the `DialogueBoxWidget` — see the plugin docs for the full API.

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/yarn) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
