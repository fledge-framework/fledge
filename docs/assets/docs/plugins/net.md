# Networking

The `fledge_net` package provides multiplayer networking for Fledge games. It includes a UDP transport layer, a host/client connection model, entity state synchronization, and client-side input prediction.

> This package includes reliable delivery, delta compression, authentication, encryption, congestion control, interest management, and authority tracking. See the feature sections below for details.

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

> **Not yet wired:** `NetworkConfig.serverPassword`, `enableEncryption` and `interestRadius` are stored on the resource but nothing reads them yet — setting them has no effect today. Until the next release wires them up, pass an `authenticator` to `NetworkHost`, wrap your transport in `EncryptedTransport` yourself, and use `InterestManager` directly (all shown below).

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
host.update();  // Check timeouts, ping peers (RTT), retransmit
host.broadcast(PacketType.stateUpdate, stateBytes);
```

`host.update()` pings every peer once per `pingInterval` (default 1 s, first ping on the first update after a peer connects) so `peer.rtt` is measured on the host side too.

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

`connect()` accepts a numeric address or a hostname such as `'localhost'`. Hostnames are resolved with `InternetAddress.lookup` before connecting, preferring an IPv4 result (the UDP transport is IPv4-only for now); `client.hostAddress` then holds the numeric address. Pass `hostResolver:` to `NetworkClient` to plug in your own resolution.

Client states: `disconnected` → `connecting` → `connected` → `failed`.

### Connection Handshake

1. Client sends a `connect` packet, and re-sends it every `connectRetryInterval` (default 250 ms) until the host answers or `connectionTimeout` expires, so a single lost packet doesn't stall the handshake. The retries run on their own timer; you don't need to call `client.update()` during `connect()`.
2. Host checks capacity — sends `connectRejected` if full
3. If an `authenticator` is set, the host awaits it. Duplicate `connect` packets from the same address are ignored while authentication is in flight, so one client never becomes two peers.
4. If accepted, host creates a `Peer` and sends `connectAccepted` with the assigned peer ID. If the client keeps retrying because that reply was lost, the host sends the acceptance again (same peer ID).
5. Client transitions to `connected`

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

Fledge is a 2D engine, so the built-in `Transform2DNetworkState` syncs position and rotation as three float32s (12 bytes, plus a 1-byte delta mask):

```dart
final state = Transform2DNetworkState()
  ..x = transform.translation.x
  ..y = transform.translation.y
  ..rotation = transform.rotation; // radians
```

Delta encoding uses a 3-bit mask (X, Y, rotation) with a 0.001 epsilon threshold — fields whose difference falls below epsilon are not transmitted, and `createDelta` returns `null` when nothing changed.

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

Clients predict locally and reconcile when the server confirms. Prediction, reconciliation, and state-apply logic **must** run on `Schedules.fixedUpdate` (driven by the `FixedTimestep` resource — 60Hz by default). Only the fixed-timestep schedule guarantees the client and server advance the sim at the same rate; running prediction on the variable-rate `Schedules.update` desyncs from the host.

Best-effort transport work (packet pumping, ping/pong, `host.update()` / `client.update()`) can stay on `Schedules.first` or `Schedules.last`, which are frame-rate driven.

```dart
final prediction = ClientPrediction();

// Register the prediction system on the fixed-timestep schedule.
app.addSystem(
  FunctionSystem('predictInput', run: (world) {
    final input = InputFrame(tick: prediction.nextTick())
      ..moveX = controller.moveX
      ..moveY = controller.moveY
      ..setButton(InputButton.primaryAction, firing);

    prediction.recordInput(input, predictedState);

    // Send unacknowledged inputs to host.
    final unacked = prediction.getUnackedInputs();
    client.send(PacketType.input, serializeInputs(unacked));
  }),
  schedule: Schedules.fixedUpdate,
);

