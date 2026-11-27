/// ECS-facing session lifecycle and the replication engine.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:meta/meta.dart';

import '../connection/client.dart';
import '../connection/host.dart';
import '../connection/peer.dart';
import '../connection/protocol_mismatch.dart';
import '../plugin.dart';
import '../protocol/net_clock.dart';
import '../protocol/packet.dart';
import '../transport/encrypted_transport.dart';
import '../transport/transport.dart';
import '../transport/udp_transport.dart';
import 'actions.dart';
import 'components.dart';
import 'events.dart';
import 'identity.dart';
import 'inputs.dart';
import 'network_identity.dart';
import 'registry.dart';
import 'reliable_channel.dart';
import 'resources.dart';
import 'tick_sync.dart';
import 'wire.dart';

part 'host_side.dart';
part 'client_side.dart';

/// Role of a [NetworkSession].
enum NetworkRole {
  /// No session (single player, or between sessions).
  offline,

  /// Authoritative host.
  host,

  /// Client connected (or connecting) to a host.
  client,
}

/// Counters for debugging and tests. Never contains payload data.
class NetworkStats {
  /// Host: inputs dropped because the sender does not own the entity.
  int rejectedInputs = 0;

  /// Host: RPCs dropped because the sender does not own the target.
  int rejectedRpcs = 0;

  /// Actions dropped or rejected by the host's own checks (sequence,
  /// target ownership, decoding).
  int rejectedActions = 0;

  /// Host: reliable messages a client is not allowed to send.
  int rejectedMessages = 0;

  /// Client: prediction corrections applied.
  int corrections = 0;

  /// Host: snapshot chunks sent (all peers).
  int snapshotChunksSent = 0;

  /// Client: snapshot chunks received.
  int snapshotChunksReceived = 0;

  /// Host: resource chunks queued for clients.
  int resourceChunksSent = 0;

  /// Client: resource chunks applied.
  int resourceChunksReceived = 0;

  /// Host: inputs that arrived after their tick was simulated.
  int lateInputs = 0;

  /// Client: hard tick resets.
  int tickResets = 0;

  /// Host: entities skipped because their encoded state exceeded
  /// `NetworkSession.maxEntityStateBytes` (each counted once).
  int oversizedEntities = 0;
}

/// Resource that owns the live [NetworkHost] or [NetworkClient] and runs
/// the replication layer. Inserted by `NetworkPlugin`.
///
/// Start a session from app code (a menu callback, a startup system, a
/// test); the plugin systems pick it up on the next frame:
///
/// ```dart
/// final session = app.world.getResource<NetworkSession>()!;
/// await session.host(port: 7777);          // or:
/// final ok = await session.join('192.168.1.20', 7777);
/// ```
///
/// Everything that touches the [World] happens inside the plugin systems:
/// network callbacks only append to queues, which the systems drain.
class NetworkSession {
  /// Shared network configuration (also a resource).
  final NetworkConfig config;

  /// What gets replicated.
  final ReplicationRegistry registry;

  /// Monotonic clock for RTT, resend timers and tick sync. Inject a
  /// `ManualNetClock` (shared with a manual `LoopbackNetwork`) for
  /// deterministic tests.
  final NetClock clock;

  /// Creates the transport for [host] / [join] when none is passed
  /// (default: `UdpTransport()`). When `config.enableEncryption` is set
  /// the transport is wrapped in an [EncryptedTransport].
  Transport Function()? transportFactory;

  /// Diagnostics counters.
  final NetworkStats stats = NetworkStats();

  World? _world;
  NetworkRole _role = NetworkRole.offline;
  _HostSide? _host;
  _ClientSide? _client;
  final List<_EndedSide> _ending = [];
  String? _lastError;

  NetworkSession({
    required this.config,
    required this.registry,
    NetClock? clock,
    this.transportFactory,
  }) : clock = clock ?? NetClock.system;

  /// Largest encoded action payload. Actions are resent in every input
  /// packet until acknowledged, so they must stay small: send what the
  /// player did (a slot, a tile), not the state it produces.
  static const int maxActionBytes = 256;

