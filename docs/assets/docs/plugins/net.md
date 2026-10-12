# Networking

The `fledge_net` package provides multiplayer networking for Fledge games: a UDP transport, a host-authoritative connection model, and an ECS **replication layer** that spawns entities on clients, keeps their state in sync, carries player inputs with ownership checks, predicts the local player, interpolates everyone else, and delivers RPCs.

It is built for small sessions such as 2 to 4 player co-op: one player hosts, the others join, and the host owns the simulation.

> Everything below the [Low-level API](#low-level-api) heading (transports, `NetworkHost`, `NetworkClient`, packets) is what the replication layer is built on. Most games only need the replication layer.

## Installation

```yaml
dependencies:
  fledge_net: ^0.4.0
```

`fledge_net` is pure Dart (no Flutter dependency), so it doesn't know about `Transform2D`. You tell it how to encode your components (including your transform) with codecs, as shown below.

## Co-op Quickstart

The example: players ride a shared, host-owned vehicle. Each player's avatar is a child entity of the vehicle and is controlled by that player.

### 1. Describe what replicates

Build the same `ReplicationRegistry` on host and clients. The handshake compares a hash of it and refuses mismatched builds.

```dart
class MoveInput {
  final double dx, dy;
  const MoveInput(this.dx, this.dy);
}

class Emote {
  final String name;
  const Emote(this.name);
}

final transformCodec = NetCodec<Transform2D>.of(
  encode: (t, out) => out
    ..writeFloat32(t.translation.x)
    ..writeFloat32(t.translation.y)
    ..writeFloat32(t.rotation),
  decode: (r) =>
      Transform2D.from(r.readFloat32(), r.readFloat32())..rotation = r.readFloat32(),
);

Transform2D lerpTransform(Transform2D a, Transform2D b, double t) => Transform2D.from(
      a.translation.x + (b.translation.x - a.translation.x) * t,
      a.translation.y + (b.translation.y - a.translation.y) * t,
    )..rotation = a.rotation + (b.rotation - a.rotation) * t;

// Pure and deterministic: host and owning client both run it.
Transform2D move(Transform2D s, MoveInput i, double dt) => Transform2D.from(
      s.translation.x + i.dx * 120 * dt,
      s.translation.y + i.dy * 120 * dt,
    )..rotation = s.rotation;

ReplicationRegistry buildReplication() => ReplicationRegistry()
  ..component<Transform2D>('transform', transformCodec, interpolate: lerpTransform)
  ..component<Health>('health', healthCodec)
  ..input<MoveInput>(moveInputCodec)
  ..predict<Transform2D, MoveInput>(
    step: move,
    error: (a, b) => (a.translation - b.translation).length,
    tolerance: 0.01,
  )
  ..rpc<Emote>('emote', emoteCodec)
  // World position, for interest management.
  ..positionOf = (world, e) {
    final g = world.get<GlobalTransform2D>(e);
    return g == null ? null : (g.x, g.y);
  };
```

Register the **local** `Transform2D` (relative to the parent). Never replicate `GlobalTransform2D`: clients rebuild it from the replicated hierarchy with `TransformPropagateSystem`.

> **Registering from an extension:** inside an `extension ... on ReplicationRegistry`, write `this.component<T>(...)`. A bare `component<T>(...)` resolves to the top-level `component` annotation constant exported by `fledge_ecs` and fails to compile. Cascades (`registry..component<T>(...)`) are unaffected.

### 2. Add the plugin

```dart
final config = NetworkConfig(tickRate: 60, syncRate: 20, interestRadius: 2000);

final app = App()
  ..insertResource(config.fixedTimestep()) // FixedTimestep must match tickRate
  ..addPlugin(RenderPlugin())
  ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate)
  ..addPlugin(NetworkPlugin(config: config, replication: buildReplication()));
```

The plugin's systems are always registered but do nothing until a session starts, so the same `App` works for single player.

### 3. Host or join

```dart
final session = app.world.getResource<NetworkSession>()!;

await session.host(port: 7777);
// or, on another machine:
final ok = await session.join('192.168.1.20', 7777);
if (!ok) showError(session.lastError);
```

`join` resolves once the host accepted the connection. Tick sync and the welcome message follow within a few round trips; then `session.isReady` becomes true and a `NetConnected` event is sent. `session.close()` ends the session.

### 4. Spawn replicated entities on the host

Add `Replicated` on the host. On the next fixed tick the entity gets a network id and a `NetworkIdentity`, and is spawned with its registered components on every client it is relevant to.

```dart
// Host, at session start.
final vehicle = world.spawn()
  ..insert(Replicated(alwaysRelevant: true))
  ..insert(Transform2D.from(0, 0));

// Host, when a player joins.
class SpawnAvatars implements System {
  // meta: name, schedule Schedules.update ...
  @override
  Future<void> run(World world) async {
    for (final e in world.eventReader<NetPeerConnected>().read()) {
      final avatar = world.spawn()
        ..insert(Replicated(owner: e.peerId)) // the joining peer controls it
        ..insert(Transform2D.from(e.peerId * 32.0, 0)); // local to the vehicle
      world.setParent(avatar.entity, vehicleEntity);
    }
  }
}
```

Parents are replicated by network id and resolved on the client with `world.setParent`; a child that arrives before its parent waits until the parent spawns. Moving the vehicle on the host moves every avatar on every client, because only the vehicle transform changes and `TransformPropagateSystem` does the rest.

### 5. Submit input

Every instance submits input for the entities it owns. Put the system in `Schedules.fixedPreUpdate` and join `NetSets.localInput`:

```dart
FunctionSystem(
  'submitMove',
  sets: [NetSets.localInput],
  resourceReads: {ActionState, NetworkSession},
  resourceWrites: {NetLocalInputs<MoveInput>},
  run: (world) {
    final me = world.getResource<NetworkSession>()!.localPeerId;
    final inputs = world.getResource<NetLocalInputs<MoveInput>>()!;
    for (final (e, id) in world.query1<NetworkIdentity>().iter()) {
      if (id.ownerId == me) inputs.submit(e, readStick(world));
    }
  },
);
```

With `predict` registered, that's all: the owning client applies `step` immediately (no round trip) and the host applies the same `step` when the input arrives. Other host systems can read the inputs of the current tick from `NetInputs<MoveInput>` (after `NetInputSystem.systemName`).

### 6. React to events

| Event | Where | When |
|---|---|---|
| `NetPeerConnected(peerId)` | host | a client connected (spawn its avatar) |
| `NetPeerDisconnected(peerId, reason, ownedNetIds, policy)` | host | a client left; its owned entities were already handled |
| `NetConnected(localPeerId)` | client | handshake and tick sync done |
| `NetDisconnected(reason)` | both | session ended; clients have despawned replicated entities |
| `NetEntitySpawned` / `NetEntityDespawned` | client | a replicated entity appeared / went away |
| `NetPredictionCorrected(entity, netId, tick, error)` | client | the host disagreed with a prediction |
| `NetRejected(peerId, kind, netId, reason)` | host | a client sent input or an RPC for an entity it doesn't own |
| `NetRpcReceived<T>(sender, value, target)` | both | an RPC arrived |
| `NetProtocolMismatch(details)` | both | a peer runs another protocol version |

Events follow the usual Fledge rule: they are readable during the frame after they were sent.

### 7. RPCs

```dart
// Client to host (targeting an entity the client owns is optional):
session.sendRpc(const Emote('wave'), target: myAvatar);
// Host to everyone, or to one peer:
session.sendRpc(const Emote('boost'));
session.sendRpcTo(peerId, const Emote('you-win'));
```

RPCs are reliable and ordered together with spawns and despawns, so an RPC that targets a freshly spawned entity never arrives before the spawn. The host rejects (and reports with `NetRejected`) client RPCs whose target the client does not own.

### 8. Test it in one process

`LoopbackNetwork` with a `ManualNetClock` runs a host and several clients deterministically in one test. Give every app the same clock and a transport factory on the same network, tick them with a fixed frame delta, and advance the network clock by one step per frame:

```dart
final clock = ManualNetClock();
final net = LoopbackNetwork(
  clock: clock,
  latency: const Duration(milliseconds: 50),
  jitter: const Duration(milliseconds: 50),
  packetLoss: 0.05,
  random: Random(7),
);

App makeApp() => App()
  ..insertResource(config.fixedTimestep())
  ..insertResource(WallTime()..delta = 1 / config.tickRate) // fixed frame delta
  ..addPlugin(NetworkPlugin(
    config: NetworkConfig(tickRate: config.tickRate),
    replication: buildReplication(),
    clock: clock,
    transportFactory: net.createTransport,
  ));

Future<void> frame(List<App> apps) async {
  await net.advance(Duration(milliseconds: 1000 ~/ config.tickRate));
  for (final app in apps) {
    await app.tick();
  }
}
```

Keep ticking frames while `join` is pending, because the connect handshake travels over the simulated network too.

To test the host's authority checks, import the test-only library `package:fledge_net/testing.dart` (not exported from `fledge_net.dart`). Its `NetworkSessionTesting` extension lets a client session act like a modified client: `sendRawInput(netId:, firstTick:, inputs:)` sends inputs for any entity (encode values with `encodeWithCodec(codec, value)`; `encodeRawInputPacket` builds a whole packet) and `sendRawRpc(value, targetNetId:)` names any target. The host should drop them and report `NetRejected`.

The package tests (`packages/fledge_net/test/support/replication_harness.dart`) contain a complete harness: one host plus three clients with latency, jitter and loss, inputs, prediction, interest and late join.

## How Replication Works

### Ticks

All simulation runs in the fixed-timestep chain, and `NetworkConfig.tickRate` must equal the `FixedTimestep` rate (`config.fixedTimestep()` builds a matching one; `host`/`join` throw otherwise, and clients with a different tick rate are refused).

- **Host:** `NetworkTick.serverTick` is authoritative and advances once per fixed step (`localTick` equals it).
- **Client:** `NetworkTick.localTick` is the tick the client simulates and produces input for. It **leads** the host by about RTT/2 plus `inputLeadBufferTicks` (default 2), so an input for tick `t` reaches the host just before the host simulates `t`. On connect, a tick-sync handshake (`PacketType.tickSync`, a few request/response round trips, lowest RTT wins) sets the lead. Afterwards every snapshot is a sample, and small errors are corrected by *time dilation*: the client runs its fixed steps slightly faster or slower by nudging the `FixedTimestep` accumulator. Large errors (more than 10 ticks, e.g. after a stall) snap the tick, and prediction history is discarded. If the host reports late inputs, the client widens its buffer by a tick at a time. `NetworkTick.serverTick` on a client is the estimate of the current host tick.

### Systems

| System | Schedule | Ordering | Does |
|---|---|---|---|
| `NetPumpSystem` | `first` | `FirstSets.platform` | `host/client.update()`, tick sync, connection events, reliable resends |
| `NetReceiveSystem` | `first` | after the pump and every `FirstSets` phase | applies packets: spawns, despawns, hierarchy, ownership, snapshots, RPC events (client); validated inputs and RPCs, disconnect policy (host) |
| `NetInterpolationSystem` | `first` | after receive | writes interpolated components |
| `NetTickSystem` | `fixedFirst` | | advances `NetworkTick` |
| `NetInputSystem` | `fixedPreUpdate` | after `NetSets.localInput` | builds `NetInputs<I>` for this tick |
| `NetPredictSystem` | `fixedPreUpdate` | after input | host: applies `step` to every entity with an input; client: reconciles and predicts its own entities |
| `NetSendSystem` | `fixedLast` | | host: assigns ids, interest, spawns/despawns, snapshots; client: records predictions, sends inputs |

Network callbacks never touch the `World`: they append to queues that these systems drain. Each system has a `static const String systemName` for `before:`/`after:`. The plugin is free of ordering ambiguities on its own and together with `PhysicsPlugin`, `RenderPlugin` and `TransformPropagateSystem` (checked by `App.checkScheduleOrdering()` in the tests). Game systems that write replicated components in the same schedules as these systems should order themselves against them.

### Spawns, despawns and hierarchy

Spawn (with the full initial component state), despawn, re-parent, ownership changes and RPCs travel on one **ordered reliable channel** per client (`ReliableChannel`: sequence numbers, cumulative acks piggybacked on every packet, resend after about 1.5 RTT). A parent is always spawned before its children. A child whose parent is unknown is kept as an orphan and attached when the parent arrives.

### Snapshots

Every `tickRate / syncRate` ticks the host sends each client a snapshot of every entity relevant to it. **Each snapshot carries the full state** of those entities (no delta against an acknowledged baseline yet), so a lost snapshot is repaired by the next one and there is no baseline bookkeeping. Snapshots are split into self-contained chunks of at most `Packet.maxPayloadBytes`; one entity never spans two chunks. Each chunk carries the server tick, the last input tick the host simulated for that client (input ack) and the reliable-channel ack. Older data never overwrites newer data. For a co-op game with a few hundred small entities this costs a few KB per snapshot; delta compression against acked baselines is a planned optimisation.

Limits: one entity's replicated state must fit in about 1.1 KB (an error names the entity otherwise), and a registry holds up to 32 component types.

### Interest management

With `interestRadius` and `ReplicationRegistry.positionOf` set, each client receives only:

- entities within `interestRadius` of the **global** position of the first replicated entity it owns,
- entities it owns, entities marked `Replicated(alwaysRelevant: true)`, and entities without a position,
- and the ancestors of all of these (a child is useless without its parent).

A client that owns no positioned entity receives everything. The relevant set is recomputed every tick: entities that enter it are spawned on the client, entities that leave it are despawned.

### Inputs and authority

Clients send their inputs every tick, redundantly: each packet repeats every input the host has not acknowledged yet (up to `inputRedundancy`). The host buffers them per client and entity, and every tick hands exactly one input per controlled entity to `NetInputs<I>`. If an input is missing it repeats the previous one for up to `maxInputRepeatTicks` ticks. The host **rejects** inputs and targeted RPCs for entities the sender does not own (`NetworkIdentity.ownerId != peerId`): the data is dropped, `NetworkSession.stats` counts it, and a `NetRejected` event names the peer, kind and network id (never payload data). Clients cannot spawn, despawn, re-parent or change ownership; only the host can. Change ownership on the host by setting `NetworkIdentity.ownerId`.

Ownership is tracked on the host, and a client submits inputs only for the entities the session's own owner map (filled from the host's spawn and owner messages) says it owns, so editing a client's local `NetworkIdentity` cannot spoof control.

