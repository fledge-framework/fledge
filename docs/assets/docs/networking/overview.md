# Networking

`fledge_net` adds multiplayer to a Fledge game. One player hosts, the others join, and the host runs the authoritative simulation. An ECS **replication layer** on top of a UDP connection spawns your entities on clients and keeps their state in sync. It carries each player's inputs (checking that the player owns the entity), predicts the local player so controls feel instant, interpolates everyone else, and delivers RPCs and player actions.

It's built for small sessions, such as 2 to 4 player co-op over a LAN, direct IP or [Steam](/docs/networking/steam).

## What you need

```yaml
dependencies:
  fledge_net: ^0.7.1
  # Optional: play over Steam (relays, NAT traversal, Steam identities)
  fledge_net_steam: ^0.7.1
```

- **Pure Dart** (Dart `^3.11`, no Flutter dependency), so it also runs in tests and headless servers. It doesn't know about `Transform2D`: you tell it how to encode your components (your transform included) with codecs.
- **Platforms**: desktop first (Windows, macOS, Linux). The default `UdpTransport` uses `dart:io` sockets (IPv4 only), so **the web isn't supported**: there is no WebSocket or WebRTC transport. Mobile should work over `dart:io` but is untested. A sandboxed macOS app needs the `com.apple.security.network.client` and `com.apple.security.network.server` entitlements to open sockets.
- **Fixed timestep**: the simulation runs in the fixed-timestep schedules, and `FixedTimestep` must tick at `NetworkConfig.tickRate`. `config.fixedTimestep()` builds a matching one.

## Concepts

| Concept | What it is |
|---|---|
| **Session** | The `NetworkSession` resource. `host()` starts hosting, `join()` connects to a host, `close()` ends it. With no session the plugin's systems do nothing, so the same `App` works for single player. |
| **Role** | `session.role` is a `NetworkRole`: `offline`, `host` or `client`. `NetworkConfig.mode` (a `NetworkMode` with the same three values) mirrors it; the session sets both. |
| **Host authority** | Only the host spawns, despawns, re-parents and changes ownership. Clients send inputs, actions and RPCs, and the host checks each one. |
| **Replication registry** | A `ReplicationRegistry` lists what goes over the wire: component types and their codecs, the input type, prediction, RPCs, actions and replicated resources. Host and clients build the same one; the handshake refuses mismatched builds. |
| **Replicated entity** | A host entity with the `Replicated` marker. It gets a network id and a `NetworkIdentity` (net id + owner peer id), and appears on every client it is relevant to. |
| **Peer id** | The host is peer `0`; clients get `1, 2, …` when they connect. `NetworkIdentity.ownerId` says which peer controls an entity. |
| **Tick vs sync** | The simulation advances one **tick** per fixed step (`tickRate`, 60 Hz by default). The host sends state **snapshots** every `tickRate / syncRate` ticks (20 Hz by default). |
| **Inputs, actions, RPCs** | **Inputs** are level state sent every tick (the stick is held left). **Actions** are discrete things a player does, delivered exactly once and confirmed by the host (use an item). **RPCs** are reliable messages (an emote, a "you win"). |
| **Prediction** | The owning client runs your pure `step` function on its own inputs straight away, and corrects itself when the host disagrees. |
| **Interpolation** | Entities a client doesn't predict are drawn a little in the past, between two snapshots, so they move smoothly. |

The details are in [How replication works](/docs/networking/replication). Every option is listed in [Configuration](/docs/networking/configuration).

## Co-op quickstart

In this example, players ride a shared vehicle that the host owns. Each player's avatar is a child of the vehicle, and that player controls it.

<!-- snippet-setup
class Health {
  final int hp;
  const Health(this.hp);
}

class MoveInput {
  final double dx, dy;
  const MoveInput(this.dx, this.dy);
}

class Emote {
  final String name;
  const Emote(this.name);
}

class UseItem {
  final int slot;
  const UseItem({required this.slot});
}

final healthCodec = NetCodec<Health>.of(
  encode: (h, out) => out.writeInt16(h.hp),
  decode: (r) => Health(r.readInt16()),
);
final moveInputCodec = NetCodec<MoveInput>.of(
  encode: (m, out) => out..writeFloat32(m.dx)..writeFloat32(m.dy),
  decode: (r) => MoveInput(r.readFloat32(), r.readFloat32()),
);
final emoteCodec = NetCodec<Emote>.of(
  encode: (e, out) => out.writeString(e.name),
  decode: (r) => Emote(r.readString()),
);
final useItemCodec = NetCodec<UseItem>.of(
  encode: (u, out) => out.writeByte(u.slot),
  decode: (r) => UseItem(slot: r.readByte()),
);