// When server state arrives — reconcile.
final inputsToReplay = prediction.reconcile(serverTick, serverState);
// Re-simulate from server state using replayed inputs.
```

> Determinism is scoped to the fixed-timestep loop. `fledge_net` relies on both peers running the same `FixedTimestep.stepDuration` for prediction to converge; it is *not* a rollback / GGPO-style netcode.

### InputFrame

Each input frame captures a tick's worth of player input:

- Movement: `moveX`, `moveY` (normalized -1..1). `moveZ` is available for games that use a third axis (e.g. jump strength) but is not used by the built-in 2D state sync.
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
| Version | 1 byte | Protocol version (currently `3`) |
| Type | 1 byte | PacketType enum |
| Sequence | 2 bytes | Packet sequence number |
| Ack | 2 bytes | Last received sequence from remote |
| AckBits | 4 bytes | Bitmap of last 32 received sequences |
| Timestamp | 4 bytes | Sender's local monotonic clock (ms, unsigned 32-bit, wraps) |
| Reserved | 2 bytes | Reserved for future use |

The timestamp is only meaningful to the machine that wrote it; clocks on different machines are never compared.

### Packet size limit

Datagrams are capped at `Packet.maxDatagramBytes` (1200 bytes), which keeps them under typical path MTUs so the IP layer never fragments them. After the 20-byte header and 28 bytes reserved for `EncryptedTransport` (reserved even when encryption is off), the largest payload is `Packet.maxPayloadBytes` = **1152 bytes**. `NetworkClient.send`, `NetworkHost.sendTo`, `broadcast` and `broadcastExcept` throw an `ArgumentError` for larger payloads, and a broadcast sends nothing in that case. Split large data across several packets yourself; there's no automatic fragmentation yet.

### Protocol version mismatch

Version history: `2` replaced the old 3D transform format with `Transform2DNetworkState`; `3` made the header timestamp an unsigned 32-bit monotonic value, made ping/pong echo the sender's timestamp, and switched strings to UTF-8. `PacketHeader.deserialize` returns `null` for any packet whose version doesn't match `PacketHeader.version`, so peers running incompatible versions cannot exchange traffic. Both sides report the mismatch instead of timing out:

- **Host**: emits a `ProtocolMismatchEvent` (`source`, `localVersion`, `remoteVersion`) on `NetworkHost.onProtocolMismatch`. If the packet was a `connect`, it also replies with `connectRejected` and a reason such as `"Protocol version mismatch: host v3, client v2"`. A v3 client shows that reason in `onStateChange`. A v2 client can't parse the v3 reply, but it still recognizes the version byte and reports its own mismatch error.
- **Client**: when bytes from the host carry the protocol magic but a different version, the client emits a `ProtocolMismatchEvent` on `NetworkClient.onProtocolMismatch` and transitions to `ClientState.failed` with a reason such as `"Protocol version mismatch: local v3, server v4"`. `connect()` returns `false` right away.

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

`writeString` encodes UTF-8 with a 16-bit byte-length prefix, so any Unicode text (`'Zoë 🦆'`) round-trips. Strings and `writeBytes` data are limited to 65535 bytes, and `writeString` throws `ArgumentError` beyond that. `readString` throws `FormatException` on invalid UTF-8. `writeUint16` / `writeUint32` and the matching `read*` methods are available for unsigned fields.

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

You create your own systems to drive the host/client, poll for data, and sync state. Place prediction / reconciliation / state-apply systems on `Schedules.fixedUpdate` so they tick at the same rate as the server sim (see [Input Prediction](#input-prediction)). Transport bookkeeping (`host.update()`, `client.update()`) can run on `Schedules.first` or `Schedules.last`.

## Reliable Delivery

Critical packet types (`connect`, `disconnect`, `entitySpawn`, `entityDespawn`, `rpc`) are automatically retransmitted until acknowledged. State updates and input are sent unreliably (latest-wins).

Retransmit timeout scales with RTT: `rtt * 2.0`, clamped to 100 ms–5 s (100 ms until the first RTT sample). Packets are dropped after 10 retransmit attempts.

### Round-trip time

RTT is measured with ping/pong. Each side puts its own monotonic-clock timestamp in a `ping`, and the other side echoes it back unchanged in the `pong`, so the sample is always `now − echoed` on the same clock and is correct across the 32-bit wrap. `client.update()` pings the host, and `host.update()` pings each peer, every `pingInterval`. Results feed `NetworkClient.rtt` and `Peer.rtt`, which are exponential moving averages, and those drive the retransmit timeouts (`client.retransmitTimeout`, `peer.retransmitTimeout(fallback)`). Samples that are negative or above 60 s are discarded.

```dart
// Check if a packet type is reliable
PacketType.rpc.isReliable;          // true
PacketType.stateUpdate.isReliable;  // false
```

## Authentication

The host can validate client connections via a password or custom authenticator:

```dart
final host = NetworkHost(
  transport: UdpTransport(),
  authenticator: (clientId, credentials) async {
    final password = String.fromCharCodes(credentials);
    return password == 'secret';
  },
);
```

Clients pass credentials during connect:

```dart
final passwordBytes = Uint8List.fromList(utf8.encode('secret'));
await client.connect('192.168.1.100', 7777, credentials: passwordBytes);
```

`NetworkConfig` also has `serverPassword` and `authenticator` fields, but they are **not yet wired** to `NetworkHost` (see the note under [NetworkConfig](#networkconfig)). Pass the authenticator to the `NetworkHost` constructor as shown above.

## Encryption

Wrap your transport with `EncryptedTransport` for authenticated per-packet encryption:

```dart
final inner = UdpTransport();
final transport = EncryptedTransport(
  inner: inner,
  sharedKey: EncryptedTransport.generateKey(), // 32 random bytes
);
```

`EncryptedTransport` uses AES-256-GCM (via `package:pointycastle`). The wire format per packet is:

```
[ 6 bytes  ] plaintext header (magic + version + type) — kept readable for routing
[ 12 bytes ] random GCM nonce
[ N bytes  ] ciphertext (sequence, ack, ackBits, timestamp, payload)
[ 16 bytes ] GCM authentication tag
```

The 6-byte header is bound into the auth tag as AAD, so tampering with it is detected. Packets that fail verification (wrong key, flipped bit, truncated tag) are silently dropped by the receiver.

`sharedKey` must be exactly 32 bytes (AES-256). The setter throws `ArgumentError` on other lengths. Setting it to `null` disables encryption and passes traffic through unchanged.

`NetworkConfig.enableEncryption` is **not yet wired**. Setting it does not encrypt anything, so wrap the transport yourself as shown above.

> **Key distribution:** the key is pre-shared — both host and client must be configured with the same 32 bytes before any encrypted traffic flows. A proper key-exchange handshake (ECDH during connect) is on the roadmap; until then, distribute the key via your own out-of-band mechanism (config, login response, etc.).

## Congestion Control

Each peer has a `CongestionController` using AIMD (Additive Increase, Multiplicative Decrease):

- On ack: window increases gradually
- On packet loss: window halves (minimum 1200 bytes)
- Maximum window: 256 KB

Retransmit timeout is RTT-adaptive: `rtt * 2.0` clamped to 100 ms–5 s (see [Round-trip time](#round-trip-time)).

## Interest Management

Use `InterestManager` for radius-based entity filtering:

```dart
final interest = InterestManager(
  relevanceRadius: 500,
  positionGetter: (world, entity) {
    final pos = world.get<Transform2D>(entity)!;
    return (pos.translation.x, pos.translation.y);
  },
);

