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
  ..positionFrom<GlobalTransform2D>((g) => (g.x, g.y));
```

Register the **local** `Transform2D` (relative to the parent). Never replicate `GlobalTransform2D`: clients rebuild it from the replicated hierarchy with `TransformPropagateSystem`.

`positionFrom<C>` declares `C` as a read of `NetSendSystem`, so the scheduler orders it against systems that write `C`. For a position computed from several components, use `position((world, entity) => ..., reads: {ComponentId.of<A>(), ComponentId.of<B>()})` and list every component the getter reads.

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

### 8. Player actions

Inputs are **level state** sent every tick (the stick is held left); a repeated or lost one does no harm. Discrete things a player *does* (use an item, place a machine, pick something up) are **actions**: each must happen exactly once, in order, and the player wants to see it straight away.

```dart
// Both sides:
registry.action<UseItem>('use', useItemCodec);

// Client (from a fixed-step system, so the action carries this tick):
final ticket = session.sendAction(UseItem(slot: 2), target: myAvatar);

// Host, Schedules.fixedUpdate:
for (final a in world.getResource<NetActions<UseItem>>()!.entries) {
  if (!canUse(a.peerId, a.value)) {
    session.resolveAction(a, accepted: false, reason: 'out of seeds');
    continue;
  }
  applyUse(a.peerId, a.value);               // accepted by default
}
```

- **Exactly once, in order, on its tick.** Actions ride in every input packet until the host acknowledges them, so a lost packet costs a tick, not a resend timeout. The host applies each sequence number once and holds an action until it reaches the tick it was sent at, so it lands on the same tick as the inputs sent with it. A sequence gap (impossible for an honest client) or a target the sender doesn't own is rejected and reported with `NetRejected`.
- **Resolution.** An action not resolved by the end of its tick counts as accepted. The sender gets one `NetActionResolved<T>` event per action (accepted, reason, the tick it was resolved at).
- **Showing it straight away.** `session.pendingActions<T>()` lists the sender's actions whose effect the host's state doesn't show yet. Draw the authoritative state, then each pending action's effect on top. A rejected action leaves the list at once; an accepted one stays until the host's state includes it, so the effect never flickers off and back on. For replicated resources this is exact: a resolution travels on the bulk channel behind every resource chunk queued before it. Entity state is as of the newest snapshot.
- The host's own actions take the same path (peer 0), so host and clients share one code path. Keep payloads small (`NetworkSession.maxActionBytes`, 256): send what the player did (a slot, a tile), never the state it produces.

### 9. Test it in one process

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
- **Client:** `NetworkTick.localTick` is the tick the client simulates and produces input for. It **leads** the host by about RTT/2 plus `inputLeadBufferTicks` (default 2), so an input for tick `t` reaches the host just before the host simulates `t`. On connect, a tick-sync handshake (`PacketType.tickSync`, a few request/response round trips, lowest RTT wins) sets the lead. Afterwards every snapshot is a sample, and small errors are corrected by *time dilation*: the client runs its fixed steps slightly faster or slower by nudging the `FixedTimestep` accumulator. Large errors (more than 10 ticks, e.g. after a stall) snap the tick: the prediction history restarts at the new tick while the predicted state is kept, so the avatar doesn't snap back. If the host reports late inputs, the client widens its buffer by a tick at a time, and after 10 seconds without any it narrows it again a tick at a time. `NetworkTick.serverTick` on a client is the estimate of the current host tick.

### Systems

| System | Schedule | Ordering | Does |
|---|---|---|---|
| `NetPumpSystem` | `first` | `FirstSets.platform` | `host/client.update()`, tick sync, connection events, reliable resends |
| `NetReceiveSystem` | `first` | after the pump and every `FirstSets` phase | applies packets: spawns, despawns, hierarchy, ownership, snapshots, RPC events (client); validated inputs and RPCs, disconnect policy (host) |
| `NetInterpolationSystem` | `update` | `UpdateSets.receive` | writes interpolated components, after the frame's fixed steps |
| `NetTickSystem` | `fixedFirst` | | advances `NetworkTick` |
| `NetInputSystem` | `fixedPreUpdate` | after `NetSets.localInput` | builds `NetInputs<I>` for this tick |
| `NetPredictSystem` | `fixedPreUpdate` | after input | host: applies `step` to every entity with an input; client: reconciles and predicts its own entities |
| `NetSendSystem` | `fixedLast` | | host: assigns ids, interest, spawns/despawns, snapshots; client: records predictions, sends inputs |

Interpolated components are written in `update`, after the frame's fixed steps, so remote entities are sampled at the same moment as the local avatar drawn with `FixedTimestep.alpha`; order systems that draw them after `NetInterpolationSystem.systemName`. Interpolated entities change every frame already, so don't also give them fixed-step render interpolation (`PreviousTransform2D`).

Network callbacks never touch the `World`: they append to queues that these systems drain. Each system has a `static const String systemName` for `before:`/`after:`. The plugin is free of ordering ambiguities on its own and together with `PhysicsPlugin`, `RenderPlugin` and `TransformPropagateSystem` (checked by `App.checkScheduleOrdering()` in the tests). Game systems that write replicated components in the same schedules as these systems should order themselves against them.

### Spawns, despawns and hierarchy

Spawn (with the full initial component state), despawn, re-parent, ownership changes and RPCs travel on an **ordered reliable control channel** per client (`ReliableChannel`: sequence numbers, cumulative acks piggybacked on every packet, resend after about 1.5 RTT). Replicated resources travel on a second reliable channel, the **bulk channel**, so a large world streaming in never delays an RPC. A message bigger than one packet (up to 1 MiB) is split into fragments and reassembled in order. A parent is always spawned before its children. A child whose parent is unknown is kept as an orphan and attached when the parent arrives.

### Snapshots

Every `tickRate / syncRate` ticks the host sends each client a snapshot of **what changed** among the entities relevant to it, compared with that client's last acknowledged copy:

- Each component has a version that changes when its encoded bytes do. Per client, the host remembers the versions the client has acknowledged; an entity is listed only if a component changed or one was added or removed, and then only the changed components' bytes are sent (with a mask of which components exist, so removals arrive too).
- Snapshot chunks are numbered per client, and clients acknowledge them (newest plus a 32-chunk bitfield) in every input packet. A lost chunk is never acknowledged, so what it carried is simply sent again.
- The owner of an entity always gets its predicted components, which reconciliation needs every snapshot.
- At least one chunk (maybe empty) goes every sync: it carries the server tick, the input ack and the control-channel ack.
- When every chunk of a tick has arrived, the client knows the entities it didn't hear about held still, and stops interpolating them there (so a mover that stops comes to rest where it stopped).

Chunks are self-contained and at most `Packet.maxPayloadBytes`; one entity never spans two. Older data never overwrites newer data. 2000 static entities cost well under 1 KB/s once acknowledged.

Limits: a registry holds up to 32 component types, and one entity's encoded state (which must fit one snapshot datagram; put larger state in a replicated resource) (its replicated components plus a few bytes of framing) must fit in `NetworkSession.maxEntityStateBytes` (1114 bytes). The host does not replicate a larger entity: it logs a warning once (`dart:developer`, name `fledge_net`), counts it in `NetworkSession.stats.oversizedEntities`, never spawns it on clients (or despawns it there if it grew past the limit), and replicates it again once it fits. Everything else keeps replicating. Children of a skipped entity wait on clients as orphans until it arrives.

### Replicated resources

Large shared state, such as a tile map, belongs in a resource rather than thousands of entities. Register it with a `ResourceCodec` that splits it into chunks and gives each chunk a version (`ChunkVersions` keeps them):

```dart
registry.resource<Farm>('farm', FarmCodec(), create: Farm.new);