/// The vehicle the players ride (set by the host at session start).
class Vehicle {
  final Entity entity;
  Vehicle(this.entity);
}

MoveInput readStick(World world) => const MoveInput(0, 0);
bool canUse(int peerId, UseItem item) => true;
void applyUse(int peerId, UseItem item) {}
ReplicationRegistry buildReplication() => ReplicationRegistry();
final config = NetworkConfig();
final app = App();
final world = app.world;
final session = world.getResource<NetworkSession>()!;
final myAvatar = world.spawn().entity;
const peerId = 1;
-->

### 1. Describe what replicates

Build the same `ReplicationRegistry` on the host and on every client:

```dart
final transformCodec = NetCodec<Transform2D>.of(
  encode: (t, out) => out
    ..writeFloat32(t.translation.x)
    ..writeFloat32(t.translation.y)
    ..writeFloat32(t.rotation),
  decode: (r) =>
      Transform2D.from(r.readFloat32(), r.readFloat32())..rotation = r.readFloat32(),
);

Transform2D lerpTransform(Transform2D a, Transform2D b, double t) =>
    Transform2D.from(
      a.translation.x + (b.translation.x - a.translation.x) * t,
      a.translation.y + (b.translation.y - a.translation.y) * t,
    )..rotation = a.rotation + (b.rotation - a.rotation) * t;

// Pure and deterministic: the host and the owning client both run it.
Transform2D move(Transform2D s, MoveInput i, double dt) => Transform2D.from(
      s.translation.x + i.dx * 120 * dt,
      s.translation.y + i.dy * 120 * dt,
    )..rotation = s.rotation;

ReplicationRegistry buildCoopReplication() => ReplicationRegistry()
  ..component<Transform2D>('transform', transformCodec, interpolate: lerpTransform)
  ..component<Health>('health', healthCodec)
  ..input<MoveInput>(moveInputCodec)
  ..predict<Transform2D, MoveInput>(
    step: move,
    error: (a, b) => (a.translation - b.translation).length,
    tolerance: 0.01,
  )
  ..rpc<Emote>('emote', emoteCodec)
  ..action<UseItem>('use', useItemCodec)
  // World position, for interest management.
  ..positionFrom<GlobalTransform2D>((g) => (g.x, g.y));
```

- A `NetCodec<T>` writes a value to a `PacketBuilder` and reads it back from a `PacketReader`. It must be deterministic: the same value always encodes to the same bytes.
- Register the **local** `Transform2D` (relative to the parent). Never replicate `GlobalTransform2D`: clients rebuild it from the replicated hierarchy with `TransformPropagateSystem`.
- Keys and registration order must match on every machine. The host sends a hash of them (`schemaHash`) in its welcome, and a client whose registry differs ends its session with `Replication schema mismatch`.
- `positionFrom<C>` declares `C` as a read of `NetSendSystem`, so the scheduler orders it against systems that write `C`. For a position computed from several components, use `position((world, entity) => ..., reads: {...})` and list every component the getter reads.

> **Registering from an extension:** inside an `extension ... on ReplicationRegistry`, write `this.component<T>(...)`. A bare `component<T>(...)` resolves to the top-level `component` annotation constant exported by `fledge_ecs` and fails to compile. Cascades (`registry..component<T>(...)`) are unaffected.

### 2. Add the plugin

```dart
void main() {
  final config = NetworkConfig(tickRate: 60, syncRate: 20, interestRadius: 2000);

  final app = App()
    ..insertResource(config.fixedTimestep()) // FixedTimestep must match tickRate
    ..addPlugin(RenderPlugin())
    ..addSystem(TransformPropagateSystem(), schedule: Schedules.preUpdate)
    ..addPlugin(NetworkPlugin(config: config, replication: buildReplication()));
}
```

