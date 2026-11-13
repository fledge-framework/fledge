import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';

import 'protocol/net_clock.dart';
import 'replication/identity.dart';
import 'replication/resources.dart';
import 'replication/events.dart';
import 'replication/registry.dart';
import 'replication/session.dart';
import 'replication/systems.dart';
import 'replication/network_identity.dart';
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

  double? _interpolationDelay;

  /// How far behind the newest snapshot (in ms, converted to ticks)
  /// clients render interpolated entities, measured from the *mean*
  /// snapshot arrival time.
  ///
  /// Unless set explicitly it is [defaultInterpolationDelay]: two snapshot
  /// intervals plus [interpolationJitterMargin] ms, which rides out one
  /// lost snapshot under up to ~100 ms of arrival jitter. Smaller values
  /// cut latency but starve the buffer on loss/jitter (the client then
  /// extrapolates for up to [maxExtrapolation] ms, or holds); keep an
  /// explicit value above `2 * syncInterval * 1000 / tickRate` plus half
  /// the expected jitter. Assign `null` to go back to the derived default.
  double get interpolationDelay =>
      _interpolationDelay ?? defaultInterpolationDelay;

  set interpolationDelay(double? ms) => _interpolationDelay = ms;

  /// Jitter allowance (ms) on top of two snapshot intervals in
  /// [defaultInterpolationDelay].
  static const double interpolationJitterMargin = 50;

  /// Derived [interpolationDelay]:
  /// `2 * syncInterval * 1000 / tickRate + interpolationJitterMargin`
  /// (170 ms at 50 Hz / 20 Hz, 150 ms at 60 Hz / 20 Hz).
  double get defaultInterpolationDelay =>
      2 * syncInterval * 1000 / tickRate + interpolationJitterMargin;

  /// Longest time (ms) a client keeps extrapolating an interpolated entity
  /// past its newest snapshot when snapshots are late or lost (several
  /// in a row), before holding it. When the next snapshot arrives the
  /// entity blends from the extrapolated path back onto the interpolated
  /// one over one snapshot interval. `0` disables extrapolation (hold).
  ///
  /// Extrapolation calls the component's `interpolate` function with
  /// `t > 1`; registrations whose type cannot extrapolate should clamp
  /// `t` (or set this to `0`).
  double maxExtrapolation;

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

  /// Says who this player is when joining (and, on a host, who the host's
  /// own player is: `NetworkSession.localIdentity`). Without one a client
  /// joins anonymously. See `ClientIdentity` for the id conventions
  /// (`dev:`, `steam:`, `hub:`).
  IdentityProvider? identityProvider;

  /// Host: checks joining clients' identities. Without one, any well-formed
  /// identity is accepted as claimed (fine for LAN and development; use a
  /// real verifier, such as Steam's or a hub's, on the internet).
  IdentityVerifier? identityVerifier;

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
  /// If set (and an interest position is registered with
  /// `ReplicationRegistry.positionFrom` / `position`), a client
  /// only receives entities within this radius of the first replicated
  /// entity it owns, plus always-relevant / unpositioned / owned entities
  /// and their ancestors. Entities entering the radius are spawned on
  /// the client, entities leaving it are despawned.
  double? interestRadius;

  /// Maximum number of connected clients (host).
  int maxPeers;

  /// Host: bytes a second each client may be sent. Control messages go
  /// first, then snapshots, then resource chunks; what doesn't fit waits
  /// for the next tick (unsent snapshot changes are sent later, being
  /// still unacknowledged). Big joins stream in at this rate. The default,
  /// 64 KiB/s, keeps a host with three clients under about 1.5 Mbps of
  /// upload; steady play needs far less.
  int sendBudgetBytesPerSecond;

  /// Host: decides, beyond `interestRadius`, `Replicated.alwaysRelevant`
  /// and `Replicated.ownerOnly`, whether [entity] is sent to client
  /// [peerId]. Return false to hide it. Called for every replicated entity
  /// and client once a fixed tick, so keep it cheap.
  bool Function(World world, Entity entity, int peerId)? relevance;

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
    double? interpolationDelay,
    this.maxExtrapolation = 100,
    this.serverPassword,
    this.authenticator,
    this.identityProvider,
    this.identityVerifier,
    this.enableEncryption = false,
    this.encryptionKey,
    this.interestRadius,
    this.maxPeers = 8,
    this.sendBudgetBytesPerSecond = 64 * 1024,
    this.relevance,
    this.connectionTimeout = const Duration(seconds: 10),
    this.disconnectPolicy = OwnedEntityPolicy.despawn,
    this.inputLeadBufferTicks = 2,
    this.maxInputRepeatTicks = 8,
    this.inputRedundancy = 8,
  }) : _interpolationDelay = interpolationDelay;

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
/// | `NetInterpolationSystem` | `update` | `UpdateSets.receive` |
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
      ..addEvent<NetPredictionCorrected>()
      ..addEvent<NetResourceUpdated>();
    replication.inputReplicator?.install(app);
    for (final rpc in replication.rpcs) {
      rpc.registerEvent(app);
    }
    for (final action in replication.actions) {
      action.register(app);
    }

    app.configureSet(
      NetSets.localInput,
      (s) => s.before(NetInputSystem.systemName),
    );
    final systems = NetworkSystems(replication);
    app
      ..addSystem(systems.pump, schedule: Schedules.first)
      ..addSystem(systems.receive, schedule: Schedules.first)
      ..addSystem(systems.interpolation, schedule: Schedules.update)
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