### Prediction and reconciliation

For entities it owns, a client applies `step(state, input, dt)` (with `dt = FixedTimestep.stepSeconds`) as soon as the input is submitted, and records the predicted state per tick. When a snapshot arrives, the server state for tick `T` is compared with the recorded prediction for `T` using your `error` function. Within `tolerance` nothing happens. Otherwise the client resets to the server state and replays the unacknowledged inputs `T+1 .. now` with `step`, then emits `NetPredictionCorrected`. A deterministic `step` never triggers a correction. Things the client cannot predict (the host teleports the avatar, a host-only system pushes it) are corrected within one round trip.

`correctionBlend` (below 1, requires `interpolate`) softens corrections visually: the corrected state is blended in from the mispredicted one, and later snapshots remove the remaining error over a few round trips. Only `step` is replayed, so keep everything that affects the predicted component inside `step`, or accept corrections for the rest.

### Interpolation

Components registered with `interpolate` on entities the client does not predict are buffered by **server tick** (not arrival time) and rendered `interpolationDelay` ms behind the newest snapshot (measured from its mean arrival time), between the two samples around the render tick.

The render tick runs on its own clock: it advances with frame time, independent of the client's simulation-clock corrections (time dilation, input-lead changes when RTT or late inputs change, tick resets) and of how many fixed steps a frame runs. It tracks the snapshot stream by speeding up or slowing down by at most 10 %, so interpolated entities never step or move backwards; only a large discontinuity (such as the host's clock jumping) snaps it.