class FarmCodec extends ResourceCodec<Farm> {
  @override
  int chunkCount(Farm farm) => farm.chunkCount;          // e.g. 10x10-tile chunks
  @override
  int chunkVersion(Farm farm, int chunk) => farm.versions.of(chunk);
  @override
  void encodeChunk(Farm farm, int chunk, PacketBuilder out) { /* ... */ }
  @override
  void decodeChunk(Farm farm, int chunk, PacketReader input) { /* ... */ }
}

// On the host, whenever a tile changes:
farm.versions.bump(chunkOf(tile));
```

The host sends each client the chunks whose version changed since it last sent them, reliably on the bulk channel; a joining client receives every chunk. Clients apply chunks into their own instance (made with `create` if missing) and receive a `NetResourceUpdated(key, chunk)` event per chunk. `resize` lets resources whose chunk count varies grow or shrink on clients; `ResourceCodec.whole` sends a small resource as one chunk. A 100x100 tile grid with ten changes a second costs under 4 KB/s.

### Send budget

Each client has a byte budget (`sendBudgetBytesPerSecond`, 64 KiB/s by default), spent every tick in priority order: control messages (spawns, RPCs), then snapshots, then resource chunks. What doesn't fit waits for the next tick: unsent snapshot changes stay unacknowledged and go later (a rotating start gives every entity its turn), and spawns and resource chunks are only queued while about two seconds of the budget is unacknowledged. A join of tens of thousands of entities streams in at the budget instead of overflowing the reliable channel; the "Reliable channel overflow" disconnect remains only for a client that stops acknowledging.

### Interest management

With `interestRadius` and an interest position (`ReplicationRegistry.positionFrom` / `position`) set, each client receives only:

- entities within `interestRadius` of the **global** position of the first replicated entity it owns,
- entities it owns, entities marked `Replicated(alwaysRelevant: true)`, and entities without a position,
- and the ancestors of all of these (a child is useless without its parent).

A client that owns no positioned entity receives everything. Positioned entities are bucketed in a grid of `interestRadius` cells, so the radius check looks at nearby cells only.

Two rules apply with or without a radius:

- `Replicated(ownerOnly: true)` sends an entity only to its owner (a private entity).
- `registry.component<T>(…, ownerOnly: true)` sends one component only to the entity's owner: other clients get the entity without it (a player's inventory on a shared player entity). It moves with ownership.
- `NetworkConfig.relevance`, `(world, entity, peerId) => bool`, hides entities from chosen clients (it isn't asked about entities the client owns). The relevant set is recomputed every tick: entities that enter it are spawned on the client, entities that leave it are despawned.

### Inputs and authority

Clients send their inputs every tick, redundantly: each packet repeats every input the host has not acknowledged yet (up to `inputRedundancy`). The host buffers them per client and entity, and every tick hands exactly one input per controlled entity to `NetInputs<I>`. If an input is missing it repeats the previous one for up to `maxInputRepeatTicks` ticks. The host **rejects** inputs and targeted RPCs for entities the sender does not own (`NetworkIdentity.ownerId != peerId`): the data is dropped, `NetworkSession.stats` counts it, and a `NetRejected` event names the peer, kind and network id (never payload data). Clients cannot spawn, despawn, re-parent or change ownership; only the host can. Change ownership on the host by setting `NetworkIdentity.ownerId`.

Ownership is tracked on the host, and a client submits inputs only for the entities the session's own owner map (filled from the host's spawn and owner messages) says it owns, so editing a client's local `NetworkIdentity` cannot spoof control.

### Prediction and reconciliation

For entities it owns, a client applies `step(state, input, dt)` (with `dt = FixedTimestep.stepSeconds`) as soon as the input is submitted, and records the predicted state per tick. When a snapshot arrives, the server state for tick `T` is compared with the recorded prediction for `T` using your `error` function. Within `tolerance` nothing happens. Otherwise the client resets to the server state and replays the unacknowledged inputs `T+1 .. now` with `step`, then emits `NetPredictionCorrected`. A deterministic `step` never triggers a correction. Things the client cannot predict (the host teleports the avatar, a host-only system pushes it) are corrected within one round trip.

The simulation always takes the corrected state. `correctionBlend` (below 1, requires `interpolate`) smooths the correction **for drawing only**: while it lasts, the entity carries `NetSmoothed<S>`, the value to draw. It starts where the old prediction was drawn, moves with the same inputs as the entity, and closes `correctionBlend` of the remaining gap each tick, after which it is removed. Draw `world.get<NetSmoothed<S>>(e)?.value ?? world.get<S>(e)`.

Only `step` is replayed, so keep everything that affects the predicted component inside `step`, or accept corrections for the rest. A step that needs the world (a collision map, solid tiles) is registered as `stepWith: (state, input, context) => ...`: `PredictContext` gives the world (read only), the entity, the tick and `dt`. Replays see the present world, not the one at the replayed tick, so depend on data that rarely changes (the map), not on other moving entities.

### Interpolation

Components registered with `interpolate` on entities the client does not predict are buffered by **server tick** (not arrival time) and rendered `interpolationDelay` ms behind the newest snapshot (measured from its mean arrival time), between the two samples around the render tick.

The render tick runs on its own clock: it advances with frame time, independent of the client's simulation-clock corrections (time dilation, input-lead changes when RTT or late inputs change, tick resets) and of how many fixed steps a frame runs. It tracks the snapshot stream by speeding up or slowing down by at most 10 %, so interpolated entities never step or move backwards; only a large discontinuity (such as the host's clock jumping) snaps it.

By default `interpolationDelay` is derived: two snapshot intervals plus a 50 ms jitter margin (`2 * syncInterval * 1000 / tickRate + 50`, so 150 ms at 60 Hz / 20 Hz). That covers one lost snapshot under up to ~100 ms of arrival jitter. If you set it yourself, stay above two snapshot intervals plus half the expected jitter. Lower values trade smoothness for latency.

When snapshots run out (several lost in a row), the entity is extrapolated along its last segment for up to `maxExtrapolation` ms (default 100) and then held. When data arrives again it blends back onto the interpolated path over one snapshot interval, so there's no jump. Extrapolation calls your `interpolate` function with `t > 1`. If a type can't extrapolate, clamp `t` in that function or set `maxExtrapolation` to 0 (hold).

Interpolation runs in `Schedules.update` (`UpdateSets.receive`), after the frame's fixed steps, so interpolated entities are sampled at the same moment as the local avatar drawn with `FixedTimestep.alpha`. Order systems that draw interpolated components after `NetInterpolationSystem.systemName`, and don't give interpolated entities fixed-step render interpolation (`PreviousTransform2D`) as well: their values already change every frame.

### Disconnects

When a client leaves (disconnect, timeout, or the host disconnects it), the host applies `NetworkConfig.disconnectPolicy` to the entities it owned and then sends `NetPeerDisconnected`:

- `OwnedEntityPolicy.despawn` (default): despawned with their children, which despawns them on every client.
- `OwnedEntityPolicy.releaseToHost`: kept, and ownership moves to the host (`ownerId` 0).
- `OwnedEntityPolicy.holdForReturn`: kept and owned by the host for now; when a client joins again with the same player identity (see [Player Identity](#player-identity)), ownership goes back to it and `NetPeerConnected.returned` lists the entities. Anonymous players' entities are just released to the host.

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
| `sendBudgetBytesPerSecond` | 65536 | Bytes a second each client may be sent; control, then snapshots, then resource chunks |
| `relevance` | null | `(world, entity, peerId) => bool` hiding entities from chosen clients |
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
| `sendAction(value, {target})`, `resolveAction(action, {accepted, reason})`, `pendingActions<T>()` | [Player actions](#8-player-actions) |
| `stats` | Counters: rejected inputs/RPCs/messages/actions, corrections, snapshot chunks, resource chunks, late inputs, tick resets, oversized entities |
| `NetworkSession.maxEntityStateBytes` | Largest replicated state of one entity (see [Snapshots](#snapshots)) |
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
host.update();  // Check timeouts, ping peers (RTT)
host.broadcast(PacketType.custom, stateBytes);
```