  /// Largest encoded replicated state of one entity, in bytes: the
  /// registered components' codec output plus a few bytes of framing
  /// (a presence mask and one length varint per component).
  ///
  /// It is what fits one reliable spawn message (and therefore one
  /// snapshot entry). The host does not replicate an entity whose state is
  /// larger: it is reported once (`dart:developer` log, and
  /// [NetworkStats.oversizedEntities]), never spawned on clients, or
  /// despawned on clients if it grew past the limit, and replicated again
  /// once it fits. Everything else keeps replicating.
  static const int maxEntityStateBytes =
      ReliableChannel.maxFragmentBytes - _spawnHeaderMaxBytes <
          _snapshotEntryMaxBytes
      ? ReliableChannel.maxFragmentBytes - _spawnHeaderMaxBytes
      : _snapshotEntryMaxBytes;

  /// Room for one entity in a snapshot chunk: the payload less the
  /// header, the entity count and the entity's net id.
  static const int _snapshotEntryMaxBytes =
      Packet.maxPayloadBytes - SnapshotHeader.maxBytes - 5 - 5;

  /// Current role.
  NetworkRole get role => _role;

  /// Whether this instance is hosting.
  bool get isHost => _role == NetworkRole.host;

  /// Whether this instance is a client.
  bool get isClient => _role == NetworkRole.client;

  /// Whether a session is running.
  bool get isActive => _role != NetworkRole.offline;

  /// Host: always `true` while hosting. Client: `true` once the welcome
  /// arrived and the tick is synchronised (inputs and prediction start
  /// then).
  bool get isReady => _host != null || (_client?.ready ?? false);

  /// Whether this machine holds the host's copy of the replicated resource
  /// registered as [key]: always while hosting (or offline: it's the only
  /// copy), and on a client once at least one chunk of it has arrived. A
  /// client that has only just become [isReady] may still be showing what
  /// it had before joining; read a resource for decisions once this is true.
  bool hasReceived(String key) =>
      _client == null || _client!.received.contains(key);

  /// The underlying host while hosting.
  NetworkHost? get networkHost => _host?.host;

  /// The underlying client while joined.
  NetworkClient? get networkClient => _client?.client;

  /// `0` while hosting; the assigned peer id on a client; `null` offline.
  int? get localPeerId {
    if (_host != null) return 0;
    return _client?.peerId;
  }

  /// The newest host tick whose state this instance has: on a client, the
  /// newest snapshot received; on the host, the current tick; 0 offline.
  ///
  /// Entity state from a snapshot reflects the host up to this tick, so a
  /// client re-applying its `pendingActions` over such state skips those
  /// sent at or before it (the host has applied them by then, unless they
  /// reached it late).
  int get lastSnapshotTick {
    final c = _client;
    if (c != null) return c.lastSnapshotTick;
    return _host != null ? _host!._actionTick : 0;
  }

  /// Host: connected peer ids, ascending.
  List<int> get peerIds => _host?.sortedPeerIds() ?? const [];

  /// Round-trip time in ms: to [peerId] on the host, to the host on a
  /// client. `0` until measured.
  double rttMs([int? peerId]) {
    final h = _host;
    if (h != null && peerId != null) return h.host.getPeer(peerId)?.rtt ?? 0;
    return _client?.client.rtt ?? 0;
  }

  /// Reason the last [join] failed, or the last session ended.
  String? get lastError => _lastError;

  /// Client tick synchronisation state (null unless joined).
  ClientTickSync? get tickSync => _client?.sync;

  /// Attach the world (done by `NetworkPlugin`). Used only to validate
  /// `FixedTimestep` when a session starts.
  @internal
  void attach(World world) => _world = world;

  /// Whether the plugin systems have anything to do.
  @internal
  bool get hasWork => _host != null || _client != null || _ending.isNotEmpty;

  // Lifecycle -----------------------------------------------------------------

  /// Start hosting on [port]. Throws if a session is already running, if
  /// `FixedTimestep` does not match `config.tickRate`, or if encryption
  /// is enabled without a key.
  Future<void> host({int port = 7777, Transport? transport}) async {
    _checkCanStart();
    _localIdentity = (await config.identityProvider?.identify())?.id;
    final t = _prepareTransport(transport);
    final networkHost = NetworkHost(
      transport: t,
      maxPeers: config.maxPeers,
      connectionTimeout: config.connectionTimeout,
      sourceAuthenticator: _hostAuthenticator(),
      replaceSameIdentity: true,
      pingInterval: const Duration(milliseconds: 500),
      clock: clock,
    );
    final side = _HostSide(this, networkHost);
    _world?.getResource<NetworkTick>()
      ?..serverTick = 0
      ..localTick = 0
      ..synced = true;
    _host = side;
    _role = NetworkRole.host;
    config.mode = NetworkMode.host;
    _lastError = null;
    try {
      await networkHost.start(port);
    } catch (e) {
      side.dispose();
      _host = null;
      _role = NetworkRole.offline;
      config.mode = NetworkMode.offline;
      rethrow;
    }
  }