By default `interpolationDelay` is derived: two snapshot intervals plus a 50 ms jitter margin (`2 * syncInterval * 1000 / tickRate + 50`, so 150 ms at 60 Hz / 20 Hz). That covers one lost snapshot under up to ~100 ms of arrival jitter. If you set it yourself, stay above two snapshot intervals plus half the expected jitter. Lower values trade smoothness for latency.

When snapshots run out (several lost in a row), the entity is extrapolated along its last segment for up to `maxExtrapolation` ms (default 100) and then held. When data arrives again it blends back onto the interpolated path over one snapshot interval, so there's no jump. Extrapolation calls your `interpolate` function with `t > 1`. If a type can't extrapolate, clamp `t` in that function or set `maxExtrapolation` to 0 (hold).

Interpolation runs in `Schedules.first`, so each frame shows the time consumed by the previous frame's fixed pass. That is a constant one-frame phase, not jitter.

### Disconnects

When a client leaves (disconnect, timeout, or the host disconnects it), the host applies `NetworkConfig.disconnectPolicy` to the entities it owned and then sends `NetPeerDisconnected`:

- `OwnedEntityPolicy.despawn` (default): despawned with their children, which despawns them on every client.
- `OwnedEntityPolicy.releaseToHost`: kept, and ownership moves to the host (`ownerId` 0).

