import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'protocol/net_clock.dart';
import 'replication/events.dart';
import 'replication/registry.dart';
import 'replication/session.dart';
import 'replication/systems.dart';
import 'sync/network_identity.dart';
import 'transport/transport.dart';

/// Network mode.
///
/// `NetworkSession.host` / `join` set it; `close` resets it to [offline].
enum NetworkMode {
  /// Single player (no networking).
  offline,

  /// This instance is the host.
  host,

  /// This instance is a client.
  client,
}

/// Network configuration resource.
///
/// Every field is read by the replication layer (`NetworkSession` and the
/// `NetworkPlugin` systems). Host and clients must agree on [tickRate]
/// and on the `ReplicationRegistry` (checked during the handshake).
class NetworkConfig {
  /// Current network mode (maintained by `NetworkSession`).
  NetworkMode mode;

  /// Simulation rate in Hz. Must match the `FixedTimestep` resource
  /// (`NetworkSession.host` / `join` throw otherwise; use
  /// [fixedTimestep] to build a matching one). Host and client must use
  /// the same rate.
  int tickRate;

  /// Snapshot rate in Hz: the host sends state every [syncInterval]
  /// ticks.
  int syncRate;

  /// How far behind the newest snapshot (in ms, converted to ticks)
  /// clients render interpolated entities. Larger values hide more
  /// jitter/loss at the cost of latency; keep it above
  /// `2 * 1000 / syncRate`.
  double interpolationDelay;

  /// Optional server password. The host rejects clients whose
  /// credentials are not its UTF-8 bytes (compared in constant time);
  /// clients send it as their default credentials. Sent in the clear
  /// unless [enableEncryption] is set.
  String? serverPassword;

  /// Custom authenticator callback (host).
  ///
  /// Called when a client connects. Return `true` to accept, `false` to
  /// reject. The [clientId] is the identifier sent by the client, and
  /// [credentials] contains any additional authentication data. If
  /// [serverPassword] is also set, both must accept.
  Future<bool> Function(String clientId, Uint8List credentials)? authenticator;

  /// Encrypt all traffic with AES-256-GCM (`EncryptedTransport`) using
  /// [encryptionKey]. Starting a session with this set and no key throws;
  /// there is no unencrypted fallback.
  bool enableEncryption;

  /// Pre-shared 32-byte key for [enableEncryption]. Distributing it is
  /// up to the app. It is never logged.
  Uint8List? encryptionKey;

  /// Interest radius for spatial filtering.
  ///
  /// If null, all replicated entities are sent to all clients (default).
  /// If set (and `ReplicationRegistry.positionOf` is provided), a client
  /// only receives entities within this radius of the first replicated
  /// entity it owns, plus always-relevant / unpositioned / owned entities
  /// and their ancestors. Entities entering the radius are spawned on
  /// the client, entities leaving it are despawned.
  double? interestRadius;

  /// Maximum number of connected clients (host).
  int maxPeers;

  /// Silence after which a connection is considered lost.
  Duration connectionTimeout;

  /// What the host does with the owned entities of a departed peer.
  OwnedEntityPolicy disconnectPolicy;

  /// Ticks of safety margin in the client input lead (on top of RTT).
  int inputLeadBufferTicks;

  /// How many ticks a missing input is replaced by the previous one
  /// (host for late/lost client inputs; client/host for ticks without a
  /// local submission). After that the entity gets no input.
  int maxInputRepeatTicks;

  /// Maximum number of unacknowledged inputs re-sent in every client
  /// input packet (redundancy against loss).
  int inputRedundancy;

  NetworkConfig({
    this.mode = NetworkMode.offline,
    this.tickRate = 60,
    this.syncRate = 20,
    this.interpolationDelay = 100,
    this.serverPassword,
    this.authenticator,
    this.enableEncryption = false,
    this.encryptionKey,
    this.interestRadius,
    this.maxPeers = 8,
    this.connectionTimeout = const Duration(seconds: 10),
    this.disconnectPolicy = OwnedEntityPolicy.despawn,
    this.inputLeadBufferTicks = 2,
    this.maxInputRepeatTicks = 8,
    this.inputRedundancy = 8,
  });

  /// Ticks between snapshots (`tickRate / syncRate`, at least 1).
  int get syncInterval {
    final interval = (tickRate / syncRate).round();
    return interval < 1 ? 1 : interval;
  }

  /// A `FixedTimestep` whose step matches [tickRate].
  FixedTimestep fixedTimestep({int maxCatchupSteps = 5}) => FixedTimestep(
    stepDuration: Duration(microseconds: (1e6 / tickRate).round()),
    maxCatchupSteps: maxCatchupSteps,
  );
}

/// Network tick resource.
///
/// - **Host**: [serverTick] is the authoritative tick, advanced once per
///   fixed step (in `Schedules.fixedFirst`); [localTick] equals it.
/// - **Client**: [localTick] is the tick this client simulates and
///   produces input for. It *leads* the host by about RTT/2 plus a small
///   buffer so inputs arrive just in time; it is set by the connect-time
///   tick sync and kept on target by time dilation. [serverTick] is the
///   estimate of the current host tick ([localTick] minus the lead).
class NetworkTick {
  /// Host: current authoritative tick. Client: estimated host tick.
  int serverTick = 0;

