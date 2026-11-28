# How Replication Works

This page explains what the replication layer does each tick: how clients keep time with the host, what travels reliably and what goes in snapshots, how interest management and the send budget decide what each client gets, and how prediction and interpolation hide latency. Start with the [overview](/docs/networking/overview) if you haven't set up a session yet.

## Ticks

All simulation runs in the fixed-timestep chain, and `NetworkConfig.tickRate` must equal the `FixedTimestep` rate. `config.fixedTimestep()` builds a matching one; `host` and `join` throw if they differ. The host also sends its tick rate in the welcome, and a client with another rate ends its session (`Tick rate mismatch`).

The `NetworkTick` resource holds the tick numbers:

| Member | Host | Client |
|---|---|---|
| `serverTick` | The authoritative tick, advanced once per fixed step | The estimate of the host's current tick |
| `localTick` | Equal to `serverTick` | The tick this client simulates and produces input for |
| `lead` | `0` | `localTick - serverTick` |
| `deltaTime` | `FixedTimestep.stepSeconds` | Same |
| `synced` | `true` while hosting | `true` once tick sync finished |

A client's `localTick` **leads** the host by about RTT/2 plus `inputLeadBufferTicks` (default 2), so an input for tick `t` reaches the host just before the host simulates `t`:

- On connect, a tick-sync handshake (a few request/response round trips, lowest RTT wins) sets the lead.
- Afterwards every snapshot is a sample, and small errors are corrected by **time dilation**: the client runs its fixed steps slightly faster or slower by nudging the `FixedTimestep` accumulator (`FixedTimestep.nudge`, at most one step per call). The tick sync owns that accumulator while a client session runs, so don't nudge it yourself.
- Large errors (more than 10 ticks, for example after a stall) snap the tick. The prediction history restarts at the new tick but the predicted state is kept, so the avatar doesn't snap back. `NetworkStats.tickResets` counts these.
- If the host reports late inputs, the client widens its buffer a tick at a time; after 10 seconds without any, it narrows it again a tick at a time.

`session.tickSync` exposes the client's `ClientTickSync` (lead, RTT, error) for diagnostics.

## Systems

`NetworkPlugin` adds seven systems. They are always registered but do nothing while no session is active.

| System | Schedule | Ordering | Does |
|---|---|---|---|
| `NetPumpSystem` | `first` | `FirstSets.platform` | Drives the connection (pings, timeouts), answers tick sync, turns connection changes into events, resends reliable messages |
| `NetReceiveSystem` | `first` | After the pump and every `FirstSets` phase | Client: applies spawns, despawns, hierarchy, ownership, snapshots, resources, RPC events. Host: validated inputs and RPCs, disconnect policy |
| `NetInterpolationSystem` | `update` | `UpdateSets.receive` | Writes interpolated component values, after the frame's fixed steps |
| `NetTickSystem` | `fixedFirst` | | Advances `NetworkTick` (and applies time dilation on clients) |
| `NetInputSystem` | `fixedPreUpdate` | After `NetSets.localInput` | Builds this tick's `NetInputs<I>` and, on the host, `NetActions<T>` |
| `NetPredictSystem` | `fixedPreUpdate` | After `NetInputSystem` | Host: applies `step` to every entity with an input. Client: reconciles and predicts its own entities |
| `NetSendSystem` | `fixedLast` | | Host: assigns network ids, computes interest, sends spawns, despawns and snapshots. Client: records predictions, sends inputs |

Each system has a `static const String systemName` to order against, for example `after: [NetInputSystem.systemName]`. `NetworkSystems(registry)` builds the same seven instances if you assemble an app by hand. Each system declares the components and resources it touches (the registered component types among them), so the scheduler orders it against your systems. The plugin has no ordering ambiguities on its own or with `PhysicsPlugin`, `RenderPlugin` and `TransformPropagateSystem`. Game systems that write replicated components in the same schedules should still order themselves against these systems explicitly.

Network callbacks never touch the `World`: they append to queues that these systems drain.

## Spawns, despawns and hierarchy