When a client's session ends, it despawns every replicated entity and sends `NetDisconnected`.

Disconnect notices are sent redundantly (3 identical copies a few ms apart by default; `disconnectRedundancy` / `disconnectRedundancyInterval` on `NetworkClient` and `NetworkHost`), so a single lost datagram doesn't leave a departed player's entities around until `connectionTimeout`. Duplicates are ignored.

## NetworkConfig

Every field is used by the replication layer.

| Property | Default | Description |
|---|---|---|
| `mode` | `offline` | Maintained by `NetworkSession` (`host` / `client` / `offline`) |
| `tickRate` | 60 | Simulation rate in Hz; must match `FixedTimestep` and the host |
| `syncRate` | 20 | Snapshot rate in Hz (`syncInterval = tickRate / syncRate` ticks) |
| `interpolationDelay` | derived | How far behind the newest snapshot (ms) remote entities are rendered. Unset (or set to `null`): `defaultInterpolationDelay` = 2 snapshot intervals + 50 ms (150 ms at 60 Hz / 20 Hz) |
| `maxExtrapolation` | 100 | How long (ms) remote entities are extrapolated past the newest snapshot when snapshots are lost or late; 0 holds instead |
| `serverPassword` | null | Host requires these UTF-8 bytes as credentials (constant-time compare); clients send it by default. Sent in the clear unless encryption is on |
| `authenticator` | null | Custom host check `(clientId, credentials) async => bool`; if a password is also set, both must accept |
| `enableEncryption` | false | Wrap the transport in `EncryptedTransport` (AES-256-GCM) |
| `encryptionKey` | null | Pre-shared 32-byte key; required when `enableEncryption` is set (starting without one throws; there is no unencrypted fallback). Never logged |
| `interestRadius` | null | Interest radius; null sends everything to everyone |
| `maxPeers` | 8 | Maximum clients |
| `connectionTimeout` | 10 s | Silence after which a connection is dropped |
| `disconnectPolicy` | `despawn` | What happens to a departed client's entities |
| `inputLeadBufferTicks` | 2 | Safety margin in the client's input lead |
| `maxInputRepeatTicks` | 8 | How long a missing input is replaced by the previous one |
| `inputRedundancy` | 8 | Unacked inputs repeated in every input packet |