  /// Tick being simulated locally (client: leads [serverTick]).
  int localTick = 0;

  /// Tick delta time in seconds.
  double deltaTime = 0;

  /// Whether the ticks are meaningful (hosting, or client tick sync done).
  bool synced = false;

  /// How many ticks the local tick leads the (estimated) server tick.
  int get lead => localTick - serverTick;

  /// Advance one tick at [tickRate] Hz. Equivalent to
  /// `advanceStep(1 / tickRate)`.
  void advance(int tickRate) => advanceStep(1.0 / tickRate);

  /// Advance both ticks by one step of [stepSeconds], preserving the
  /// client lead.
  void advanceStep(double stepSeconds) {
    serverTick++;
    localTick++;
    deltaTime = stepSeconds;
  }
}

/// Plugin for network functionality.
///
/// Inserts [NetworkConfig], [NetworkTick], `NetworkEntityRegistry`, a
/// `NetworkSession` (and `NetInputs<I>` / `NetLocalInputs<I>` if an input
/// type is registered), registers the network ECS events, and adds the
/// replication systems. The systems are **always registered but no-ops
/// while no session is active** (offline), because a session is
/// typically started at runtime from a menu.
///
/// ```dart
/// final app = App()
///   ..insertResource(config.fixedTimestep())
///   ..addPlugin(NetworkPlugin(config: config, replication: replication));
/// await app.world.getResource<NetworkSession>()!.host(port: 7777);
/// ```
///
/// ## Systems
///
/// | System | Schedule | Ordering |
/// |---|---|---|
/// | `NetPumpSystem` | `first` | `FirstSets.platform` |
/// | `NetReceiveSystem` | `first` | after pump and every `FirstSets` phase |
/// | `NetInterpolationSystem` | `first` | after receive |
/// | `NetTickSystem` | `fixedFirst` | |
/// | `NetInputSystem` | `fixedPreUpdate` | after `NetSets.localInput` |
/// | `NetPredictSystem` | `fixedPreUpdate` | after input |
/// | `NetSendSystem` | `fixedLast` | |
///
/// Game systems that submit local input join `NetSets.localInput`;
/// systems that read `NetInputs<I>` go after `NetInputSystem.systemName`
/// (simulation belongs in the fixed chain; `Schedules.update` desyncs).
class NetworkPlugin implements Plugin {
  /// Initial network configuration.
  final NetworkConfig config;

  /// What is replicated. Frozen when the plugin is built.
  final ReplicationRegistry replication;

  /// Clock for the session (inject a `ManualNetClock` in tests).
  final NetClock? clock;

  /// Default transport factory for the session (e.g. a
  /// `LoopbackNetwork.createTransport` in tests).
  final Transport Function()? transportFactory;

  NetworkSession? _session;

  NetworkPlugin({
    NetworkConfig? config,
    ReplicationRegistry? replication,
    this.clock,
    this.transportFactory,
  }) : config = config ?? NetworkConfig(),
       replication = replication ?? ReplicationRegistry();

  @override
  void build(App app) {
    replication.freeze();
    final session = NetworkSession(
      config: config,
      registry: replication,
      clock: clock,
      transportFactory: transportFactory,
    )..attach(app.world);
    _session = session;

    app
      ..insertResource(config)
      ..insertResource(NetworkTick())
      ..insertResource(NetworkEntityRegistry())
      ..insertResource(session)
      ..addEvent<NetPeerConnected>()
      ..addEvent<NetPeerDisconnected>()
      ..addEvent<NetConnected>()
      ..addEvent<NetDisconnected>()
      ..addEvent<NetProtocolMismatch>()
      ..addEvent<NetRejected>()
      ..addEvent<NetEntitySpawned>()
      ..addEvent<NetEntityDespawned>()
      ..addEvent<NetPredictionCorrected>();
    replication.inputReplicator?.install(app);
    for (final rpc in replication.rpcs) {
      rpc.registerEvent(app);
    }

    app.configureSet(
      NetSets.localInput,
      (s) => s.before(NetInputSystem.systemName),
    );
    final systems = NetworkSystems(replication);
    app
      ..addSystem(systems.pump, schedule: Schedules.first)
      ..addSystem(systems.receive, schedule: Schedules.first)
      ..addSystem(systems.interpolation, schedule: Schedules.first)
      ..addSystem(systems.tick, schedule: Schedules.fixedFirst)
      ..addSystem(systems.input, schedule: Schedules.fixedPreUpdate)
      ..addSystem(systems.predict, schedule: Schedules.fixedPreUpdate)
      ..addSystem(systems.send, schedule: Schedules.fixedLast);
  }

  @override
  void cleanup() {
    final session = _session;
    if (session != null && session.isActive) {
      session.close('App shutting down').ignore();
    }
  }
}