  /// Join the host at [address]:[port]. Resolves to `true` once the host
  /// accepted the connection (the welcome and tick sync follow within a
  /// few round trips; see [isReady] and the `NetConnected` event).
  ///
  /// [credentials] default to the UTF-8 bytes of `config.serverPassword`.
  /// On failure resolves to `false` and [lastError] holds the reason.
  Future<bool> join(
    String address,
    int port, {
    Transport? transport,
    Uint8List? credentials,
  }) async {
    _checkCanStart();
    final ClientIdentity? identity;
    try {
      identity = await config.identityProvider?.identify();
    } catch (e) {
      _lastError = 'Could not identify the player: $e';
      return false;
    }
    _localIdentity = identity?.id;
    final t = _prepareTransport(transport);
    final networkClient = NetworkClient(
      transport: t,
      connectionTimeout: config.connectionTimeout,
      pingInterval: const Duration(milliseconds: 500),
      clock: clock,
    );
    final side = _ClientSide(this, networkClient);
    _client = side;
    _role = NetworkRole.client;
    config.mode = NetworkMode.client;
    _lastError = null;
    final password = config.serverPassword;
    final ok = await networkClient.connect(
      address,
      port,
      clientId: identity?.id ?? anonymousClientId,
      credentials: _frameCredentials(
        credentials ??
            (password == null
                ? Uint8List(0)
                : Uint8List.fromList(utf8.encode(password))),
        identity?.proof ?? Uint8List(0),
      ),
    );
    if (!identical(_client, side)) return false; // closed meanwhile
    if (!ok) {
      _lastError =
          networkClient.lastStateReason ??
          side.failureReason ??
          'Connection failed';
      side.dispose();
      _client = null;
      _role = NetworkRole.offline;
      config.mode = NetworkMode.offline;
      unawaited(networkClient.disconnect().catchError((Object _) {}));
      return false;
    }
    side.onConnected();
    return true;
  }

  /// End the session. Hosts disconnect every peer; clients notify the
  /// host. On the next frame clients despawn all replicated entities and
  /// a `NetDisconnected` event is sent.
  Future<void> close([String reason = 'Session closed']) async {
    final h = _host;
    final c = _client;
    _endSide(reason);
    if (h != null) await h.host.stop();
    if (c != null) await c.client.disconnect();
  }

  void _endSide(String reason) {
    final h = _host;
    final c = _client;
    if (h != null) {
      h.dispose();
      _ending.add(_EndedSide(host: h, reason: reason));
    }
    if (c != null) {
      c.dispose();
      _ending.add(_EndedSide(client: c, reason: reason));
    }
    _host = null;
    _client = null;
    _role = NetworkRole.offline;
    config.mode = NetworkMode.offline;
  }

  /// Client: the connection failed after connecting (timeout, kicked,
  /// handshake mismatch).
  void _failClient(String reason) {
    final c = _client;
    if (c == null) return;
    _lastError = reason;
    _endSide(reason);
    unawaited(c.client.disconnect().catchError((Object _) {}));
  }

  void _checkCanStart() {
    if (_role != NetworkRole.offline || _host != null || _client != null) {
      throw StateError('A network session is already running');
    }
    if (config.tickRate <= 0 || config.syncRate <= 0) {
      throw StateError('NetworkConfig.tickRate and syncRate must be > 0');
    }
    final step = _world?.getResource<FixedTimestep>();
    if (step != null) {
      final expectedUs = 1e6 / config.tickRate;
      if ((step.stepDuration.inMicroseconds - expectedUs).abs() > 1.0) {
        throw StateError(
          'FixedTimestep.stepDuration (${step.stepDuration.inMicroseconds}us) '
          'does not match NetworkConfig.tickRate (${config.tickRate} Hz, '
          '${expectedUs.round()}us). Insert config.fixedTimestep() as the '
          'FixedTimestep resource.',
        );
      }
    }
  }