## NetworkSession

| Member | Description |
|---|---|
| `host({port, transport})` | Start hosting (default transport: `UdpTransport`, or `transportFactory`) |
| `join(address, port, {transport, credentials})` | Connect; `false` and `lastError` on failure |
| `close([reason])` | End the session |
| `role`, `isHost`, `isClient`, `isActive`, `isReady` | Session state |
| `localPeerId` | 0 on the host, the assigned id on a client |
| `peerIds`, `rttMs([peerId])` | Connected peers (host), round-trip times |
| `sendRpc(value, {target, exceptPeer})`, `sendRpcTo(peerId, value, {target})` | RPCs |
| `stats` | Counters: rejected inputs/RPCs/messages, corrections, snapshot chunks, late inputs, tick resets |
| `networkHost`, `networkClient`, `tickSync` | The underlying objects, for diagnostics |

Pass `clock:` and `transportFactory:` to `NetworkPlugin` to run on a `ManualNetClock` and a `LoopbackNetwork` in tests.

## Low-level API

The rest of this page documents the building blocks the replication layer uses. You can use them directly for custom protocols.

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

`NetworkIdentity` records an entity's network id and owner. The replication layer inserts it for you (from `Replicated` on the host, from spawn messages on clients); construct it yourself only for custom protocols:

```dart
final entity = world.spawn()
  ..insert(NetworkIdentity(
    netId: registry.generateNetId(),
    ownerId: 0,          // 0 = host-owned, >0 = client peer ID
    hasAuthority: true,
    spawnType: 'player',
  ))
  ..insert(Position(0, 0));
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

### Client-Side Interpolation (low-level)

The replication layer interpolates registered components by server tick (see [Interpolation](#interpolation)). `NetworkInterpolation` is a standalone, wall-clock-keyed helper for custom protocols:

```dart
entity.insert(NetworkInterpolation(
  interpolationDelay: 100,  // ms behind server time
));

// In your system — add incoming state snapshots
interpolation.addState(serverTick, receivedState);

// Each frame — interpolate between buffered snapshots
interpolation.update(DateTime.now());
final smoothed = interpolation.currentState;
```

## Input Prediction (low-level)

The replication layer does all of this for registered components (see [Prediction and reconciliation](#prediction-and-reconciliation)). `ClientPrediction`, `InputFrame` and `ServerInputQueue` are standalone helpers for custom protocols.

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
// Empty when the prediction recorded for serverTick matched serverState
// (within `tolerance`, or your `statesMatch`). Otherwise
// prediction.lastReconcileMispredicted is true: reset to serverState and
// re-simulate the returned inputs.
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

The replication layer stays under this limit on its own (snapshots are chunked, reliable messages are batched). For your own packets: datagrams are capped at `Packet.maxDatagramBytes` (1200 bytes), which keeps them under typical path MTUs so the IP layer never fragments them. After the 20-byte header and 28 bytes reserved for `EncryptedTransport` (reserved even when encryption is off), the largest payload is `Packet.maxPayloadBytes` = **1152 bytes**. `NetworkClient.send`, `NetworkHost.sendTo`, `broadcast` and `broadcastExcept` throw an `ArgumentError` for larger payloads, and a broadcast sends nothing in that case. Split large data across several packets yourself; there's no automatic fragmentation yet.

### Protocol version mismatch

Version history: `2` replaced the old 3D transform format with `Transform2DNetworkState`; `3` made the header timestamp an unsigned 32-bit monotonic value, made ping/pong echo the sender's timestamp, switched strings to UTF-8, and added the replication layer (packet types `replication` and `tickSync`, and the snapshot / input payload formats documented in `lib/src/replication/wire.dart`). `PacketHeader.deserialize` returns `null` for any packet whose version doesn't match `PacketHeader.version`, so peers running incompatible versions cannot exchange traffic. Both sides report the mismatch instead of timing out:

- **Host**: emits a `ProtocolMismatchEvent` (`source`, `localVersion`, `remoteVersion`) on `NetworkHost.onProtocolMismatch`. If the packet was a `connect`, it also replies with `connectRejected` and a reason such as `"Protocol version mismatch: host v3, client v2"`. A v3 client shows that reason in `onStateChange`. A v2 client can't parse the v3 reply, but it still recognizes the version byte and reports its own mismatch error.
- **Client**: when bytes from the host carry the protocol magic but a different version, the client emits a `ProtocolMismatchEvent` on `NetworkClient.onProtocolMismatch` and transitions to `ClientState.failed` with a reason such as `"Protocol version mismatch: local v3, server v4"`. `connect()` returns `false` right away.

### PacketType

```
connect, connectAccepted, connectRejected, disconnect,
ping, pong,
stateUpdate, input, entitySpawn, entityDespawn,
replication, tickSync,
rpc, custom
```

The replication layer uses `stateUpdate` (snapshot chunks), `input` (redundant per-tick inputs), `replication` (its ordered reliable channel) and `tickSync`. `entitySpawn`, `entityDespawn` and `rpc` are free for custom protocols.

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

`writeString` encodes UTF-8 with a 16-bit byte-length prefix, so any Unicode text (`'Zoë 🦆'`) round-trips. Strings and `writeBytes` data are limited to 65535 bytes, and `writeString` throws `ArgumentError` beyond that. `readString` throws `FormatException` on invalid UTF-8. `writeUint16` / `writeUint32` and the matching `read*` methods are available for unsigned fields, `writeVarUint` / `readVarUint` for compact unsigned varints (LEB128), and `writeVarBytes` / `readVarBytes` for varint-length-prefixed bytes without the 64 KiB limit.

## NetworkPlugin

`NetworkPlugin(config:, replication:, clock:, transportFactory:)` inserts `NetworkConfig`, `NetworkTick`, `NetworkEntityRegistry`, `NetworkSession` (and `NetInputs<I>` / `NetLocalInputs<I>` when an input type is registered), registers the network events and adds the [replication systems](#systems). It freezes the `ReplicationRegistry`. The systems do nothing while no session is active.

## Reliable Delivery

Critical packet types (`connect`, `disconnect`, `entitySpawn`, `entityDespawn`, `rpc`) are automatically retransmitted until acknowledged. State updates and input are sent unreliably (latest-wins).

Retransmit timeout scales with RTT: `rtt * 2.0`, clamped to 100 ms–5 s (100 ms until the first RTT sample). Packets are dropped after 10 retransmit attempts. (The replication layer does not use this mechanism: its `ReliableChannel` acks cumulatively and never gives up, relying on the connection timeout instead.)

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

With `NetworkSession`, set `NetworkConfig.serverPassword` and/or `NetworkConfig.authenticator` instead: the session builds the host authenticator (password compared in constant time; both must accept when both are set) and sends the password as the client's default credentials.

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

With `NetworkSession`, set `NetworkConfig.enableEncryption: true` and `encryptionKey:` (32 bytes) instead: the session wraps its transport in `EncryptedTransport`. Starting a session with encryption enabled but no key throws; there is no unencrypted fallback. The key is never logged.

> **Key distribution:** the key is pre-shared — both host and client must be configured with the same 32 bytes before any encrypted traffic flows. A proper key-exchange handshake (ECDH during connect) is on the roadmap; until then, distribute the key via your own out-of-band mechanism (config, login response, etc.).

## Congestion Control

Each peer has a `CongestionController` using AIMD (Additive Increase, Multiplicative Decrease):

- On ack: window increases gradually
- On packet loss: window halves (minimum 1200 bytes)
- Maximum window: 256 KB

Retransmit timeout is RTT-adaptive: `rtt * 2.0` clamped to 100 ms–5 s (see [Round-trip time](#round-trip-time)).

## InterestManager

`InterestManager` is a standalone radius filter:

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

Entities beyond `relevanceRadius` from a peer's owned entity are excluded. The replication layer has its own interest management driven by `NetworkConfig.interestRadius` (see [Interest management](#interest-management)); use `InterestManager` only for custom protocols.

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

The replication layer enforces this on the host: inputs and targeted RPCs for entities the sender does not own are rejected (see [Inputs and authority](#inputs-and-authority)). Custom protocols must check `ownerId == peer.id` themselves.

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

Host peer timeouts and reliable retransmits also follow the injected clock, so advancing a `ManualNetClock` past `connectionTimeout` times out a silent peer without real waiting. `connect()`'s overall timeout and its retries still run on real timers.

### Transport delivery contract

Each received datagram is delivered exactly once. If anything listens to `transport.onReceive` (as `NetworkHost` and `NetworkClient` do), packets go to the stream only. Otherwise they go to a bounded buffer (`maxBufferedPackets`, default 1024, oldest dropped first) that `transport.receive()` drains. `UdpTransport`, `LoopbackTransport` and `EncryptedTransport` all follow this contract. `UdpTransport` also queues sends that hit a full OS buffer (up to `maxQueuedSends`) instead of silently dropping them, and accepts a `bindAddress` (e.g. `InternetAddress.loopbackIPv4`).

## API Reference

See [NetworkConfig](#networkconfig) and [NetworkSession](#networksession) above.

### NetworkHost

| Method | Description |
|--------|-------------|
| `start(port)` | Bind and start listening |
| `stop()` | Disconnect all peers (redundant notices) and close |
| `update()` | Process timeouts, ping peers, retransmit |
| `sendTo(peerId, type, data)` | Send to one peer (payload ≤ `Packet.maxPayloadBytes`) |
| `broadcast(type, data)` | Send to all connected peers |
| `broadcastExcept(excludeId, type, data)` | Broadcast excluding one peer |
| `disconnectPeer(id, reason)` | Force disconnect a peer |
| `getPeer(id)` | The connected `Peer` (e.g. for `rtt`), or null |
| `onProtocolMismatch` | Stream of `ProtocolMismatchEvent` |

Constructor options: `maxPeers`, `connectionTimeout`, `retransmitTimeout` (fallback before RTT is known), `authenticator`, `pingInterval` (default 1 s), `clock` (pings, RTT, peer timeouts and retransmits), `disconnectRedundancy` (default 3), `disconnectRedundancyInterval` (default 5 ms).

### NetworkClient

| Method | Description |
|--------|-------------|
| `connect(host, port, {credentials})` | Connect to a host (IP or hostname) with optional auth |
| `disconnect()` | Send `disconnectRedundancy` disconnect notices, then close |
| `update()` | Process pings, timeouts and retransmits |
| `send(type, data)` | Send data to host (payload ≤ `Packet.maxPayloadBytes`) |
| `state` | Current `ClientState` |
| `rtt` | Smoothed round-trip time in ms |
| `lastStateReason` | Reason from the last state change (e.g. `Authentication failed`) |
| `retransmitTimeout` | Current reliable-retransmit timeout |
| `onProtocolMismatch` | Stream of `ProtocolMismatchEvent` |

Constructor options: `connectionTimeout`, `pingInterval`, `connectRetryInterval` (default 250 ms), `clock`, `hostResolver`, `disconnectRedundancy` (default 3), `disconnectRedundancyInterval` (default 5 ms).

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