Every send is one unreliable datagram: it may be lost, duplicated or reordered. For reliable, ordered delivery, layer a `ReliableChannel` over the datagrams (see [Reliable delivery](#reliable-delivery)).

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
  if (event.type == PacketType.custom) {
    // Handle your message
  }
});

// Each frame
client.update();  // Ping, timeout check
client.send(PacketType.custom, inputBytes);
```

`connect()` accepts a numeric address or a hostname such as `'localhost'`. Hostnames are resolved with `InternetAddress.lookup` before connecting, preferring an IPv4 result (the UDP transport is IPv4-only for now); `client.hostAddress` then holds the numeric address. Pass `hostResolver:` to `NetworkClient` to plug in your own resolution.

Client states: `disconnected` → `connecting` → `connected` → `failed`.

### Connection Handshake

1. Client sends a `connect` packet, and re-sends it every `connectRetryInterval` (default 250 ms) until the host answers or `connectionTimeout` expires, so a single lost packet doesn't stall the handshake. The retries run on their own timer; you don't need to call `client.update()` during `connect()`.
2. Host checks capacity — sends `connectRejected` if full
3. If an `authenticator` is set, the host awaits it. Duplicate `connect` packets from the same address are ignored while authentication is in flight, so one client never becomes two peers. At most `maxPendingConnects` (default 64) connects are authenticated at once; connects from further addresses are ignored until a slot frees up (the client keeps retrying), so a flood of connects can't pile up authenticator calls.
4. If accepted, host creates a `Peer` and sends `connectAccepted` with the assigned peer ID. If the client keeps retrying because that reply was lost, the host sends the acceptance again (same peer ID); this retry loop is what makes the acceptance reliable.
5. Client transitions to `connected`

## NetworkIdentity

`NetworkIdentity` records an entity's network id and owner. The replication layer inserts it (from `Replicated` on the host, from spawn messages on clients):

```dart
final id = world.get<NetworkIdentity>(entity)!;
id.netId;        // network id, the same on every machine
id.ownerId;      // 0 = host-owned, >0 = client peer ID
id.hasAuthority; // this instance owns it: ownerId == localPeerId
id.ownerId = 2;  // on the host: hand the entity to peer 2 (replicated)
```

`hasAuthority` is `ownerId == localPeerId` (`localPeerId` is 0 on the host, the client's own peer id on a client), so on the host it is `true` only for host-owned entities and it follows ownership changes. The host still simulates every entity; a client-owned entity is driven by that client's inputs.

The `NetworkEntityRegistry` resource provides entity ↔ netId lookups. The replication layer maintains it; its mutators are internal.

```dart
final registry = world.getResource<NetworkEntityRegistry>()!;
final entity = registry.getEntity(netId);
final netId = registry.getNetId(entity);
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
stateUpdate, input, replication, tickSync,
custom
```

The replication layer uses `stateUpdate` (snapshot chunks), `input` (redundant per-tick inputs), `replication` (its ordered reliable channel) and `tickSync`. `custom` is free for your own protocols.

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

`NetworkHost` and `NetworkClient` send single, unreliable datagrams; only the connect handshake retries on its own. Reliable delivery is `ReliableChannel`: one per direction of a connection, carried in your own packets (the replication layer uses `PacketType.replication`).

```dart
final channel = ReliableChannel();
channel.enqueue(messageBytes);              // ordered, reliable, deduplicated