  Transport _prepareTransport(Transport? transport) {
    Transport t = transport ?? transportFactory?.call() ?? UdpTransport();
    if (config.enableEncryption) {
      final key = config.encryptionKey;
      if (key == null) {
        throw StateError(
          'NetworkConfig.enableEncryption is set but encryptionKey is null; '
          'provide the pre-shared 32-byte key',
        );
      }
      // EncryptedTransport validates the key length; its error message
      // contains only the length, never key material.
      t = EncryptedTransport(inner: t, sharedKey: key);
    }
    return t;
  }

  /// The connect handshake's credentials: the password (or app
  /// credentials) and the identity proof, each length-prefixed.
  static Uint8List _frameCredentials(Uint8List secret, Uint8List proof) =>
      (PacketBuilder()
            ..writeBytes(secret)
            ..writeBytes(proof))
          .build();

  /// Checks a joining client: its credentials framing, the password, its
  /// identity (with [NetworkConfig.identityVerifier]) and then any custom
  /// [NetworkConfig.authenticator], which receives the password slot.
  Future<bool> Function(
    String clientId,
    Uint8List credentials,
    NetAddress source,
  )
  _hostAuthenticator() {
    final custom = config.authenticator;
    final password = config.serverPassword;
    final expected = password == null
        ? null
        : Uint8List.fromList(utf8.encode(password));
    final verifier = config.identityVerifier;
    return (clientId, credentials, source) async {
      final Uint8List secret;
      final Uint8List proof;
      try {
        final reader = PacketReader(credentials);
        secret = reader.readBytes();
        proof = reader.readBytes();
      } on Object {
        return false;
      }
      if (expected != null && !_constantTimeEquals(expected, secret)) {
        return false;
      }
      if (clientId != anonymousClientId) {
        if (ClientIdentity.validate(clientId) != null) return false;
        // Nobody joins as the host: with a trusting verifier anyone could
        // claim it (or a second copy of the game on the host's machine,
        // sharing its identity, would), and become the host's player.
        if (clientId == _localIdentity) return false;
        if (verifier != null &&
            !await verifier.verify(clientId, proof, source: source)) {
          return false;
        }
      }
      return custom == null ? true : custom(clientId, secret);
    };
  }

  String? _localIdentity;

  /// This player's identity, from [NetworkConfig.identityProvider], once a
  /// session has started (null if none was configured).
  String? get localIdentity => _localIdentity;

  /// Host: the identity peer [peerId] joined with, or null if it joined
  /// anonymously or isn't connected.
  String? identityOf(int peerId) {
    final identity = _host?.identityOf(peerId) ?? '';
    return identity.isEmpty || identity == anonymousClientId ? null : identity;
  }

