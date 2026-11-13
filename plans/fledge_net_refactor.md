# fledge_net refactor plan

Status: **approved, in progress.** W1 done; W2 done; W3 done; W4.2 (player identity) done; W4.3 (`fledge_net_steam`) done, including lobbies, invites, "Join Game" and packaging. Breaking changes are acceptable (0.x); each lands with a protocol version bump where the wire format changes, tests, README/docs updates and a `fledge_net` changelog entry via Conventional Commits.

## Why

An audit of `fledge_net` 0.5.0 (architecture, transport/security, timing/prediction) against a real consumer, Tharsis Plateau (2-4 player host-authoritative co-op farming), found:

- **Sound, keep:** tick sync and `FixedTimestep.nudge` steering, rollback/replay prediction, the decoupled interpolation render clock, `ReliableChannel`, handshake retries, malformed-packet handling, AES-256-GCM usage, 1200-byte datagrams, Fledge conventions (`systemName`, `NetSets`, `checkScheduleOrdering` test), no render dependency.
- **Doesn't fit a large shared world:** entity-only replication (no resources), full state every snapshot, a ~1.1 KB per-entity cap with no fragmentation, join bursts that trip the 16,384-unacked kick.
- **Missing for gameplay:** no safe channel for discrete actions (inputs repeat on late ticks; RPCs carry no tick, sequence or reply), no fixed-step input latching in `fledge_input`, fragile recovery after hard clock resets.
- **Missing for internet play:** no NAT traversal, IP-only addressing, static pre-shared key without replay protection, address-only peer identity.
- **Dead weight:** the legacy `src/sync/` layer duplicates `src/replication/` but is still exported, tested and documented; `CongestionController` is declared and never used.

Verified in source during review: the per-entity `StateError` (`host_side.dart:580-586`), the monotonic `extraBufferTicks` (`tick_sync.dart:139-144`), the unused `CongestionController` (`peer.dart:97, 271`), and input repetition (`inputs.dart:161-170`).

## Workstreams

Sizes are relative (S/M/L). Order is given at the end.

### W1. Cleanup and correctness (S)