// Every tick: new messages plus resends of unacked ones older than the timeout.
for (final packet in channel.takePackets(
  nowMs: clock.nowMs,
  resendAfterMs: 200,
  ack: channel.receivedAck,                 // piggyback our cumulative ack
)) {
  client.send(PacketType.custom, packet);
}

// On receive:
channel.onAck(channel.receivePacket(payload));
for (final message in channel.drain()) { /* in order, exactly once */ }
```

Acks are cumulative, so a lost ack is repaired by the next packet. The channel never gives up on a message, and it is bounded:

- **Send side**: at most `maxUnacked` messages (default `ReliableChannel.defaultMaxUnacked`, 16384) wait for an ack. Once `isFull`, `enqueue` throws `StateError`. The ordered stream can't be completed after that, so drop the connection: the replication layer disconnects such a peer (`Reliable channel overflow`) or ends the client session.
- **Receive side**: at most `maxReceiveWindow` out-of-order messages (default `ReliableChannel.defaultMaxReceiveWindow`, 1024; the replication host uses 256 for client channels) are buffered; a message further ahead is dropped and arrives again with the sender's resend.
- **Message size**: `ReliableChannel.maxMessageBytes` (1134 bytes); one message always fits one packet.

### Round-trip time

RTT is measured with ping/pong. Each side puts its own monotonic-clock timestamp in a `ping`, and the other side echoes it back unchanged in the `pong`, so the sample is always `now − echoed` on the same clock and is correct across the 32-bit wrap. `client.update()` pings the host, and `host.update()` pings each peer, every `pingInterval`. Results feed `NetworkClient.rtt` and `Peer.rtt`, which are exponential moving averages (the replication layer derives its resend timeout from them). Samples that are negative or above 60 s are discarded.

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

## Player Identity

A player identity is an opaque, stable string the host uses to recognise a returning player, whatever transport or address they connect from. By convention it starts with the scheme that issued it, so identities from different sources never collide: `dev:<name>` for local development and LAN play over direct IP, `steam:<SteamID64>` for Steam (from `fledge_net_steam`), `hub:<account>` for a gateway or hub service. Games compare identities; they never parse them.

The client says who it is with an `IdentityProvider`, and the host checks it with an `IdentityVerifier`:

```dart
// Development / LAN: a name kept per install, trusted as claimed.
final config = NetworkConfig(
  identityProvider: DevIdentityProvider(savedName),
  identityVerifier: const TrustingVerifier(),
  disconnectPolicy: OwnedEntityPolicy.holdForReturn,
);

