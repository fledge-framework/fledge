# fledge_net

Networking components for the [Fledge](https://fledge-framework.dev) game framework — peer-to-peer multiplayer, state synchronization, and input prediction.

## Features

- **Transport abstraction** — UDP-based with pluggable backends
- **Host/client architecture** — authoritative server model with connection management
- **Protocol layer** — packet framing, sequencing, and ack tracking
- **State synchronization** — host broadcasts world state to clients
- **Input prediction** — client-side prediction with server reconciliation
- **Network identity** — entity replication with ownership tracking

## Status

**Early Stage** — functional for prototyping but not production-ready. See [limitations](https://fledge-framework.dev/docs/plugins/net#limitations) in the documentation.

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

final app = App()
  .addPlugin(NetworkPlugin(
    config: NetworkConfig(
      mode: NetworkMode.host,
      tickRate: 60,
      syncRate: 20,
    ),
  ));
```

## Documentation

See the [Networking guide](https://fledge-framework.dev/docs/plugins/net) for full documentation.

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