1. Delete the legacy `sync/` API: `state_sync.dart`, `input_sync.dart`, `interest_manager.dart`, `NetworkSyncConfig`, `PendingSpawn`, `PendingDespawn`, their exports (`fledge_net.dart:68-71`), tests (`input_sync_test`, `interest_test`, `state_sync_test`, `delta_compression_test`, `transform_2d_sync_test`) and doc sections (`docs/assets/docs/plugins/net.md`).
2. Move `NetworkIdentity` / `NetworkEntityRegistry` into `replication/`; drop the unused `spawnType`; make registry mutators `@internal`; fix `hasAuthority` being `true` on the host for client-owned entities (`host_side.dart:612`).
3. Oversized entity state must not wedge replication: validate at registration where possible, otherwise log once and skip that entity (`host_side.dart:583`). (Superseded in part by W2 fragmentation, but the wedge is a bug today.)
4. Catch the unawaited retransmit send in `NetworkHost.update` (`host.dart:319`) and the `ArgumentError` path in `_sendSafely` (`session.dart:504-508`).
5. Move the peer-level "reliable" packet types (`connectAccepted`, `rpc`, `entitySpawn`, `entityDespawn`) onto `ReliableChannel`, or give them receiver dedup and stop the silent give-up after 10 tries.
6. Remove `CongestionController` (replaced by W2's send budget).
7. Cap unbounded structures: send-side `_unacked`, `_pendingConnects`, the receive reorder window.
8. Hot-path tidying: `ReliableChannel.maxMessageBytes` as a static const; reuse `PacketBuilder`s; declare the components `positionOf` reads in `NetSendSystem.meta` (today it reads e.g. `GlobalTransform2D` undeclared, `systems.dart:207`).

### W2. State replication that scales (L, the core) — *done*

Implemented as planned: fragmentation in `ReliableChannel` (up to 1 MiB, part byte per entry); a bulk channel (channel byte on replication packets) for `registry.resource` chunks sent when their version changes; change-only snapshots against per-client acknowledged baselines (chunk sequence numbers acknowledged with a 32-bit bitfield in input packets; predicted components always sent to their owner; complete ticks give clients "held still" samples); a per-client budget (`sendBudgetBytesPerSecond`) spent control → snapshots → bulk, with spawns and resource chunks queued only within about two seconds of the budget; `Replicated.ownerOnly`, `NetworkConfig.relevance` and an interest grid. Acceptance tests: `resources_test` (4 KiB/s farm), `deltas_test` (2000 static entities under 1 KiB/s), `budget_visibility_test` (budget, 17000-entity join, owner-only, relevance, RPC not blocked by a download). Not done: per-component sync rates (W2.6, low value with change-only snapshots).

### W2. (original plan)

Goal: a 100x100-tile farm, a few hundred dynamic objects and 2-4 inventories cost bandwidth proportional to **what changes**, not to world size.

1. **Replicated resources.** New registry entry point:

   ```dart
   registry.resource<Farm>(
     'farm',
     ResourceCodec<Farm>.chunked(
       chunks: (farm) => farm.chunkCount,
       version: (farm, chunk) => farm.chunkVersion(chunk),
       encode: (farm, chunk, out) => ...,
       decode: (farm, chunk, reader) => ...,
     ),
   );
   // Small resources: ResourceCodec<Weather>.whole(encode:, decode:, version:)
   ```

   The resource owns cheap per-chunk version counters (bumped on mutation). The host tracks, per peer, the last **acked** version of each chunk and sends only changed chunks, reliably and in order, on its own channel. A joining peer receives every chunk once. Clients apply chunks into their local resource; the game never sees partial chunks.
2. **Entity deltas.** Per peer, per entity, keep the acked baseline (per-component version or hash). Snapshots carry only components that changed since the peer's acked baseline, plus an explicit "removed" set (today absence means removal, `client_side.dart:613`). Unchanged entities aren't sent. Wire format change → protocol v4.
3. **Fragmentation.** Reliable messages larger than one datagram are split and reassembled (message id, fragment index/count), up to a configurable cap (e.g. 1 MiB). Removes the ~1.1 KB per-entity cap for reliable data and enables whole-resource/initial-state transfer.
4. **Send budget and flow control.** A per-peer byte budget per tick, filled by priority: reliable control > resource chunks > entity deltas, with entity deltas prioritised by relevance and staleness. Replaces the 16,384-unacked kick with back-pressure; joins stream in over several ticks instead of bursting.
   - **Design target:** 16-32 KiB/s per peer in steady play, so a host with 3 peers uses about 0.4-0.8 Mbps of upload (fits a ~1 Mbps DSL uplink).
   - **Default hard budget:** 64 KiB/s per peer, configurable. Joins and catch-up stream at the budget.
   - Under the Steam transport the budget stays below Steam's configured send rate, so the two rate controls don't fight.
5. **Channels.** Separate reliable-ordered streams for (a) control/spawn/despawn, (b) resource chunks, (c) RPCs/actions, so a big join doesn't head-of-line-block actions. Add unreliable RPCs (for cosmetic effects).
6. **Visibility.** Per-peer visibility beyond radius: `owner-only` (private inventories), `always`, and a custom predicate; a spatial grid for radius interest instead of O(N) per peer per tick (`host_side.dart:635-706`). Per-component sync rate (e.g. transforms 20 Hz, rarely-changing components on change only).

Acceptance tests (new, using `LoopbackNetwork` latency/jitter/loss):
- 100x100 chunked farm resource, 10 tile changes/second: steady-state host upload per peer under 4 KiB/s; full join of the farm completes under the send budget without a kick.
- 2,000 static entities: steady-state cost near zero; join streams without exceeding the budget.
- Owner-only component never reaches non-owners.
- Resource state converges exactly (byte-equal encode) on all clients under 10% loss.

### W3. Gameplay protocol (M) — *done*

Implemented, with these decisions:

- **Actions** (`registry.action<T>`, `session.sendAction` / `resolveAction` / `pendingActions<T>()`, `NetActions<T>` resource, `NetActionResolved<T>` events). Delivered in a **resource rebuilt each fixed tick**, not as events: Fledge events are per frame and a frame runs 0..N fixed ticks. Actions ride **redundantly in every input packet** until the host acknowledges them (`actionAck` in the snapshot header); a first version on the reliable control channel was head-of-line blocked about 10 ticks per lost packet. The host holds each action until its tick, so it lands with the inputs sent alongside it; unresolved actions are accepted at the end of the tick. Resolutions travel on the bulk channel behind every resource chunk queued before them, which is what makes `pendingActions` (the W3.3 override helper) flicker-free for resources.
- **Tick resets** keep the predicted state and restart the history; ignoring server states from before the jump. Re-basing (relabelling) the input history was tried and rejected: relabelled inputs the host had already applied fall inside the redundancy window and get applied twice.
- **Extra buffer** decays one tick per `bufferDecaySeconds` (10 s) without late inputs.
- **Correction smoothing** is render-only: the simulation takes the corrected state; `correctionBlend < 1` maintains `NetSmoothed<S>` (a ghost of the old prediction carried forward with the same inputs, lerped toward the truth), so it works for any state type with only `step` and `interpolate`.
- **Step context**: `predict(stepWith: (state, input, PredictContext) => ...)` with read-only world, entity, tick, dt, replaying.
- **Interpolation** moved to `Schedules.update` in a new standard phase set `UpdateSets` (`receive` → `simulate`, in `fledge_ecs`; variable-mode physics joins `simulate`), so remote entities share the frame's alpha.
- **Harness**: `NetTestbed.runRealtime` (per-app frame rates and clock rates, paused apps); `realism_test` covers 144 Hz vs 60 Hz, ±1 % clocks for 30 s, a 250 ms latency spike and its recovery; `prediction_test` covers a stall.

Original plan:


1. **Fixed-step input latching (`fledge_input`).** `ActionState.justPressed` is per frame, so a fixed-step consumer misses presses (0 steps that frame) or doubles them (2 steps). Add a latch: presses accumulate until the first fixed step consumes them (e.g. `ActionState.fixedJustPressed(action)`, cleared in `fixedLast`), with tests for 0/1/2-step frames. Prerequisite for fixed-step gameplay with or without networking.
2. **Sequenced actions.** A channel for discrete, validated actions, distinct from level-state inputs:

   ```dart
   registry.action<UseTool>(codec);
   final handle = session.sendAction(UseTool(tile), target: avatar); // seq + tick stamped
   // host: NetActions<UseTool> events: (peer, seq, tick, value)
   session.resolveAction(peer, seq, accepted: true);   // or rejected with a reason code
   // client: ActionResolved<UseTool>(seq, accepted, reason) events
   ```

   Exactly-once delivery, ordered per peer, never repeated. Document that inputs are level state (held movement) and repeat on late ticks by design; edge-triggered things go through actions.
3. **Local overrides until confirmed.** A small helper so the client can show an action's effect immediately and keep it until the host's state at or after the action's tick arrives (or the action is rejected), so a tilled tile doesn't flicker back on the next older snapshot. Keyed by resource chunk or entity component.
4. **Recovery.**
   - A hard tick reset must re-base input history and replay unacked inputs, not clear them and snap to stale server state (`client_side.dart:732-736, 619-621`).
   - `extraBufferTicks` decays after a quiet period without late inputs.
   - Prediction correction becomes a render-only offset that decays over a few frames, instead of blending the simulation state (`client_side.dart:812-814`), so a misprediction doesn't cause repeated corrections.
5. **Step context.** `predict` steps get a read-only, deterministic context (e.g. a collision view supplied by the game) so movement with collision can be predicted without globals.
6. **Interpolation timing.** Sample remote components after the fixed pass (or in `postUpdate`) so they share the frame's time with the local player and camera; document or guard `PreviousTransform2D` on interpolated entities (it is snapshotted in `fixedFirst` while interpolation writes per frame).
7. **Harness realism.** `NetTestbed` with independent host/client clocks: drift (+/-0.5%), pauses (alt-tab 2 s on either side), 144 Hz client vs 60 Hz host, RTT spikes. Assert no snap-back, bounded latency growth, smooth remote motion.

### W4. Reachability and session security (M-L, before online playtests)

**Decided: internet play targets Steam through the Steamworks SDK.** Steam Networking Sockets provides relays (Steam Datagram Relay), NAT traversal, and connections encrypted and authenticated by Steam, so internet play needs no port forwarding and most session security comes from Steam. The UDP transport stays for LAN, development and tests.

1. **Pluggable transport.** Opaque `NetAddress` (IP for UDP, SteamID for Steam); `Transport.bind` takes a config object; DNS lookup moves into `UdpTransport` (out of `NetworkClient`, `client.dart:374-385`). Conditional imports so `dart:io` isn't pulled into web builds (`fledge_net.dart:53, 62`).
2. **Player identity.** *Done.* Identities are opaque strings with a scheme prefix (`dev:`, `steam:`, `hub:`), independent of transport and address, so direct IP, Steam and a gateway or hub all work. The client presents one through an `IdentityProvider` (`DevIdentityProvider`, `TokenIdentityProvider`; Steam's comes with W4.3) and the host checks it with an `IdentityVerifier` (`TrustingVerifier`, `TokenVerifier`, `SchemeVerifier` to mix schemes). It travels in the connect handshake (client identifier), with its proof framed beside the password in the credentials (protocol v4). The host exposes `identityOf` / `peerFor`, events carry the identity, a second connection with the same identity replaces the first, and `OwnedEntityPolicy.holdForReturn` hands a returning player their entities back.
3. **`fledge_net_steam` package.** *Done (transport and identity), against Steamworks SDK 1.65.* Hand-written FFI bindings for the flat API subset used (`SteamAPI_InitFlat`, manual callback dispatch, `ISteamNetworkingMessages`, `ISteamUser`, relay access); `Steam` loads and initialises the library; `SteamTransport` (also an `AddressResolver`, so `steam:` hosts skip DNS) sends fledge_net's datagrams unreliably and accepts sessions; `SteamIdentityProvider` / `SteamIdentityVerifier` use `steam:<SteamID64>`, verified against the connect's Steam-authenticated source (`IdentityVerifier.verify` now gets `source`; `NetworkHost.sourceAuthenticator`). Tests run on a fake Steam network; a bindings test checks every symbol in the real library when `STEAMWORKS_SDK` is set. Lobbies too: `SteamCoop` (create/join a lobby naming the host, overlay invites, rich presence `connect` for "Join Game", `+connect_lobby` launch arguments) over `SteamMatchmaking` on `Steam`, whose own timer pumps callbacks and async call results. Packaging: `Steam.bundledLibraryPaths` (exe dir; Linux `lib/`; macOS `Frameworks/`); the game's Windows/Linux CMake bundle the library from `STEAMWORKS_SDK`, `tool/bundle_steam.dart` does macOS. *Still to do:* manual testing between two Steam accounts. A new package (framework tier: plugin) implementing the transport over Steamworks via Dart FFI (evaluate existing Dart Steamworks bindings first; otherwise generate with `ffigen` from the SDK's flat API):
   - `ISteamNetworkingMessages` (or `ISteamNetworkingSockets` P2P) sending `fledge_net`'s datagrams as unreliable messages, so `fledge_net` keeps one reliability layer across transports;
   - SteamID addressing and authentication; join by SteamID;
   - lobby, invite and "join game" hooks (`ISteamMatchmaking`, friends overlay) so friends join from Steam; the game owns the UI;
   - shipping concerns: `steam_api64.dll`/`libsteam_api` placement per OS, `steam_appid.txt` for development (app 480 "Spacewar" until the game has its own app id), Steam must be running, CI builds without the SDK present.
   - Testing: the loopback transport covers protocol behaviour; Steam itself is verified manually with two Steam accounts.
4. **Session security for the UDP transport** (LAN/dev; needs a written design and review before implementation). Under Steam, connections are already encrypted and authenticated, so this is lower priority:
   - stateless connect challenge (cookie) before allocating a peer slot;
   - per-session keys derived with HKDF from the shared secret plus both sides' nonces, separate keys per direction;
   - an authenticated packet counter with a sliding replay window;
   - a connection id instead of address-only identity (also survives NAT rebinding);
   - encryption on by default, or a loud warning when a password would travel in cleartext;
   - a distinct "wrong key / version" rejection instead of a silent timeout; disconnect reason codes.

## Order

1. **W1** (cleanup) — first; shrinks the surface everything else touches.
2. **W3.1** (fixed-step input latch) and **W3.2 design** — early, because they set the game's conventions (fixed-step movement, sequenced commands) even in singleplayer.
3. **W2** (resources, deltas, fragmentation, budget, channels, visibility) with **W3.2-3.4** implemented alongside; then the remaining W3 items and the realistic harness.
4. Game networking spike (Tharsis: two clients walking, tilling, picking up drops) against the result.
5. **W4.1-4.2** (opaque addresses, player identity) can land with W2; **W4.3** (`fledge_net_steam`) before any internet playtest; **W4.4** (UDP session security) afterwards, as LAN/dev hardening.

## Out of scope

Host migration (sessions end with the host; saves are the host's), dedicated servers, public matchmaking (Steam lobbies and invites for friends are in W4.3), voice.

## Decided

- Internet play: **Steam via the Steamworks SDK** (W4.3).
- Send budget: 16-32 KiB/s per peer steady-state target, 64 KiB/s per peer default hard budget (W2.4).

## Open questions

- Should replicated resources also be the save format (one codec for net and disk), or stay separate? *(Proposed: share the chunk codecs, keep the save envelope separate so saves can migrate between versions.)*