Spawns (with the full initial component state), despawns, re-parenting, ownership changes and RPCs travel on an **ordered reliable control channel** per client (a `ReliableChannel`: sequence numbers, cumulative acks piggybacked on every packet, resend after about 1.5 RTT). Replicated resources travel on a second reliable channel, the **bulk channel**, so a large world streaming in never delays an RPC. Action results go on the bulk channel too, behind the resource chunks queued before them. A message bigger than one packet (up to 1 MiB) is split into fragments and reassembled in order.

- A parent is always spawned before its children. A child whose parent is unknown is kept as an orphan and attached when the parent arrives.
- Removing `Replicated` from an entity, or despawning it, despawns it on clients.
- On clients, `NetEntitySpawned` and `NetEntityDespawned` report each replicated entity that appears or goes away (including when it enters or leaves the client's interest set).

The `NetworkEntityRegistry` resource maps network ids to local entities. The replication layer maintains it; games only look things up:

<!-- snippet-setup
final world = World();
const netId = 1;
final entity = world.spawn().entity;
-->

```dart
final registry = world.getResource<NetworkEntityRegistry>()!;
final Entity? local = registry.getEntity(netId);
final int? id = registry.getNetId(entity);
```

## Snapshots

Every `tickRate / syncRate` ticks (`NetworkConfig.syncInterval`) the host sends each client a snapshot of **what changed** among the entities relevant to it, compared with that client's last acknowledged copy:

- Each component has a version that changes when its encoded bytes do. Per client, the host remembers the versions the client has acknowledged. An entity is listed only if a component changed or one was added or removed, and then only the changed components' bytes are sent, with a mask of which components exist so removals arrive too.
- Snapshot chunks are numbered per client, and clients acknowledge them (newest plus a 32-chunk bitfield) in every input packet. A lost chunk is never acknowledged, so what it carried is sent again.
- The owner of an entity always gets its predicted components, which reconciliation needs every snapshot.
- At least one chunk (maybe empty) goes every sync. It carries the server tick, the input ack and the control-channel ack.
- When every chunk of a tick has arrived, the client knows the entities it didn't hear about held still, and stops interpolating them there (so a mover that stops comes to rest where it stopped).

Chunks are self-contained and at most `Packet.maxPayloadBytes`; one entity never spans two (an entity whose changes don't fit one goes reliably instead, see [Limits](#limits)). Older data never overwrites newer data. 2000 static entities cost well under 1 KB/s once acknowledged.

### Limits

- A registry holds at most 32 component types (`ReplicationRegistry.maxComponents`).
- A snapshot entry carries at most `NetworkSession.maxSnapshotEntityBytes` (1112 bytes) of one entity's changes, so that it fits one datagram. Larger entities still replicate in full: a spawn always travels on the reliable control channel, split into fragments when it's bigger than one packet, and a delta too large for a snapshot goes there too, as a reliable state message. Until the client acknowledges that message, the entity's later changes follow it on the same channel, so a snapshot never overtakes it and state is applied in tick order either way. Then it's back to snapshots. Deltas only carry the components that changed, so an entity with a large component that rarely changes (a player's inventory) costs a reliable message only when that component changes. `NetworkSession.stats.reliableEntityUpdates` counts these messages.
- One entity's encoded state, as a client gets it (its replicated components plus a few bytes of framing), may be at most `NetworkSession.maxEntityStateBytes` (64 KiB), a hard cap far above what an entity should hold. Its owner gets every component; everyone else gets it without owner-only ones, so large private state only counts against its owner. Put larger state in a [replicated resource](#replicated-resources).
- The host doesn't replicate an entity over the cap to the clients it's too large for (just its owner, when only its owner-only components make it too large). It logs a warning once (`dart:developer`, name `fledge_net`), counts it in `NetworkSession.stats.oversizedEntities`, never spawns it on those clients (or despawns it there if it grew past the cap), and replicates it again once it fits. Everything else keeps replicating. Children of a skipped entity wait on clients as orphans until it arrives.

## Replicated resources

Large shared state, such as a tile map, belongs in a resource rather than thousands of entities. Register it with a `ResourceCodec` that splits it into chunks and gives each chunk a version. `ChunkVersions` keeps the versions for you:

<!-- snippet-setup
class Farm {
  static const chunkSize = 10; // 10x10 tiles per chunk
  static const width = 100, height = 100;
  final tiles = Uint8List(width * height);
  final versions = ChunkVersions();

  int get chunkCount => (width ~/ chunkSize) * (height ~/ chunkSize);

  Iterable<int> tilesOf(int chunk) sync* {
    final cx = chunk % (width ~/ chunkSize) * chunkSize;
    final cy = chunk ~/ (width ~/ chunkSize) * chunkSize;
    for (var y = cy; y < cy + chunkSize; y++) {
      for (var x = cx; x < cx + chunkSize; x++) {
        yield y * width + x;
      }
    }
  }

  int chunkOf(int tile) =>
      (tile ~/ width) ~/ chunkSize * (width ~/ chunkSize) +
      (tile % width) ~/ chunkSize;
}

class Weather {
  int kind = 0;
  int version = 0;
}
-->

```dart
class FarmCodec extends ResourceCodec<Farm> {
  @override
  int chunkCount(Farm farm) => farm.chunkCount;

  @override
  int chunkVersion(Farm farm, int chunk) => farm.versions.of(chunk);

  @override
  void encodeChunk(Farm farm, int chunk, PacketBuilder out) {
    for (final tile in farm.tilesOf(chunk)) {
      out.writeByte(farm.tiles[tile]);
    }
  }

  @override
  void decodeChunk(Farm farm, int chunk, PacketReader input) {
    for (final tile in farm.tilesOf(chunk)) {
      farm.tiles[tile] = input.readByte();
    }
  }
}

final registry = ReplicationRegistry()
  ..resource<Farm>('farm', FarmCodec(), create: Farm.new)
  // A small resource as one chunk, sent whenever its version changes.
  ..resource<Weather>(
    'weather',
    ResourceCodec<Weather>.whole(
      encode: (w, out) => out.writeByte(w.kind),
      decode: (w, input) => w.kind = input.readByte(),
      version: (w) => w.version,
    ),
    create: Weather.new,
  );

// On the host, whenever a tile changes:
void setTile(Farm farm, int tile, int value) {
  farm.tiles[tile] = value;
  farm.versions.bump(farm.chunkOf(tile));
}
```

- The host sends each client the chunks whose version changed since it last sent them, reliably on the bulk channel. A joining client receives every chunk. Versions only need to differ; `ChunkVersions.bump(chunk)` increments one, `bumpAll(count)` marks every chunk changed.
- Clients apply chunks into their own instance (made with `create` if the world has none) and receive a `NetResourceUpdated(key, chunk)` event per chunk.
- Override `void resize(T resource, int chunkCount)` for resources whose chunk count varies: clients call it with the host's chunk count before decoding each chunk.
- `ResourceCodec.whole({encode, decode, version})` sends a small resource (weather, a calendar, a wallet) as one chunk.
- A 100x100 tile grid with ten changes a second costs under 4 KB/s.

## Send budget

Each client has a byte budget (`NetworkConfig.sendBudgetBytesPerSecond`, 64 KiB/s by default) that the host spends every tick in priority order: control messages (spawns, RPCs), then snapshots, then resource chunks. This budget is fledge_net's congestion control: there is no separate congestion controller, and the budget doesn't adapt to measured loss. Set it to what your players' upload can carry.

What doesn't fit waits for the next tick. Unsent snapshot changes stay unacknowledged and go later (a rotating start gives every entity its turn). Spawns and resource chunks are only queued while about two seconds of the budget is unacknowledged. A join of tens of thousands of entities therefore streams in at the budget instead of overflowing the reliable channel. A client that stops acknowledging altogether is eventually disconnected with "Reliable channel overflow" (or by `connectionTimeout`).

## Interest management

With `NetworkConfig.interestRadius` and an interest position (`ReplicationRegistry.positionFrom` or `position`) set, each client receives only:

- entities within `interestRadius` of the **global** position of the first positioned replicated entity it owns,
- entities it owns, entities marked `Replicated(alwaysRelevant: true)`, and entities without a position,
- and the ancestors of all of these (a child is useless without its parent), even when they're outside the radius.

A client that owns no positioned entity receives everything. Positioned entities are bucketed in a grid of `interestRadius` cells, so the radius check looks at nearby cells only.

These rules apply with or without a radius:

- `Replicated(ownerOnly: true)` sends an entity only to its owner (a private entity). It wins over `alwaysRelevant`.
- `registry.component<T>(…, ownerOnly: true)` sends one component only to the entity's owner; other clients get the entity without it (a player's inventory on a shared player entity). It follows ownership changes.
- `NetworkConfig.relevance`, `(world, entity, peerId) => bool`, hides entities from chosen clients. It isn't asked about entities the client owns, and it runs for every replicated entity and client once a fixed tick, so keep it cheap.
- Hiding is inherited: an entity whose parent (or any ancestor) is hidden from a client, by `ownerOnly` or by `relevance`, is hidden from that client too. A private chest keeps its contents private; a relevant child never drags a hidden parent along.

The relevant set is recomputed every tick: entities that enter it are spawned on the client, entities that leave it are despawned there.

## Inputs

Clients send their inputs every tick, redundantly: each packet repeats every input the host hasn't acknowledged yet (up to `inputRedundancy`). The host buffers them per client and entity, and every tick hands exactly one input per controlled entity to `NetInputs<I>`:

<!-- snippet-setup
class MoveInput {
  final double dx, dy;
  const MoveInput(this.dx, this.dy);
}
-->

```dart
final inputs = world.getResource<NetInputs<MoveInput>>()!;
for (final entry in inputs.entries) {
  // entry.peerId, entry.entity, entry.netId, entry.tick, entry.input
  if (entry.repeated) {
    // The real input was late or lost; this repeats the previous one.
  }
}
final mine = inputs.forEntity(entity)?.input;
```

If an input is missing, the host repeats the previous one for up to `maxInputRepeatTicks` ticks, then the entity gets no input. Inputs that arrive after their tick was simulated are dropped; if the host had repeated an input for that tick, it counts as late (`NetworkStats.lateInputs`) and the client widens its lead in response. The host accepts inputs only for entities the sender owns: see [Authority](/docs/networking/security-identity#authority).

## Prediction and reconciliation

For entities it owns, a client applies `step(state, input, dt)` (with `dt = FixedTimestep.stepSeconds`) as soon as the input is submitted, and records the predicted state per tick. When a snapshot arrives, the server state for tick `T` is compared with the recorded prediction for `T` using your `error` function:

- Within `tolerance` nothing happens.
- Otherwise the client resets to the server state, replays the unacknowledged inputs `T+1 .. now` with `step`, and sends `NetPredictionCorrected(entity, netId, tick, error)`. `NetworkStats.corrections` counts these.

A deterministic `step` never triggers a correction. Things the client can't predict (the host teleports the avatar, a host-only system pushes it) are corrected within one round trip.

Only `step` is replayed, so keep everything that affects the predicted component inside `step`, or accept corrections for the rest. A step that needs the world (a collision map, solid tiles) is registered as `stepWith: (state, input, context) => ...` instead. Its `PredictContext` gives the world (read only), the entity, the tick, `dt` and whether this is a replay. Replays see the present world, not the one at the replayed tick, so depend on data that rarely changes (the map), not on other moving entities.

### Smoothing corrections

The simulation always takes the corrected state. `correctionBlend` below 1 (it requires `interpolate` on the component) smooths a correction **for drawing only**. While it lasts, the entity carries `NetSmoothed<S>`, the value to draw. It starts where the old prediction was drawn, moves with the same inputs as the entity, and closes `correctionBlend` of the remaining gap each tick, after which it's removed:

```dart
final toDraw = world.get<NetSmoothed<Transform2D>>(entity)?.value ??
    world.get<Transform2D>(entity);
```

## Interpolation

Components registered with `interpolate` on entities the client doesn't predict are buffered by **server tick** (not arrival time) and drawn `interpolationDelay` ms behind the newest snapshot (measured from its mean arrival time), between the two samples around the render tick.

**The render clock is separate from the simulation clock.** The client's simulation clock is corrected all the time: time dilation nudges the `FixedTimestep` accumulator, the input lead changes with RTT and late inputs, and large errors reset the tick. Drawing remote entities on that clock would show every correction as a hitch. Instead, an `InterpolationClock` advances the render tick by exactly the frame time the `FixedTimestep` received, with every correction removed, however many fixed steps a frame ran. It tracks the snapshot stream by running at most 10% faster or slower than real time, so interpolated entities never step or move backwards; only a large discontinuity (such as the host's clock jumping) snaps it.

By default `interpolationDelay` is derived: two snapshot intervals plus a 50 ms jitter margin (`2 * syncInterval * 1000 / tickRate + 50`, so 150 ms at 60 Hz / 20 Hz). That covers one lost snapshot under up to about 100 ms of arrival jitter. If you set it yourself, stay above two snapshot intervals plus half the expected jitter. Lower values trade smoothness for latency.

When snapshots run out (several lost in a row), the entity is extrapolated along its last segment for up to `maxExtrapolation` ms (default 100) and then held. When data arrives again it blends back onto the interpolated path over one snapshot interval, so there's no jump. Extrapolation calls your `interpolate` function with `t > 1`. If a type can't extrapolate, clamp `t` in that function or set `maxExtrapolation` to 0 (hold).

Interpolation runs in `Schedules.update` (`UpdateSets.receive`), after the frame's fixed steps, so remote entities are sampled at the same moment as the local avatar drawn with `FixedTimestep.alpha`. Order systems that draw interpolated components after `NetInterpolationSystem.systemName`, and don't give interpolated entities fixed-step render interpolation (`PreviousTransform2D`) as well: their values already change every frame.

## Disconnects

When a client leaves (it disconnects, times out, or the host disconnects it), the host applies `NetworkConfig.disconnectPolicy`, an `OwnedEntityPolicy`, to the entities it owned, then sends `NetPeerDisconnected` (with `ownedNetIds` and the `policy` applied):

| `OwnedEntityPolicy` | What happens to the departed player's entities |
|---|---|
| `despawn` (default) | Despawned with their children, which despawns them on every client. |
| `releaseToHost` | Kept, and ownership moves to the host (`ownerId` 0). |
| `holdForReturn` | Kept and owned by the host for now. When a client joins again with the same [player identity](/docs/networking/security-identity#player-identity), ownership goes back to it and `NetPeerConnected.returned` lists the entities. Anonymous players' entities are simply released to the host. |

When a client's session ends, it despawns every replicated entity and sends `NetDisconnected`. `session.close()` does this before it returns, so a client that leaves and stops ticking (a menu, loading its own game) has nothing of the host's world left over. A client that loses the host (timeout, kicked, handshake mismatch) ends its session the same way on its next receive pass, with the reason in `session.lastError`.

When the host closes its session, every connected client leaves exactly as above: the policy is applied to what it owned and a `NetPeerDisconnected` is sent for it (reason: the one passed to `close`), followed by `NetDisconnected`. Then the session is forgotten, at once: no entity keeps its `NetworkIdentity`, and a `Replicated` marker that named a client as its owner names the host again, since peer ids are per session (the next session's peer 1 is someone else). The markers stay, so hosting again replicates the same entities under new network ids.

A player reconnecting with the same identity replaces their old connection. The old connection's `NetPeerDisconnected` always comes before the new one's `NetPeerConnected`, so under `holdForReturn` the new connection gets back what the old one held.

Disconnect notices are sent redundantly (3 identical copies a few ms apart), so a single lost datagram doesn't leave a departed player's entities around until `connectionTimeout`. Duplicates are ignored.