// A hub: the client presents a token from sign-in; the host asks the hub.
final hubConfig = NetworkConfig(
  identityProvider: TokenIdentityProvider(() async => hub.currentSession()),
  identityVerifier: TokenVerifier((id, token) => hub.verify(id, token)),
);

// Several at once, by scheme.
final mixed = NetworkConfig(
  identityVerifier: SchemeVerifier({
    'dev': const TrustingVerifier(),
    'hub': TokenVerifier((id, token) => hub.verify(id, token)),
  }),
);
```

- Without a provider a client joins anonymously; without a verifier the host accepts any well-formed identity as claimed (fine on a LAN, not on the internet).
- The identity travels in the connect handshake; its proof travels with the password in the credentials, each length-prefixed. A verifier rejection is reported like a wrong password ("Authentication failed").
- `NetworkSession.localIdentity` is this player's identity (the host's too); on the host, `identityOf(peerId)` and `peerFor(identity)` map between peers and identities, and `NetPeerConnected` / `NetPeerDisconnected` carry it.
- A client joining with the identity of a player who is still connected (after a crash, or from a new address) replaces the old connection instead of waiting for it to time out. `NetworkHost(replaceSameIdentity: true)` enables this below the session; `NetworkSession` always does.
- `ClientIdentity.validate` rules: non-empty, at most 128 bytes of UTF-8, no control characters.

## Steam

`fledge_net_steam` runs `fledge_net` over Steam Networking Messages: Valve's relays and NAT traversal, so friends host and join without forwarding ports, and Steam authenticates every datagram's sender.

```dart
final steam = Steam.init(appId: 480); // Valve's test app during development

