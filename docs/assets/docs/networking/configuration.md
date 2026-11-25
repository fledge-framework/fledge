# Network Configuration

The reference for the replication layer's settings and session API: every `NetworkConfig` field, the `NetworkPlugin` options, the `NetworkSession` members, the network events and the `NetworkStats` counters. For exhaustive signatures see the [fledge_net API reference](https://pub.dev/documentation/fledge_net/latest/).

## NetworkConfig

`NetworkConfig` is a resource (inserted by `NetworkPlugin`) and every field is read by the replication layer. Host and clients must agree on `tickRate` and on the `ReplicationRegistry`; the handshake checks both.

```dart
final config = NetworkConfig(
  tickRate: 60,
  syncRate: 20,
  interestRadius: 2000,
  maxPeers: 4,
  serverPassword: 'hunter2',
  disconnectPolicy: OwnedEntityPolicy.holdForReturn,
);
final app = App()
  ..insertResource(config.fixedTimestep())
  ..addPlugin(NetworkPlugin(config: config));
```

| Field | Default | Description |
|---|---|---|
| `mode` | `NetworkMode.offline` | `offline`, `host` or `client`. Maintained by `NetworkSession`: `host`/`join` set it and `close` resets it. You don't set it yourself. |
| `tickRate` | 60 | Simulation rate in Hz. Must match `FixedTimestep` (use `config.fixedTimestep()`) and the host's rate. |
| `syncRate` | 20 | Snapshot rate in Hz. The host sends state every `syncInterval` (`tickRate / syncRate`, at least 1) ticks. |
| `interpolationDelay` | derived | How far behind the newest snapshot (ms) clients draw interpolated entities. Unset or `null`: `defaultInterpolationDelay`, two snapshot intervals plus `interpolationJitterMargin` (50 ms), which is 150 ms at 60 Hz / 20 Hz. |
| `maxExtrapolation` | 100 | How long (ms) an interpolated entity is extrapolated past its newest snapshot when snapshots are late or lost. `0` holds instead. |
| `serverPassword` | `null` | The host requires these UTF-8 bytes as credentials (constant-time compare); clients send it by default. Sent in the clear unless encryption is on. |
| `authenticator` | `null` | Custom host check, `(clientId, credentials) async => bool`. If a password is also set, both must accept. |
| `identityProvider` | `null` | Says who this player is when joining (and who the host's own player is). Without one, a client joins anonymously. See [Player identity](/docs/networking/security-identity#player-identity). |
| `identityVerifier` | `null` | Host: checks joining clients' identities. Without one, any well-formed identity is accepted as claimed. |
| `enableEncryption` | `false` | Wrap the transport in `EncryptedTransport` (AES-256-GCM). |
| `encryptionKey` | `null` | Pre-shared 32-byte key. Required when `enableEncryption` is set: starting without one throws, and there is no unencrypted fallback. Never logged. |
| `interestRadius` | `null` | Interest radius in world units. `null` sends every entity to every client. Needs an interest position on the registry. |
| `maxPeers` | 8 | Maximum connected clients. Further connects are rejected. |
| `sendBudgetBytesPerSecond` | 65536 | Bytes a second the host may send each client: control first, then snapshots, then resource chunks. See [Send budget](/docs/networking/replication#send-budget). |
| `relevance` | `null` | Host: `(world, entity, peerId) => bool`, return false to hide an entity from a client. |
| `connectionTimeout` | 10 s | Silence after which a connection is dropped. Also bounds the connect handshake. |
| `disconnectPolicy` | `OwnedEntityPolicy.despawn` | What the host does with a departed client's entities (`despawn`, `releaseToHost`, `holdForReturn`). See [Disconnects](/docs/networking/replication#disconnects). |
| `inputLeadBufferTicks` | 2 | Ticks of safety margin in the client's input lead, on top of RTT. |
| `maxInputRepeatTicks` | 8 | How many ticks a missing input is replaced by the previous one. |
| `inputRedundancy` | 8 | Unacknowledged inputs repeated in every client input packet. |

Helpers: `config.fixedTimestep({maxCatchupSteps = 5})` returns a `FixedTimestep` whose step matches `tickRate`; `syncInterval` and `defaultInterpolationDelay` are the derived values above.

## NetworkPlugin

`NetworkPlugin({config, replication, clock, transportFactory})`:

| Parameter | Description |
|---|---|
| `config` | The `NetworkConfig` (default: `NetworkConfig()`). |
| `replication` | The `ReplicationRegistry` (default: empty). Frozen when the plugin is built. |
| `clock` | The session's `NetClock`. Pass a `ManualNetClock` in tests. |
| `transportFactory` | Creates the transport when `host`/`join` aren't given one. Default: `UdpTransport()`. Pass `LoopbackNetwork.createTransport` in tests. |

The plugin inserts `NetworkConfig`, `NetworkTick`, `NetworkEntityRegistry` and `NetworkSession`, plus `NetInputs<I>` and `NetLocalInputs<I>` for a registered input type and `NetActions<T>` for each action type. It registers every event below and adds the [replication systems](/docs/networking/replication#systems). When the app shuts down, an active session is closed.

## NetworkSession

The resource that runs a session. Get it with `world.getResource<NetworkSession>()!`.

### Lifecycle

| Member | Description |
|---|---|
| `host({port = 7777, transport})` | Start hosting. Throws if a session is running, if `FixedTimestep` doesn't match `tickRate`, or if encryption is enabled without a key. |
| `join(address, port, {transport, credentials})` | Connect to a host (IPv4 address, host name, or a transport-specific address such as `steam:<id>`). Resolves to `true` once accepted; `false` with `lastError` on failure. `credentials` default to the UTF-8 bytes of `serverPassword`. |
| `close([reason])` | End the session. Hosts disconnect every peer; clients notify the host. On the next frame clients despawn all replicated entities and `NetDisconnected` is sent. |
| `lastError` | Why the last `join` failed or the last session ended. |
| `transportFactory` | The default transport factory (settable). |

### State

| Member | Description |
|---|---|
| `role` | `NetworkRole.offline`, `host` or `client`. |
| `isHost`, `isClient`, `isActive` | Shorthands for `role`. |
| `isReady` | Host: always `true` while hosting. Client: `true` once the welcome arrived and the tick is synchronised (inputs and prediction start then). |
| `localPeerId` | `int?`: `0` while hosting, the assigned peer id on a client, `null` offline. |
| `peerIds` | Host: connected peer ids, ascending. |
| `rttMs([peerId])` | Round-trip time in ms: to `peerId` on the host, to the host on a client. `0` until measured. |
| `lastSnapshotTick` | The newest host tick whose state this instance has (client: newest snapshot; host: current tick). |
| `stats` | `NetworkStats` counters (below). |
| `tickSync` | Client: the `ClientTickSync` (lead, RTT, error), for diagnostics. |
| `networkHost`, `networkClient` | The underlying [`NetworkHost` / `NetworkClient`](/docs/networking/low-level), for diagnostics. |
| `config`, `registry`, `clock` | What the session was built with. |

### Identity

| Member | Description |
|---|---|
| `localIdentity` | This player's identity from `identityProvider`, once a session started (`null` if none is configured). |
| `identityOf(peerId)` | Host: the identity a peer joined with, or `null` if anonymous or not connected. |
| `peerFor(identity)` | Host: the connected peer that joined as `identity`, or `null`. |

### Messages

| Member | Description |
|---|---|
| `sendRpc(value, {target, exceptPeer})` | Client: to the host. Host: to every client except `exceptPeer`. `target` optionally names a replicated entity. |
| `sendRpcTo(peerId, value, {target})` | Host only: to one client. |
| `sendAction(value, {target})` | Send a [player action](/docs/networking/overview#8-player-actions); returns a `NetActionTicket(seq, tick)`. Throws when not connected, or on a client when the payload exceeds `maxActionBytes`. |
| `resolveAction(action, {accepted, reason})` | Host only: accept or reject one of this tick's `NetActions<T>` entries. Returns `false` if it was already resolved. |
| `pendingActions<T>()` | Actions this instance sent whose effect the host's state doesn't show yet, oldest first. |

### Constants

| Constant | Value | Description |
|---|---|---|
| `NetworkSession.maxEntityStateBytes` | 1112 | Largest replicated state of one entity. See [Limits](/docs/networking/replication#limits). |
| `NetworkSession.maxActionBytes` | 256 | Largest encoded action payload. |

## Events

All are registered by `NetworkPlugin`. Like other Fledge events, they're readable during the frame after they're sent.

| Event | Where | Fields | When |
|---|---|---|---|
| `NetPeerConnected` | host | `peerId`, `identity` (empty if anonymous), `returned` (net ids handed back) | A client finished connecting. It receives the relevant world state on the next fixed tick. |
| `NetPeerDisconnected` | host | `peerId`, `reason`, `identity`, `ownedNetIds`, `policy` | A client left (disconnect, timeout or kick); its entities were already handled per `policy`. |
| `NetConnected` | client | `localPeerId` | Handshake and tick sync are done. |
| `NetDisconnected` | both | `reason` | The session ended or failed after connecting. Clients have despawned every replicated entity. |
| `NetProtocolMismatch` | both | `details` (a `ProtocolMismatchEvent`: `source`, `localVersion`, `remoteVersion`, `remoteIsNewer`) | A peer runs another protocol version. |
| `NetRejected` | host | `peerId`, `kind` (`NetRejectionKind.input`, `rpc`, `message`, `action`), `netId`, `reason` | A client sent something it isn't allowed to; it was dropped. Never contains payload data. |
| `NetEntitySpawned` | client | `entity`, `netId` | A replicated entity appeared locally. |
| `NetEntityDespawned` | client | `entity` (now dead), `netId` | A replicated entity went away (host despawn, or it left this client's interest set). |
| `NetPredictionCorrected` | client | `entity`, `netId`, `tick`, `error` | The host disagreed with a prediction beyond `tolerance`. |
| `NetRpcReceived<T>` | both | `sender` (`0` = host), `value`, `targetNetId`, `target` (local entity or `null`) | An RPC arrived. |
| `NetActionResolved<T>` | sender | `seq`, `tick`, `value`, `accepted`, `reason`, `resolvedTick` | The host decided one of this instance's actions. Fired once per action. |
| `NetResourceUpdated` | client | `key`, `chunk` | A chunk of a replicated resource was updated from the host. |

## NetworkStats

`session.stats` counts events for debugging and tests. It never contains payload data.

| Field | Side | Counts |
|---|---|---|
| `rejectedInputs` | host | Inputs dropped because the sender doesn't own the entity |
| `rejectedRpcs` | host | RPCs dropped because the sender doesn't own the target |
| `rejectedActions` | host | Actions dropped or rejected by the host's own checks (sequence, target ownership, decoding) |
| `rejectedMessages` | host | Reliable messages a client isn't allowed to send (spawns and the like) |
| `corrections` | client | Prediction corrections applied |
| `snapshotChunksSent` | host | Snapshot chunks sent (all peers) |
| `snapshotChunksReceived` | client | Snapshot chunks received |
| `resourceChunksSent` | host | Resource chunks queued for clients |
| `resourceChunksReceived` | client | Resource chunks applied |
| `lateInputs` | host | Inputs that arrived after their tick was simulated with a repeated input |
| `tickResets` | client | Hard tick resets |
| `oversizedEntities` | host | Entities skipped because their state exceeded `maxEntityStateBytes` (each counted once) |
