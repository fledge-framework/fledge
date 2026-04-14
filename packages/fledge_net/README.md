# fledge_net

Networking components for the [Fledge](https://fledge-framework.dev) game framework — multiplayer with host/client architecture, state synchronization, and input prediction.

## Features

- **Transport abstraction** — UDP-based with pluggable backends and encrypted transport wrapper
- **Host/client architecture** — authoritative server model with connection management
- **Reliable delivery** — critical packets (connect, disconnect, RPC, spawn/despawn) are retransmitted until acknowledged
- **Delta compression** — bitmask-based field change detection, only modified fields are sent
- **Authentication** — password or custom authenticator callback during connection handshake
- **Encryption** — pluggable packet encryption (XOR-based, replaceable with AES-GCM)
- **Congestion control** — AIMD algorithm with RTT-adaptive retransmit timeout
- **Interest management** — radius-based spatial filtering for selective state broadcast
- **Authority model** — entity ownership tracking with authority transfer
- **State synchronization** — host broadcasts world state to clients with interpolation
- **Input prediction** — client-side prediction with server reconciliation

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
