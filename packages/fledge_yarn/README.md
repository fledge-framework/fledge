# fledge_yarn

[Yarn Spinner](https://yarnspinner.dev/) dialogue system for [Fledge](https://fledge-framework.dev) games. Parse `.yarn` files and run interactive dialogues with branching narratives.

[![pub package](https://img.shields.io/pub/v/fledge_yarn.svg)](https://pub.dev/packages/fledge_yarn)

## Installation

```yaml
dependencies:
  fledge_yarn: ^0.2.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_yarn/fledge_yarn.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  final app = App()..addPlugin(YarnPlugin());

  final project = app.world.getResource<YarnProject>()!;
  project.parse(await rootBundle.loadString('assets/dialogue/npcs.yarn'));

  final runner = app.world.createDialogueRunner();
  runner?.startNode('sara_greeting');

  await app.run();
}
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/yarn) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
