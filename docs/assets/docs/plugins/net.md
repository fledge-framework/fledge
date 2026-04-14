# Networking

The `fledge_net` package provides multiplayer networking for Fledge games. It includes a UDP transport layer, a host/client connection model, entity state synchronization, and client-side input prediction.

> **Early Stage** — This package is functional but has known limitations. Delta compression is stubbed (full state is sent each update) and reliable delivery is not yet enforced. See [Limitations](#limitations) below.

## Installation

Add `fledge_net` to your `pubspec.yaml`:

```yaml
dependencies:
  fledge_net: ^0.1.0
```

## Quick Start

```dart
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

void main() {
  final app = App()
    .addPlugin(NetworkPlugin(
      config: NetworkConfig(
        mode: NetworkMode.host,
        tickRate: 60,
        syncRate: 20,
      ),
    ));

  await app.tick();
}
```

## NetworkMode

The `NetworkMode` enum determines the role of the local instance:

| Mode | Description |
|------|-------------|
| `offline` | No networking (default) |
| `host` | Authoritative server — accepts connections, runs simulation |
| `client` | Connects to a host, receives state updates |

## NetworkConfig

```dart
NetworkConfig(
  mode: NetworkMode.host,       // offline, host, or client
  tickRate: 60,                 // Server simulation rate (Hz)
  syncRate: 20,                 // State sync broadcast rate (Hz)
  interpolationDelay: 100.0,    // Client-side interpolation delay (ms)
)
```

## Host / Client Architecture

Fledge uses a **host-authoritative** model. The host runs the game simulation and broadcasts state to clients. Clients send input and predict locally.

### Hosting a Game

```dart
final host = NetworkHost(transport: UdpTransport());
await host.start(7777);

// Listen for connections
host.onPeerConnected.listen((event) {
  print('Player ${event.peer.id} joined');
});

host.onPeerDisconnected.listen((event) {
  print('Player ${event.peer.id} left: ${event.reason}');
});

// Receive client data
host.onData.listen((event) {
  if (event.type == PacketType.input) {
    // Process client input
  }
});

// Each frame
host.update();  // Check timeouts, retransmit
host.broadcast(PacketType.stateUpdate, stateBytes);
```

The host generates a random 6-character `roomCode` on creation for lobby/matchmaking use.

### Connecting as a Client

```dart
final client = NetworkClient(transport: UdpTransport());
await client.connect('192.168.1.100', 7777);

client.onStateChange.listen((event) {
  print('Connection: ${event.state}');
});

client.onData.listen((event) {
  if (event.type == PacketType.stateUpdate) {
    // Update interpolation buffers
  }
});

// Each frame
client.update();  // Ping, timeout check
client.send(PacketType.input, inputBytes);
```

Client states: `disconnected` → `connecting` → `connected` → `failed`.

### Connection Handshake

1. Client sends a `connect` packet
2. Host checks capacity — sends `connectRejected` if full
3. If accepted, host creates a `Peer` and sends `connectAccepted` with the assigned peer ID
4. Client transitions to `connected`

## NetworkIdentity

Mark entities for network replication with the `NetworkIdentity` component:

```dart
final entity = world.spawn()
  ..insert(NetworkIdentity(
    netId: registry.generateNetId(),
    ownerId: 0,          // 0 = host-owned, >0 = client peer ID
    hasAuthority: true,
    spawnType: 'player',
  ))
  ..insert(NetworkSyncConfig(
    syncedComponents: {ComponentId.of<Position>()},
    syncRate: 20,
  ));
```

The `NetworkEntityRegistry` resource provides bidirectional entity ↔ netId lookups:

```dart
final registry = world.getResource<NetworkEntityRegistry>()!;
registry.register(entity, netId);

final entity = registry.getEntity(netId);
final netId = registry.getNetId(entity);
```

## State Synchronization

State is serialized via the `NetworkState` interface:

```dart
abstract class NetworkState {
  void serialize(PacketBuilder builder);
  void deserialize(PacketReader reader);
}
```

The built-in `TransformNetworkState` syncs position and rotation (7 floats, 28 bytes):

```dart
final state = TransformNetworkState()
  ..x = position.x
  ..y = position.y
  ..z = position.z;
```

### Client-Side Interpolation

Clients render entities slightly in the past to smooth out network jitter:

```dart
entity.insert(NetworkInterpolation(
  interpolationDelay: 100,  // ms behind server time
));

// In your system — add incoming state snapshots
interpolation.addState(serverTick, receivedState);

// Each frame — interpolate between buffered snapshots
interpolation.update(DateTime.now().millisecondsSinceEpoch);
final smoothed = interpolation.currentState;
```

## Input Prediction

Clients predict locally and reconcile when the server confirms:

```dart
final prediction = ClientPrediction();

// Each frame — record input and predicted state
final input = InputFrame(tick: prediction.nextTick())
  ..moveX = controller.moveX
  ..moveY = controller.moveY
  ..setButton(InputButton.primaryAction, firing);

prediction.recordInput(input, predictedState);

// Send unacknowledged inputs to host
final unacked = prediction.getUnackedInputs();
client.send(PacketType.input, serializeInputs(unacked));

// When server state arrives — reconcile
final inputsToReplay = prediction.reconcile(serverTick, serverState);
// Re-simulate from server state using replayed inputs
```

### InputFrame

Each input frame captures a tick's worth of player input:

- Movement: `moveX`, `moveY`, `moveZ` (normalized -1..1)
- Look: `lookX`, `lookY`
- Buttons: 32-bit bitfield via `setButton()` / `isButtonPressed()`
- Custom data: optional `Uint8List` for game-specific input

Predefined button indices: `primaryAction`, `secondaryAction`, `jump`, `crouch`, `sprint`, `interact`, `reload`, `pause`.

### Server-Side Input Processing

```dart
final inputQueue = ServerInputQueue();

// When input arrives from a client
inputQueue.addFrames(receivedFrames);

// Each tick — process the next input
final frame = inputQueue.getNextFrame(currentTick);
if (frame != null) {
  applyInput(frame);
}
```

## Packet Protocol

Packets use a 20-byte header with a "FLEG" magic number:

| Field | Size | Description |
|-------|------|-------------|
| Magic | 4 bytes | `0x464C4547` ("FLEG") |
| Version | 1 byte | Protocol version (currently 1) |
| Type | 1 byte | PacketType enum |
| Sequence | 2 bytes | Packet sequence number |
| Ack | 2 bytes | Last received sequence from remote |
| AckBits | 4 bytes | Bitmap of last 32 received sequences |
| Timestamp | 4 bytes | Milliseconds for RTT calculation |
| Reserved | 2 bytes | Reserved for future use |

### PacketType

```
connect, connectAccepted, connectRejected, disconnect,
ping, pong,
stateUpdate, input, entitySpawn, entityDespawn,
rpc, custom
```

### Serialization Helpers

`PacketBuilder` and `PacketReader` provide typed serialization:

```dart
final builder = PacketBuilder()
  ..writeFloat32(position.x)
  ..writeFloat32(position.y)
  ..writeString(playerName)
  ..writeBool(isAlive);

final reader = PacketReader(data);
final x = reader.readFloat32();
final y = reader.readFloat32();
final name = reader.readString();
final alive = reader.readBool();
```

## NetworkPlugin

The plugin registers core resources into the ECS world:

```dart
App()
  .addPlugin(NetworkPlugin(
    config: NetworkConfig(
      mode: NetworkMode.host,
      tickRate: 60,
      syncRate: 20,
    ),
  ));
```

Resources inserted:
- `NetworkConfig` — mode, tick rate, sync rate
- `NetworkTick` — current server and local tick counters
- `NetworkEntityRegistry` — entity ↔ netId mapping

You create your own systems to drive the host/client, poll for data, and sync state.

## Limitations

This package is at **Early Stage** maturity. Known limitations:

| Priority | Limitation |
|----------|-----------|
| **P1** | Delta compression is stubbed — every state update sends the full transform (28 bytes per entity). Not viable for large player counts. |
| **P1** | Reliable delivery is not enforced — ack/retransmit logic exists but critical packets (RPC, spawn/despawn) may be dropped. |
| **P2** | No encryption — all packets are plaintext. |
| **P2** | No authentication — no handshake validation. |
| **P2** | No congestion control — no rate limiting or bandwidth throttling. |
| **P3** | No interest management — all clients receive all entity state. |
| **P3** | Host-only authority — no client-authoritative or shared authority model. |

## API Reference

### NetworkConfig

| Property | Type | Description |
|----------|------|-------------|
| `mode` | `NetworkMode` | offline, host, or client |
| `tickRate` | `int` | Server simulation rate in Hz (default: 60) |
| `syncRate` | `int` | State broadcast rate in Hz (default: 20) |
| `interpolationDelay` | `double` | Client interpolation delay in ms (default: 100) |

### NetworkHost

| Method | Description |
|--------|-------------|
| `start(port)` | Bind and start listening |
| `stop()` | Disconnect all peers and close |
| `update()` | Process timeouts and retransmissions |
| `sendTo(peerId, type, data)` | Send to one peer |
| `broadcast(type, data)` | Send to all connected peers |
| `broadcastExcept(excludeId, type, data)` | Broadcast excluding one peer |
| `disconnectPeer(id, reason)` | Force disconnect a peer |

### NetworkClient

| Method | Description |
|--------|-------------|
| `connect(host, port)` | Connect to a host |
| `disconnect()` | Disconnect from host |
| `update()` | Process pings and timeouts |
| `send(type, data)` | Send data to host |
| `state` | Current `ClientState` |
| `rtt` | Round-trip time in ms |

### NetworkIdentity

| Property | Type | Description |
|----------|------|-------------|
| `netId` | `int` | Unique network entity ID |
| `ownerId` | `int` | Owning peer (0 = host) |
| `hasAuthority` | `bool` | Whether this instance can modify |
| `spawnType` | `String?` | Type identifier for remote spawning |

## See Also

- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin system introduction
- [Input Handling](/docs/plugins/input) - Local input processing
