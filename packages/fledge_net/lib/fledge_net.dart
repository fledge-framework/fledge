/// Networking for Fledge: host-authoritative multiplayer with an ECS
/// replication layer.
///
/// - **Session**: `NetworkSession` (a resource inserted by
///   [NetworkPlugin]) hosts or joins; connection changes arrive as ECS
///   events (`NetPeerConnected`, `NetConnected`, ...).
/// - **Replication**: describe components, the input type, prediction and
///   RPCs on a [ReplicationRegistry]; mark host entities [Replicated].
///   Spawns, despawns, hierarchy and ownership travel reliably and in
///   order; state travels in chunked snapshots filtered by interest.
/// - **Inputs**: clients submit `NetLocalInputs<I>`; the host validates
///   ownership and exposes per-tick `NetInputs<I>`.
/// - **Prediction / interpolation**: the owning client predicts with
///   your pure `step` and reconciles; other entities are interpolated by
///   server tick.
/// - **Low level**: `NetworkHost` / `NetworkClient`, `UdpTransport`,
///   `EncryptedTransport` (AES-256-GCM), `LoopbackNetwork` for tests.
///
/// ## Hosting and joining
///
/// ```dart
/// final config = NetworkConfig(tickRate: 60, syncRate: 20);
/// final app = App()
///   ..insertResource(config.fixedTimestep())
///   ..addPlugin(NetworkPlugin(config: config, replication: replication));
///
/// final session = app.world.getResource<NetworkSession>()!;
/// await session.host(port: 7777);
/// // or: await session.join('192.168.1.20', 7777);
///
/// // Host: replicate an entity controlled by peer 1.
/// app.world.spawn()
///   ..insert(Replicated(owner: 1))
///   ..insert(Position(0, 0));
/// ```
///
/// Simulation (input application, prediction, game logic that affects
/// replicated state) belongs in the fixed-timestep chain: the network tick
/// advances once per `FixedTimestep` step, and `NetworkConfig.tickRate`
/// must match it.
///
/// ## Testing multiplayer in one process
///
/// Use [LoopbackNetwork] (optionally with a [ManualNetClock]) instead of
/// [UdpTransport] to run a host and any number of clients in-process, with
/// simulated latency, jitter, loss and duplication (seedable via an
/// injected `Random`). Pass `clock:` and `transportFactory:` to
/// [NetworkPlugin].
library;

// Transport
export 'src/transport/transport.dart';
export 'src/transport/udp_transport.dart';
export 'src/transport/encrypted_transport.dart';
export 'src/transport/loopback_transport.dart';

// Protocol
export 'src/protocol/net_clock.dart';
export 'src/protocol/packet.dart';

// Connection
export 'src/connection/client.dart';
export 'src/connection/host.dart';
export 'src/connection/peer.dart';
export 'src/connection/protocol_mismatch.dart';

// Sync
export 'src/sync/input_sync.dart';
export 'src/sync/interest_manager.dart';
export 'src/sync/network_identity.dart';
export 'src/sync/state_sync.dart';

// Replication
export 'src/replication/codec.dart';
export 'src/replication/components.dart';
export 'src/replication/events.dart';
export 'src/replication/inputs.dart';
export 'src/replication/registry.dart' show ReplicationRegistry, PositionGetter;
export 'src/replication/reliable_channel.dart';
export 'src/replication/session.dart';
export 'src/replication/systems.dart';
export 'src/replication/tick_sync.dart';

// Plugin
export 'src/plugin.dart';