  /// Host: the connected peer that joined as [identity], or null.
  int? peerFor(String identity) {
    for (final peer in _host?.host.peers ?? const <Peer>[]) {
      if (peer.identity == identity && peer.isConnected) return peer.id;
    }
    return null;
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    var diff = a.length ^ b.length;
    final n = math.max(a.length, b.length);
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      diff |= x ^ y;
    }
    return diff == 0;
  }

  // RPC -----------------------------------------------------------------------

  /// Send RPC [value] (type [T] must be registered with
  /// `ReplicationRegistry.rpc`). On a client it goes to the host; on the
  /// host it is broadcast to every client (except [exceptPeer]).
  ///
  /// [target] optionally names a replicated entity. The host rejects
  /// client RPCs whose target the client does not own.
  ///
  /// Delivery is reliable and ordered with spawns/despawns; RPCs are
  /// flushed at the end of the next fixed tick.
  void sendRpc<T>(T value, {Entity? target, int? exceptPeer}) {
    final rep = _rpcRep<T>();
    final bytes = rep.encode(value);
    final h = _host;
    if (h != null) {
      h.queueRpc(rep.index, bytes, target, null, exceptPeer);
      return;
    }
    final c = _client;
    if (c == null) throw StateError('No network session');
    c.queueRpc(rep.index, bytes, target);
  }

  /// Client: queue RPC [value] naming [targetNetId] as its target
  /// verbatim, skipping the local entity lookup [sendRpc] does. Lets
  /// tests impersonate a modified client; see
  /// `package:fledge_net/testing.dart`.
  @internal
  void queueRpcForNetId<T>(T value, int targetNetId) {
    final c = _client;
    if (c == null) throw StateError('queueRpcForNetId is client-only');
    final rep = _rpcRep<T>();
    c.queueRpcForNetId(rep.index, rep.encode(value), targetNetId);
  }

  /// Host: send RPC [value] to one peer.
  void sendRpcTo<T>(int peerId, T value, {Entity? target}) {
    final h = _host;
    if (h == null) throw StateError('sendRpcTo is host-only');
    final rep = _rpcRep<T>();
    h.queueRpc(rep.index, rep.encode(value), target, peerId, null);
  }

  // Actions --------------------------------------------------------------------

  /// Send player action [value] (type [T] must be registered with
  /// `ReplicationRegistry.action`), optionally naming a [target] entity
  /// the sender owns.
  ///
  /// The host gets it exactly once, in order, in `NetActions<T>` on the
  /// tick it was sent at (the host's own actions on its next tick), and
  /// accepts or rejects it with [resolveAction]. Until the host's state
  /// shows the result it is listed by [pendingActions]; the outcome
  /// arrives as a `NetActionResolved<T>` event.
  ///
  /// Call it from a fixed-step system (e.g. alongside the tick's inputs)
  /// so the action carries that tick.
  NetActionTicket sendAction<T>(T value, {Entity? target}) {
    final rep = _actionRep<T>();
    final h = _host;
    if (h != null) return h.queueLocalAction(rep.index, value, target);
    final c = _client;
    if (c == null || !c.connected) throw StateError('Not connected');
    final length = rep.encode(value).length;
    if (length > maxActionBytes) {
      throw ArgumentError.value(
        length,
        'action payload',
        'exceeds maxActionBytes ($maxActionBytes)',
      );
    }
    return c.queueAction(rep.index, value, target);
  }

  /// Host: accept or reject [action] (from this tick's `NetActions<T>`).
  /// [reason] travels to the sender with the outcome. An action not
  /// resolved by the end of its tick is accepted. Returns `false` if it
  /// was already resolved.
  bool resolveAction(
    NetAction<Object?> action, {
    required bool accepted,
    String? reason,
  }) {
    final h = _host;
    if (h == null) throw StateError('resolveAction is host-only');
    return h.resolveAction(
      action.peerId,
      action.seq,
      accepted: accepted,
      reason: reason,
    );
  }

  /// Actions of type [T] this instance sent whose effect the host's
  /// state does not show yet, oldest first: not yet resolved, or accepted
  /// at a tick newer than the latest snapshot. A rejected action leaves
  /// the list at once.
  ///
  /// This is how a client shows an action straight away: draw (or apply
  /// to a copy of) the authoritative state, then each pending action's
  /// effect on top. Accepted actions stay listed until the host's state
  /// includes them, so the effect never flickers off and back on.
  ///
  /// Replicated resources are exact here: a resolution is sent after every
  /// resource chunk queued before it. Entity state is as of the newest
  /// snapshot ([lastSnapshotTick]), which under a tight send budget may not
  /// list every change; to re-apply actions over it (an action that isn't
  /// idempotent, such as moving an item), skip those whose tick is at or
  /// before [lastSnapshotTick].
  List<NetPendingAction<T>> pendingActions<T>() {
    final rep = _actionRep<T>();
    final source = _host != null
        ? _host!.localOutstanding(rep.index)
        : _client?.outstanding(rep.index) ?? const <OutstandingAction>[];
    return [
      for (final a in source)
        rep.pending(
              a.seq,
              a.tick,
              a.value,
              a.target,
              accepted: a.acceptedAt != null,
            )
            as NetPendingAction<T>,
    ];
  }

  /// Client: put action [value] on the wire with a chosen [seq], [tick]
  /// and [targetNetId], bypassing the client's own bookkeeping (testing
  /// hook; see `package:fledge_net/testing.dart`).
  @internal
  void queueRawAction<T>(
    T value, {
    required int seq,
    required int tick,
    int targetNetId = 0,
  }) {
    final c = _client;
    if (c == null) throw StateError('queueRawAction is client-only');
    final rep = _actionRep<T>();
    c._rawActions.add(
      ActionEntry(rep.index, seq, tick, targetNetId, rep.encode(value)),
    );
  }

  ActionReplicator<Object?> _actionRep<T>() {
    final rep = registry.actionFor(T);
    if (rep == null) {
      throw ArgumentError('Action type $T is not registered');
    }
    return rep;
  }

  RpcReplicator<Object?> _rpcRep<T>() {
    final rep = registry.rpcFor(T);
    if (rep == null) {
      throw ArgumentError('RPC type $T is not registered');
    }
    return rep;
  }

  // System entry points (called by the plugin systems) ------------------------

  /// `NetPumpSystem`: drive the connection, answer tick sync, resend.
  @internal
  void pump(World world) {
    _host?.pump(world);
    _client?.pump(world);
  }

  /// `NetReceiveSystem`: apply inbound packets to the world.
  @internal
  void receive(World world) {
    if (_ending.isNotEmpty) {
      final ended = List<_EndedSide>.of(_ending);
      _ending.clear();
      for (final e in ended) {
        e.cleanup(world, this);
      }
    }
    _host?.receive(world);
    _client?.receive(world);
  }

  /// `NetInterpolationSystem`: write interpolated component values.
  @internal
  void interpolate(World world) => _client?.interpolate(world);

  /// `NetTickSystem`: advance the network tick for this fixed step.
  @internal
  void fixedTick(World world) {
    final tick = world.getResource<NetworkTick>();
    final ts = world.getResource<FixedTimestep>();
    if (tick == null || ts == null) return;
    if (_host != null) {
      tick
        ..advanceStep(ts.stepSeconds)
        ..localTick = tick.serverTick
        ..synced = true;
      return;
    }
    final c = _client;
    if (c == null || !c.sync.synced) return;
    final adjust = c.sync.step();
    if (adjust != 0) ts.nudge(adjust * ts.stepSeconds);
    tick
      ..localTick = c.sync.localTick
      ..serverTick = c.sync.serverTickEstimate
      ..deltaTime = ts.stepSeconds
      ..synced = true;
  }

  /// `NetInputSystem`: build `NetInputs<I>` for this tick.
  @internal
  void gatherInputs(World world) {
    _host?.gatherInputs(world);
    _host?.releaseActions(world);
    _client?.gatherInputs(world);
  }

  /// `NetPredictSystem`: host applies predicted steps; client reconciles
  /// and predicts.
  @internal
  void predict(World world) {
    _host?.predict(world);
    _client?.predict(world);
  }

  /// `NetSendSystem`: replicate (host) / send inputs (client).
  @internal
  void send(World world) {
    _host?.send(world);
    _client?.send(world);
  }

  // Helpers -------------------------------------------------------------------

  double get _stepMs => 1000.0 / config.tickRate;

  int _resendAfterMs(double rtt) {
    if (rtt <= 0) return 250;
    return (rtt * 1.5 + 2 * _stepMs).clamp(50, 2000).round();
  }

  static void _emit<T>(World world, T event) {
    if (world.events.isRegistered<T>()) {
      world.eventWriter<T>().send(event);
    }
  }

  /// Fire-and-forget send of [payload].
  ///
  /// An oversized payload is a programming error: it throws
  /// [ArgumentError] synchronously, at the call site, instead of becoming
  /// an unhandled asynchronous error. Asynchronous failures (closed
  /// transport, socket errors) are dropped like any lost datagram.
  static void _sendSafely(Uint8List payload, Future<void> Function() send) {
    Packet.checkPayloadSize(payload);
    unawaited(send().catchError((Object _) {}));
  }
}

/// A side whose session ended; cleaned up by the next receive pass.
class _EndedSide {
  final _HostSide? host;
  final _ClientSide? client;
  final String reason;

  _EndedSide({this.host, this.client, required this.reason});

  void cleanup(World world, NetworkSession session) {
    final registry = world.getResource<NetworkEntityRegistry>();
    final tick = world.getResource<NetworkTick>();
    final c = client;
    if (c != null) {
      for (final info in c.entities.values) {
        if (world.isAlive(info.entity)) world.despawnRecursive(info.entity);
      }
      c.entities.clear();
    }
    registry?.clear();
    if (tick != null) tick.synced = false;
    NetworkSession._emit(world, NetDisconnected(reason));
  }
}
