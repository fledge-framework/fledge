# fledge_net

## Purpose
Networking layer for multiplayer: transport, protocol, host/client architecture, and an ECS replication layer (session lifecycle, entity replication with hierarchy and interest management, owned inputs with authority checks, client prediction/reconciliation, tick-keyed interpolation, RPCs), plus authentication, encryption and congestion control.

## Status: Functional

## Stats
- Source: 29 files, ~8,500 LOC
- Tests: 36 files, ~7,000 LOC (390 tests)
- TODOs in code: 0
- Protocol version: 5 (v4: actions and fragmented reliable messages; v5: reliable `state` messages for entity deltas too large for a snapshot)

## What Works
- Transport abstraction (UDP-like interface); `UdpTransport`, `EncryptedTransport` (AES-256-GCM via `pointycastle`), public `LoopbackNetwork` / `LoopbackTransport` test network (latency, jitter, loss, duplication, seeded `Random`, manual clock mode)
- Protocol layer with packet framing and sequencing; varint helpers (`writeVarUint`, `writeVarBytes`)
- Host/client architecture (authoritative server model); connect retries; duplicate-connect guard; hostname resolution; `NetworkHost.getPeer`; `NetworkClient.lastStateReason`
- Redundant disconnect notices (`disconnectRedundancy` = 3 copies, `disconnectRedundancyInterval` = 5 ms, on client `disconnect()` and host `disconnectPeer()`/`stop()`); duplicates ignored on both sides
- Host peer timeouts and Peer-level retransmits on the injectable `NetClock` (`Peer(clock:)`, `lastReceiveMs`/`lastSendMs`; `lastReceiveTime`/`lastSendTime` kept as informational `DateTime`s whose setters shift the ms values)
- Test-only `package:fledge_net/testing.dart` (not exported from the barrel): `encodeRawInputPacket`, `RawInputStream`, `encodeWithCodec`, `NetworkSessionTesting` extension (`sendRawInput`, `sendRawInputPacket`, `sendRawRpc`) for forged-traffic authority tests
- RTT from ping/pong echo of the sender's own monotonic 32-bit clock (`NetClock`), wrap-safe
- 1200-byte datagram cap (`Packet.maxPayloadBytes` = 1152) enforced on host/client send APIs
- Structured `ProtocolMismatchEvent` on host and client
- **Replication layer** (`lib/src/replication/`):
  - `NetworkSession` resource: `host()` / `join()` / `close()`, wires `NetworkConfig` (password + authenticator, encryption with pre-shared key, interest radius, tick/sync rate, interpolation delay, max peers, timeouts, disconnect policy, input lead/repeat/redundancy)
  - `ReplicationRegistry`: component codecs (`NetCodec<T>`), one input type, `predict<S, I>` steps, RPC types, `positionOf`; schema hash checked in the welcome
  - `Replicated` marker on host entities -> netId + `NetworkIdentity`; reliable ordered spawn/despawn/parent/owner/RPC via `ReliableChannel` (cumulative acks); full-state chunked snapshots every `syncInterval` ticks
  - Hierarchy via parent netId, orphan buffering; interest management (radius around owner's global position, always-relevant/unpositioned/owned, ancestor closure, spawn on enter / despawn on exit)
  - Tick sync handshake (`PacketType.tickSync`) + time dilation (`ClientTickSync`); client local tick leads host by RTT/2 + buffer; adaptive buffer on late inputs
  - Inputs: `NetLocalInputs<I>` -> redundant input packets -> host `TickInputQueue` per peer/entity -> `NetInputs<I>`; ownership validated (rejections counted + `NetRejected` event)
  - Prediction/reconciliation driver (pure `step`, `error`/`tolerance`, replay, optional `correctionBlend`); tick-keyed interpolation for non-predicted entities
  - Interpolation render clock (`InterpolationClock` in `tick_sync.dart`): advances on `ClientTickSync.timeline(accumulatorSteps)` = sim clock minus the client's own corrections (dilation, handshake/reset jumps), so dilation, lead changes (RTT / late-input buffer) and 0/2-step frames never step the render tick; tracks the low-passed snapshot arrival offset with <= 10 % slew, snaps only beyond max(10 ticks, delay); offset re-seeded on tick resets. `ClientTickSync.renderTick` is kept for compatibility but unused (not smooth)
  - `NetworkConfig.interpolationDelay` defaults to derived `defaultInterpolationDelay` = `2 * syncInterval * 1000 / tickRate + 50` ms (150 ms at 60/20 Hz, 170 ms at 50/20); explicit values (setter accepts `null` to restore). `maxExtrapolation` (100 ms) bounds extrapolation (`interpolate` called with `t > 1`) on starvation, then a one-snapshot-interval blend back onto interpolation. Reordered (stale) snapshots still fill interpolation gaps
  - Interpolation tests: `test/replication/interpolation_test.dart` sweeps seeds 1..20 (default: all smooth; harsh 80+-40 ms / 10 % loss: >= 19/20, measured 99/100 on seeds 1..100, residual = 4 consecutive lost snapshots), `test/replication/render_clock_test.dart` (timeline / clock invariants, variable frame time + RTT/lead changes end to end)
  - ECS events for connect/disconnect/spawn/despawn/rejection/correction/RPC; disconnect policy (`OwnedEntityPolicy.despawn` / `releaseToHost`)
- Legacy/low-level helpers kept: `InterestManager`, `StateBuffer`/`NetworkInterpolation`, `Transform2DNetworkState`, `ClientPrediction` (reconcile now compares server state), `ServerInputQueue`, `InputFrame`

## Gaps
- **[P1]** No key-exchange handshake: encryption requires a pre-shared key distributed out-of-band. A Diffie-Hellman (or similar) negotiation should land before shipping production multiplayer.
- **[P2]** Snapshots carry full state of relevant entities (no delta vs acked baseline). Fine for co-op scale; delta compression is the next bandwidth optimisation.
- **[P2]** Congestion controller not yet wired into send path (canSend check not enforced).
- **[P3]** Raw `NetworkHost`/`NetworkClient` payloads above `Packet.maxPayloadBytes` throw (no fragmentation below the replication layer). Replicated entities may hold up to `NetworkSession.maxEntityStateBytes` (64 KiB): deltas over `maxSnapshotEntityBytes` (1112) go on the reliable control channel as `state` messages (protocol v5), with later deltas of that entity following on the channel until it's acknowledged.
- **[P3]** Prediction replays only the registered `step`, not other systems (physics) that touch the predicted component.
- **[P3]** `correctionBlend` < 1 smooths by blending simulation state; residual error is removed over further round trips (no separate visual-only offset).
- **[P3]** IPv4 only. `connect()`'s overall timeout and connect retries use real timers (everything else, incl. host peer timeouts and retransmits, uses `NetClock`).
- **[P3]** Deprecated, unused: `NetworkSyncConfig`, `PendingSpawn`, `PendingDespawn` (remove next breaking release).

## Action Items
1. Add key negotiation (e.g. ECDH during connect handshake) so `sharedKey` isn't a manual out-of-band burden (needs design review)
2. Delta snapshots against acked baselines (per-peer, per-component)
3. Wire `CongestionController.canSend()` into host/client send paths with packet queueing

## Architecture Notes
- **Entry point**: `lib/fledge_net.dart` (barrel export; `registry.dart` exports only `ReplicationRegistry` / `PositionGetter`, `wire.dart` is internal). `lib/testing.dart` is a separate test-only entrypoint wrapping `wire.dart` encoders plus the `@internal` `NetworkSession.queueRpcForNetId` hook.
- **Name clash**: `fledge_ecs` exports a top-level `component` annotation; inside extensions on `ReplicationRegistry` use `this.component<T>(...)` (documented on the method and in net.md).
- **NetworkPlugin** (`lib/src/plugin.dart`): `NetworkPlugin({config, replication, clock, transportFactory})`. Inserts `NetworkConfig`, `NetworkTick`, `NetworkEntityRegistry`, `NetworkSession`, `NetInputs<I>`/`NetLocalInputs<I>`; registers events; freezes the registry; adds 7 systems that are **always registered, no-ops while no session is active** (run condition `NetworkSession.hasWork`):
  - `Schedules.first`: `NetPumpSystem` (`FirstSets.platform`) -> `NetReceiveSystem` (after pump + all `FirstSets` phases)
  - `Schedules.update`: `NetInterpolationSystem` (after the fixed pass, so remote entities share the frame's alpha)
  - `Schedules.fixedFirst`: `NetTickSystem`
  - `Schedules.fixedPreUpdate`: [`NetSets.localInput` set, app] -> `NetInputSystem` -> `NetPredictSystem`
  - `Schedules.fixedLast`: `NetSendSystem`
  - Each has `static const String systemName`. Ordering is ambiguity-free alone and with physics/render/propagate (pure-Dart stand-ins in `test/ordering_test.dart`, real plugins in `integration/all_plugins`).
- **Session** (`lib/src/replication/session.dart` + parts `host_side.dart`, `client_side.dart`): stream callbacks only append to inbox lists; systems drain them. Host side: per-peer `_HostPeer` (channel, relevant set, input queues), per-entity `_HostEntity`; send pass = register new `Replicated` -> detect removals -> refresh facts -> per-peer interest diff (enters by depth, then parent/owner changes, then exits deepest-first) -> snapshots on `tick % syncInterval == 0` -> RPCs -> channel flush. Client side: tick-sync handshake (3 replies or 1 s, min RTT), welcome check (tick rate + schema hash), apply spawn/despawn/parent/owner/rpc, snapshot apply (stale guard per entity, predicted comps -> pending server state, interpolated -> buffers; stale snapshots only fill interpolation gaps), reconcile/predict, input send.
- **NetworkTick**: host `serverTick` authoritative (`localTick == serverTick`); client `localTick` leads, `serverTick` is an estimate. `advance(tickRate)` / `advanceStep(seconds)` advance both by one.
- **Wire** (`lib/src/replication/wire.dart`): formats for snapshot chunks (`stateUpdate`), input packets (`input`), tick sync (`tickSync` 0x15), reliable messages (`replication` 0x14: welcome/spawn/despawn/parent/owner/rpc). `replication` and `tickSync` are *unreliable* at the Peer level; `ReliableChannel` handles reliability.
- **Transport** (`lib/src/transport/`): delivery contract: each datagram exactly once, to `onReceive` listeners if any, otherwise into a bounded buffer drained by `receive()`. `EncryptedTransport`: 12-byte random nonce, 16-byte tag, 6-byte plaintext header bound as AAD; auth failures dropped silently.
- **Protocol** (`lib/src/protocol/packet.dart`): strings UTF-8 with uint16 prefix; header timestamp is the sender's `NetClock` uint32 value, never compared across machines.
- **Connection** (`lib/src/connection/`): `NetworkHost`, `NetworkClient`, `Peer` (Peer-level reliable queue with 32-bit ack window; not used by replication).
- **Testing**: pure Dart, `dart test`. Replication tests live in `test/replication/` and use `test/support/replication_harness.dart` (`NetTestbed`: one host + N client Apps, shared `ManualNetClock`, manual `LoopbackNetwork`, `WallTime.delta` = one step so each frame runs one fixed step; connect handshake runs loss-free because connect retries use real timers). Stand-in components `Pos`/`GlobalPos` replace Transform2D/GlobalTransform2D. Use `LoopbackNetwork`, not hand-rolled mocks.