// Get relevant entities for a peer
final relevant = interest.getRelevantEntities(peerId, world, registry);
```

Entities beyond `relevanceRadius` from a peer's owned entity are excluded. `NetworkConfig.interestRadius` exists but is **not yet wired** (nothing reads it yet), so construct and query an `InterestManager` yourself as shown above.

## Authority Model

`NetworkIdentity` tracks entity ownership:

```dart
final identity = NetworkIdentity(
  netId: registry.generateNetId(),
  ownerId: peerId,      // Which peer owns this entity
  hasAuthority: true,    // Whether this instance can modify it
);

// Check ownership
identity.isOwnedBy(peerId);  // true

// Transfer ownership
identity.transferAuthority(newOwnerId, localAuthority: false);
```

The host should validate that clients only send updates for entities they own (`ownerId == peer.id`).

## Testing Multiplayer In One Process

`LoopbackNetwork` is an in-memory datagram network, and it's the recommended way to test netcode. Create one network, give each endpoint its own `LoopbackTransport`, and use them exactly like `UdpTransport`. One host and any number of clients can share a network.

```dart
final net = LoopbackNetwork(
  latency: const Duration(milliseconds: 40), // one-way
  jitter: const Duration(milliseconds: 10),  // extra random delay (reorders)
  packetLoss: 0.05,                          // 5% dropped
  duplication: 0.01,                         // 1% delivered twice
  random: Random(42),                        // same seed => same run
);

final host = NetworkHost(transport: net.createTransport());
await host.start(7777);