`NetworkPlugin` inserts `NetworkConfig`, `NetworkTick`, `NetworkEntityRegistry` and `NetworkSession` (plus `NetInputs<I>` / `NetLocalInputs<I>` for your input type, and `NetActions<T>` per action type), registers the network events, and adds the [replication systems](/docs/networking/replication#systems). It freezes the registry: register everything before adding the plugin.

### 3. Host or join

```dart
final session = app.world.getResource<NetworkSession>()!;

await session.host(port: 7777);

// Or, on another machine:
final ok = await session.join('192.168.1.20', 7777);
if (!ok) print('Could not join: ${session.lastError}');
```

- `join` accepts a numeric IPv4 address or a host name. It resolves to `true` once the host accepted the connection. Tick sync and the welcome message follow within a few round trips; then `session.isReady` becomes true and a `NetConnected` event is sent.
- On failure `join` resolves to `false` and `session.lastError` says why (`Authentication failed`, `Server full`, `Connection timeout`, a protocol version mismatch). Problems found after the host accepted (a different tick rate or registry) end the session with `NetDisconnected`, and `lastError` holds the reason too.
- `host` throws if a session is already running, if `FixedTimestep` doesn't match `tickRate`, or if encryption is on without a key.
- `session.close()` ends the session. Call these from a menu callback or a test, not from inside a system.

### 4. Spawn replicated entities on the host

Insert `Replicated` on the host. On the next fixed tick the entity gets a network id and a `NetworkIdentity`, and is spawned, with every registered component it has, on each client it is relevant to.

```dart
class SpawnAvatarsSystem extends System {
  static const String systemName = 'spawn_avatars';

  @override
  SystemMeta get meta => const SystemMeta(
        name: systemName,
        eventReads: {NetPeerConnected},
        resourceReads: {Vehicle},
      );

  @override
  void run(World world) {
    final vehicle = world.getResource<Vehicle>()!.entity;
    for (final e in world.eventReader<NetPeerConnected>().read()) {
      final avatar = world.spawn()
        ..insert(Replicated(owner: e.peerId)) // the joining player controls it
        ..insert(Transform2D.from(e.peerId * 32.0, 0)); // local to the vehicle
      world.setParent(avatar.entity, vehicle);
    }
  }
}

void startHosting(World world) {
  final vehicle = world.spawn()
    ..insert(Replicated(alwaysRelevant: true))
    ..insert(Transform2D.from(0, 0));
  world.insertResource(Vehicle(vehicle.entity));
}
```

Register the system on the host's app with `app.addSystem(SpawnAvatarsSystem(), schedule: Schedules.update)`. It only sees events on the host, because only the host sends `NetPeerConnected`.

Parents are replicated by network id and attached on the client with `world.setParent`; a child that arrives before its parent waits until the parent spawns. Moving the vehicle on the host moves every avatar on every client: only the vehicle's transform changes, and `TransformPropagateSystem` does the rest.

### 5. Submit input

Every instance, host included, submits input for the entities it owns. Put the system in `Schedules.fixedPreUpdate` and join `NetSets.localInput` (the plugin orders that set before `NetInputSystem`):

```dart
final submitMove = FunctionSystem(
  'submit_move',
  sets: [NetSets.localInput],
  reads: {ComponentId.of<NetworkIdentity>()},
  resourceReads: {NetworkSession},
  resourceWrites: {NetLocalInputs<MoveInput>},
  run: (world) {
    final session = world.getResource<NetworkSession>()!;
    if (!session.isReady) return;
    final inputs = world.getResource<NetLocalInputs<MoveInput>>()!;
    for (final (entity, id) in world.query1<NetworkIdentity>().iter()) {
      if (id.ownerId == session.localPeerId) {
        inputs.submit(entity, readStick(world));
      }
    }
  },
);
app.addSystem(submitMove, schedule: Schedules.fixedPreUpdate);
```

With `predict` registered, that's all: the owning client applies `step` straight away (no round trip) and the host applies the same `step` when the input arrives. Other host systems read the current tick's inputs from `NetInputs<MoveInput>` (order them after `NetInputSystem.systemName`). Submissions for entities this instance doesn't own are ignored.

### 6. React to events

The network reports what happens as ECS events. Like all Fledge events, they're readable during the frame after they're sent.

| Event | Where | When |
|---|---|---|
| `NetPeerConnected` | host | A client finished connecting (spawn its avatar). |
| `NetPeerDisconnected` | host | A client left; its owned entities were already handled. |
| `NetConnected` | client | Handshake and tick sync are done. |
| `NetDisconnected` | both | The session ended; clients have despawned replicated entities. |
| `NetRpcReceived<T>` | both | An RPC arrived. |

The full list, with every field, is in [Configuration](/docs/networking/configuration#events).

### 7. RPCs

```dart
// Client to host (targeting an entity the client owns is optional):
session.sendRpc(const Emote('wave'), target: myAvatar);

// Host to every client, or to one:
session.sendRpc(const Emote('boost'));
session.sendRpcTo(peerId, const Emote('you-win'));
```

```dart
final showEmotes = FunctionSystem(
  'show_emotes',
  eventReads: {NetRpcReceived<Emote>},
  run: (world) {
    for (final rpc in world.eventReader<NetRpcReceived<Emote>>().read()) {
      print('peer ${rpc.sender} says ${rpc.value.name}');
    }
  },
);
```

RPCs are reliable and travel in order with spawns and despawns, so an RPC that targets a freshly spawned entity never arrives before the spawn. They're flushed at the end of the next fixed tick. The host rejects client RPCs whose target the client doesn't own (see [Authority](/docs/networking/security-identity#authority)).

### 8. Player actions

Inputs are level state sent every tick, so a repeated or lost one does no harm. Discrete things a player *does* (use an item, place a machine, pick something up) are **actions**: each must happen exactly once, in order, and the player wants to see it straight away.

```dart
// Client, from a fixed-step system so the action carries this tick:
final ticket = session.sendAction(const UseItem(slot: 2), target: myAvatar);

// Host, in Schedules.fixedUpdate (after NetInputSystem):
for (final a in world.getResource<NetActions<UseItem>>()!.entries) {
  if (!canUse(a.peerId, a.value)) {
    session.resolveAction(a, accepted: false, reason: 'out of seeds');
    continue;
  }
  applyUse(a.peerId, a.value); // accepted by default
}
```

- **Exactly once, in order, on its tick.** Actions ride in every input packet until the host acknowledges them, so a lost packet costs a tick, not a resend timeout. The host applies each sequence number once and holds an action until it reaches the tick it was sent at, so it lands on the same tick as the inputs sent with it. A sequence gap (impossible for an honest client) or a target the sender doesn't own is rejected and reported with `NetRejected`.
- **Resolution.** An action not resolved by the end of its tick counts as accepted. The sender gets one `NetActionResolved<T>` event per action, with `accepted`, `reason` and `resolvedTick`.
- **Showing it straight away.** `session.pendingActions<T>()` lists the sender's actions whose effect the host's state doesn't show yet. Draw the authoritative state, then each pending action's effect on top. A rejected action leaves the list at once; an accepted one stays until the host's state includes it, so the effect never flickers off and back on. For replicated resources this is exact. Entity state is as of the newest snapshot (`session.lastSnapshotTick`): when re-applying an action that isn't idempotent, skip those whose `tick` is at or before it.
- The host's own actions take the same path (as peer 0), so host and clients share one code path. Keep payloads small (at most `NetworkSession.maxActionBytes`, 256 bytes; `sendAction` throws above it): send what the player did (a slot, a tile), never the state it produces.

### 9. Test it in one process

`LoopbackNetwork` with a `ManualNetClock` runs a host and several clients deterministically in one test. Give every app the same clock and a transport factory on the same network, tick them with a fixed frame delta, and advance the network clock one step per frame:

```dart
final clock = ManualNetClock();
final net = LoopbackNetwork(
  clock: clock,
  latency: const Duration(milliseconds: 50),
  jitter: const Duration(milliseconds: 50),
  packetLoss: 0.05,
  random: math.Random(7), // same seed, same run
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

final host = makeApp();
final client = makeApp();
await host.world.getResource<NetworkSession>()!.host(port: 7777);
final joining = client.world.getResource<NetworkSession>()!.join('127.0.0.1', 7777);
var joined = false;
joining.then((ok) => joined = ok);
for (var i = 0; i < 60 && !joined; i++) {
  await frame([host, client]); // the handshake travels the simulated network too
}
```

Keep ticking frames while `join` is pending, because the connect handshake travels over the simulated network too. Give each app its own `NetworkConfig`, since the session writes `mode` into it. To check the host's authority rules, see [Testing authority](/docs/networking/security-identity#testing-authority). The network itself is covered in [Low-level API](/docs/networking/low-level#loopbacknetwork).

## Where next

- [How replication works](/docs/networking/replication): ticks, snapshots, interest, prediction, interpolation, disconnects.
- [Configuration](/docs/networking/configuration): every `NetworkConfig` field, the `NetworkSession` API, events and stats.
- [Security and identity](/docs/networking/security-identity): passwords, player identities, encryption, authority.
- [Steam](/docs/networking/steam): host and join through Steam with no port forwarding.
- [Low-level API](/docs/networking/low-level): `NetworkHost`, `NetworkClient`, packets, transports.
- API reference: [fledge_net](https://pub.dev/documentation/fledge_net/latest/), [fledge_net_steam](https://pub.dev/documentation/fledge_net_steam/latest/).