final config = NetworkConfig(
  identityProvider: SteamIdentityProvider(steam),   // steam:<SteamID64>
  identityVerifier: const SteamIdentityVerifier(),  // only from that Steam user
);

await session.host(transport: SteamTransport(steam));                  // host
await session.join('steam:76561198000000000', 0,
    transport: SteamTransport(steam));                                // friend
```

- Addresses are Steam users (`NetAddress('steam:<SteamID64>', 0)`); the transport resolves `steam:` hosts itself (`AddressResolver`), so they never reach DNS.
- The identity needs no proof: under `SteamTransport`, the verifier is told the connect's source address (a Steam ID Steam has authenticated) and accepts a `steam:` identity only from that user. `IdentityVerifier.verify` receives `source` for this.
- `SteamCoop` hosts and joins through a Steam lobby: the host opens a lobby (naming itself as host) and invites friends from the overlay; friends join by accepting the invite or picking "Join Game", including when Steam launches the game with `+connect_lobby <id>` (`Steam.lobbyFromArgs`).
- It needs the Steam client running and the `steam_api` library from the Steamworks SDK shipped with the game (or `Steam.init(libraryPath: …)`). See the package README.

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

## Authority Model

`NetworkIdentity` tracks entity ownership:

```dart
identity.isOwnedBy(peerId);  // ownerId == peerId
identity.hasAuthority;       // owned by this instance
identity.ownerId = newOwner; // host: transfer ownership (replicated)
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