final client = NetworkClient(transport: net.createTransport());
await client.connect('127.0.0.1', 7777);
```

- `net.filter` drops specific datagrams deterministically, e.g. "drop the first `connect`".
- `createTransport(host: '10.0.0.2')` simulates distinct machines.
- `transport.inject(source, bytes)` feeds hand-crafted packets.
- `net.stats` counts sent / delivered / dropped / duplicated datagrams.

**Manual mode** gives exact, repeatable timing. Pass a `ManualNetClock` to the network and to the host and client. Nothing is delivered until you call `await net.advance(duration)` (or `net.flush()`), and the clock moves to each delivery time:

```dart
final clock = ManualNetClock();
final net = LoopbackNetwork(latency: const Duration(milliseconds: 50), clock: clock);
final host = NetworkHost(transport: net.createTransport(), clock: clock);
final client = NetworkClient(transport: net.createTransport(), clock: clock);
await host.start(7777);
final connecting = client.connect('127.0.0.1', 7777);
await net.advance(const Duration(milliseconds: 100));
await connecting; // true

for (var i = 0; i < 100; i++) {
  host.update();
  client.update();
  await net.advance(const Duration(milliseconds: 10));
}
// client.rtt == 100 exactly
```

### Transport delivery contract

Each received datagram is delivered exactly once. If anything listens to `transport.onReceive` (as `NetworkHost` and `NetworkClient` do), packets go to the stream only. Otherwise they go to a bounded buffer (`maxBufferedPackets`, default 1024, oldest dropped first) that `transport.receive()` drains. `UdpTransport`, `LoopbackTransport` and `EncryptedTransport` all follow this contract. `UdpTransport` also queues sends that hit a full OS buffer (up to `maxQueuedSends`) instead of silently dropping them, and accepts a `bindAddress` (e.g. `InternetAddress.loopbackIPv4`).

## API Reference

### NetworkConfig

| Property | Type | Description |
|----------|------|-------------|
| `mode` | `NetworkMode` | offline, host, or client |
| `tickRate` | `int` | Server simulation rate in Hz (default: 60) |
| `syncRate` | `int` | State broadcast rate in Hz (default: 20) |
| `interpolationDelay` | `double` | Client interpolation delay in ms (default: 100) |
| `serverPassword` | `String?` | Password for client authentication (**not yet wired**) |
| `authenticator` | `Function?` | Custom authentication callback (**not yet wired**; pass it to `NetworkHost`) |
| `enableEncryption` | `bool` | Enable packet encryption (default: false; **not yet wired**) |
| `interestRadius` | `double?` | Spatial filtering radius (null = broadcast all; **not yet wired**) |

### NetworkHost

| Method | Description |
|--------|-------------|
| `start(port)` | Bind and start listening |
| `stop()` | Disconnect all peers and close |
| `update()` | Process timeouts, ping peers, retransmit |
| `sendTo(peerId, type, data)` | Send to one peer (payload ≤ `Packet.maxPayloadBytes`) |
| `broadcast(type, data)` | Send to all connected peers |
| `broadcastExcept(excludeId, type, data)` | Broadcast excluding one peer |
| `disconnectPeer(id, reason)` | Force disconnect a peer |
| `onProtocolMismatch` | Stream of `ProtocolMismatchEvent` |

Constructor options: `maxPeers`, `connectionTimeout`, `retransmitTimeout` (fallback before RTT is known), `authenticator`, `pingInterval` (default 1 s), `clock`.

### NetworkClient

| Method | Description |
|--------|-------------|
| `connect(host, port, {credentials})` | Connect to a host (IP or hostname) with optional auth |
| `disconnect()` | Disconnect from host |
| `update()` | Process pings, timeouts and retransmits |
| `send(type, data)` | Send data to host (payload ≤ `Packet.maxPayloadBytes`) |
| `state` | Current `ClientState` |
| `rtt` | Smoothed round-trip time in ms |
| `retransmitTimeout` | Current reliable-retransmit timeout |
| `onProtocolMismatch` | Stream of `ProtocolMismatchEvent` |

Constructor options: `connectionTimeout`, `pingInterval`, `connectRetryInterval` (default 250 ms), `clock`, `hostResolver`.

### NetworkIdentity

| Property | Type | Description |
|----------|------|-------------|
| `netId` | `int` | Unique network entity ID |
| `ownerId` | `int` | Owning peer (0 = host) |
| `hasAuthority` | `bool` | Whether this instance can modify |
| `spawnType` | `String?` | Type identifier for remote spawning |
| `isOwnedBy(peerId)` | `bool` | Check if peer owns this entity |
| `transferAuthority(newOwnerId)` | `void` | Transfer ownership to another peer |

## See Also

- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin system introduction
- [Input Handling](/docs/plugins/input) - Local input processing
