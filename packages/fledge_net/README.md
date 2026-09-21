# fledge_net

Multiplayer networking for [Fledge](https://fledge-framework.dev) games — host/client architecture, encrypted transport, state synchronization, and client-side input prediction.

[![pub package](https://img.shields.io/pub/v/fledge_net.svg)](https://pub.dev/packages/fledge_net)

## Installation

```yaml
dependencies:
  fledge_net: ^0.2.1
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

final app = App()
  ..addPlugin(WallTimePlugin())
  ..addPlugin(NetworkPlugin(
    config: NetworkConfig(
      mode: NetworkMode.host,
      tickRate: 60,
      syncRate: 20,
    ),
  ));

await app.run();
```

## Documentation

See the [Fledge documentation site](https://fledge-framework.dev/docs/plugins/net) for guides, API reference, and advanced usage.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