Host peer timeouts and pings also follow the injected clock, so advancing a `ManualNetClock` past `connectionTimeout` times out a silent peer without real waiting. `connect()`'s overall timeout and its retries still run on real timers.

### Transport delivery contract

Each received datagram is delivered exactly once. If anything listens to `transport.onReceive` (as `NetworkHost` and `NetworkClient` do), packets go to the stream only. Otherwise they go to a bounded buffer (`maxBufferedPackets`, default 1024, oldest dropped first) that `transport.receive()` drains. `UdpTransport`, `LoopbackTransport` and `EncryptedTransport` all follow this contract. `UdpTransport` also queues sends that hit a full OS buffer (up to `maxQueuedSends`) instead of silently dropping them, and accepts a `bindAddress` (e.g. `InternetAddress.loopbackIPv4`).

## API Reference

See [NetworkConfig](#networkconfig) and [NetworkSession](#networksession) above.

### NetworkHost

| Method | Description |
|--------|-------------|
| `start(port)` | Bind and start listening |
| `stop()` | Disconnect all peers (redundant notices) and close |
| `update()` | Process timeouts, ping peers |
| `sendTo(peerId, type, data)` | Send to one peer (payload ≤ `Packet.maxPayloadBytes`) |
| `broadcast(type, data)` | Send to all connected peers |
| `broadcastExcept(excludeId, type, data)` | Broadcast excluding one peer |
| `disconnectPeer(id, reason)` | Force disconnect a peer |
| `getPeer(id)` | The connected `Peer` (e.g. for `rtt`), or null |
| `onProtocolMismatch` | Stream of `ProtocolMismatchEvent` |

Constructor options: `maxPeers`, `connectionTimeout`, `authenticator`, `maxPendingConnects` (default 64), `pingInterval` (default 1 s), `clock` (pings, RTT and peer timeouts), `disconnectRedundancy` (default 3), `disconnectRedundancyInterval` (default 5 ms).

### NetworkClient

| Method | Description |
|--------|-------------|
| `connect(host, port, {credentials})` | Connect to a host (IP or hostname) with optional auth |
| `disconnect()` | Send `disconnectRedundancy` disconnect notices, then close |
| `update()` | Process pings and timeouts |
| `send(type, data)` | Send data to host (payload ≤ `Packet.maxPayloadBytes`) |
| `state` | Current `ClientState` |
| `rtt` | Smoothed round-trip time in ms |
| `lastStateReason` | Reason from the last state change (e.g. `Authentication failed`) |
| `onProtocolMismatch` | Stream of `ProtocolMismatchEvent` |

Constructor options: `connectionTimeout`, `pingInterval`, `connectRetryInterval` (default 250 ms), `clock`, `hostResolver`, `disconnectRedundancy` (default 3), `disconnectRedundancyInterval` (default 5 ms).

### NetworkIdentity

| Property | Type | Description |
|----------|------|-------------|
| `netId` | `int` | Unique network entity ID |
| `ownerId` | `int` | Owning peer (0 = host); assign on the host to transfer ownership |
| `localPeerId` | `int` | Peer id of this instance (0 on the host) |
| `hasAuthority` | `bool` | This instance owns the entity (`ownerId == localPeerId`) |
| `isOwnedBy(peerId)` | `bool` | Check if peer owns this entity |

## See Also

- [App & Plugins Guide](/docs/guides/app-plugins) - Plugin system introduction
- [Input Handling](/docs/plugins/input) - Local input processing
