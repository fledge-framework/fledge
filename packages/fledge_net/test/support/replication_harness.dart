// Shared fixtures for the replication tests: pure-Dart stand-ins for a
// local transform (Pos), its world-space result (GlobalPos, computed by a
// tiny propagate system), a movement input and an RPC, plus a driver that
// runs one host App and N client Apps over a manual LoopbackNetwork.
import 'dart:async';
import 'dart:math';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';

/// Local (parent-relative) position. Stand-in for Transform2D.
class Pos {
  final double x;
  final double y;

  const Pos(this.x, this.y);

  @override
  String toString() => 'Pos(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// World position computed from the hierarchy. Stand-in for
/// GlobalTransform2D.
class GlobalPos {
  double x = 0;
  double y = 0;
}

/// Replicated, non-interpolated component.
class Health {
  final int hp;

  const Health(this.hp);
}

/// Movement input.
class Move {
  final double dx;
  final double dy;

  const Move(this.dx, this.dy);
}

/// RPC payload.
class Emote {
  final String name;

  const Emote(this.name);
}

/// Units per second for a full-strength Move.
const double moveSpeed = 50;

Pos stepPos(Pos s, Move m, double dt) =>
    Pos(s.x + m.dx * moveSpeed * dt, s.y + m.dy * moveSpeed * dt);

double posError(Pos a, Pos b) =>
    sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

final posCodec = NetCodec<Pos>.of(
  encode: (p, out) => out
    ..writeFloat32(p.x)
    ..writeFloat32(p.y),
  decode: (r) => Pos(r.readFloat32(), r.readFloat32()),
);

final healthCodec = NetCodec<Health>.of(
  encode: (h, out) => out.writeVarUint(h.hp),
  decode: (r) => Health(r.readVarUint()),
);

final moveCodec = NetCodec<Move>.of(
  encode: (m, out) => out
    ..writeFloat32(m.dx)
    ..writeFloat32(m.dy),
  decode: (r) => Move(r.readFloat32(), r.readFloat32()),
);

final emoteCodec = NetCodec<Emote>.of(
  encode: (e, out) => out.writeString(e.name),
  decode: (r) => Emote(r.readString()),
);

/// Registry used by every test App (host and clients must match).
ReplicationRegistry buildRegistry({bool predict = true, double blend = 1}) {
  final r = ReplicationRegistry()
    ..component<Pos>(
      'pos',
      posCodec,
      interpolate: (a, b, t) =>
          Pos(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t),
    )
    ..component<Health>('health', healthCodec)
    ..input<Move>(moveCodec)
    ..rpc<Emote>('emote', emoteCodec)
    ..positionOf = (world, e) {
      final g = world.get<GlobalPos>(e);
      return g == null ? null : (g.x, g.y);
    };
  if (predict) {
    r.predict<Pos, Move>(
      step: stepPos,
      error: posError,
      tolerance: 0.01,
      correctionBlend: blend,
    );
  }
  return r;
}

/// Computes GlobalPos from Pos and Parent (translation only). Stand-in for
/// TransformPropagateSystem; runs in Schedules.preUpdate.
class GlobalPosPropagateSystem implements System {
  static const String systemName = 'test_global_pos_propagate';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    reads: {
      ComponentId.of<Pos>(),
      ComponentId.of<Parent>(),
      ComponentId.of<Children>(),
    },
    writes: {ComponentId.of<GlobalPos>()},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final roots = [
      for (final (e, _)
          in world.query1<Pos>(filter: const Without<Parent>()).iter())
        e,
    ];
    for (final e in roots) {
      _apply(world, e, 0, 0);
    }
    return Future.value();
  }

  void _apply(World world, Entity e, double px, double py) {
    final local = world.get<Pos>(e);
    if (local == null) return;
    var g = world.get<GlobalPos>(e);
    if (g == null) {
      g = GlobalPos();
      world.insert(e, g);
    }
    g
      ..x = px + local.x
      ..y = py + local.y;
    for (final child in world.getChildren(e).toList()) {
      _apply(world, child, g.x, g.y);
    }
  }
}

/// What the local player is pressing (per App).
class Driving {
  Move? move;
}

/// Records every network ECS event seen (read once, in Schedules.last).
class EventLog {
  final peerConnected = <NetPeerConnected>[];
  final peerDisconnected = <NetPeerDisconnected>[];
  final connected = <NetConnected>[];
  final disconnected = <NetDisconnected>[];
  final rejected = <NetRejected>[];
  final corrected = <NetPredictionCorrected>[];
  final spawned = <NetEntitySpawned>[];
  final despawned = <NetEntityDespawned>[];
  final emotes = <NetRpcReceived<Emote>>[];
}

/// Host scene: a vehicle plus one avatar per connected peer.
class HostScene {
  bool spawnAvatars = true;
  Entity? vehicle;
  double vehicleVx = 0;
  final Map<int, Entity> avatars = {};
}

/// Submits Driving.move for every entity this instance owns.
class SubmitInputSystem implements System {
  static const String systemName = 'test_submit_input';

  @override
  SystemMeta get meta => SystemMeta(
    name: systemName,
    sets: const [NetSets.localInput],
    reads: {ComponentId.of<NetworkIdentity>()},
    resourceReads: {Driving, NetworkSession},
    resourceWrites: {NetLocalInputs<Move>},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final move = world.getResource<Driving>()?.move;
    final peer = world.getResource<NetworkSession>()?.localPeerId;
    if (move == null || peer == null) return Future.value();
    final inputs = world.getResource<NetLocalInputs<Move>>()!;
    for (final (e, id) in world.query1<NetworkIdentity>().iter()) {
      if (id.ownerId == peer) inputs.submit(e, move);
    }
    return Future.value();
  }
}

class EventRecorderSystem implements System {
  @override
  SystemMeta get meta =>
      const SystemMeta(name: 'test_event_recorder', resourceWrites: {EventLog});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final log = world.getResource<EventLog>()!;
    log.peerConnected.addAll(world.eventReader<NetPeerConnected>().read());
    log.peerDisconnected.addAll(
      world.eventReader<NetPeerDisconnected>().read(),
    );
    log.connected.addAll(world.eventReader<NetConnected>().read());
    log.disconnected.addAll(world.eventReader<NetDisconnected>().read());
    log.rejected.addAll(world.eventReader<NetRejected>().read());
    log.corrected.addAll(world.eventReader<NetPredictionCorrected>().read());
    log.spawned.addAll(world.eventReader<NetEntitySpawned>().read());
    log.despawned.addAll(world.eventReader<NetEntityDespawned>().read());
    log.emotes.addAll(world.eventReader<NetRpcReceived<Emote>>().read());
    return Future.value();
  }
}

/// Host: spawns an avatar (owned by the peer, parented to the vehicle)
/// for every connecting peer.
class HostSceneSystem implements System {
  @override
  SystemMeta get meta =>
      const SystemMeta(name: 'test_host_scene', resourceWrites: {HostScene});

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final scene = world.getResource<HostScene>()!;
    final vehicle = scene.vehicle;
    for (final e in world.eventReader<NetPeerConnected>().read()) {
      if (!scene.spawnAvatars || vehicle == null) continue;
      final avatar = world.spawn()
        ..insert(Replicated(owner: e.peerId))
        ..insert(Pos(e.peerId * 2.0, 0))
        ..insert(const Health(100));
      world.setParent(avatar.entity, vehicle);
      scene.avatars[e.peerId] = avatar.entity;
    }
    return Future.value();
  }
}

/// Host: moves the vehicle along x in the fixed step.
class VehicleMoveSystem implements System {
  @override
  SystemMeta get meta => SystemMeta(
    name: 'test_vehicle_move',
    writes: {ComponentId.of<Pos>()},
    resourceReads: {HostScene, FixedTimestep},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final scene = world.getResource<HostScene>()!;
    final v = scene.vehicle;
    if (v == null || scene.vehicleVx == 0 || !world.isAlive(v)) {
      return Future.value();
    }
    final dt = world.getResource<FixedTimestep>()!.stepSeconds;
    final p = world.get<Pos>(v)!;
    world.insert(v, Pos(p.x + scene.vehicleVx * dt, p.y));
    return Future.value();
  }
}

/// One host App and any number of client Apps on a manual-clock
/// LoopbackNetwork. Every frame advances the network clock by exactly one
/// fixed step and ticks each App with that delta, so each App runs exactly
/// one fixed step per frame (time dilation may add or skip one).
class NetTestbed {
  final int tickRate;
  final ManualNetClock clock = ManualNetClock(10000);
  late final LoopbackNetwork net;
  final NetworkConfig Function() makeConfig;
  final ReplicationRegistry Function() makeRegistry;
  App? host;
  final List<App> clients = [];
  int frameCount = 0;

  NetTestbed({
    this.tickRate = 50,
    Duration latency = Duration.zero,
    Duration jitter = Duration.zero,
    double packetLoss = 0,
    int seed = 1,
    NetworkConfig Function()? config,
    ReplicationRegistry Function()? registry,
  }) : makeConfig = config ?? NetworkConfig.new,
       makeRegistry = registry ?? buildRegistry {
    net = LoopbackNetwork(
      clock: clock,
      latency: latency,
      jitter: jitter,
      packetLoss: packetLoss,
      random: Random(seed),
    );
  }

  int get stepMs => 1000 ~/ tickRate;

  List<App> get apps => [?host, ...clients];

  App createApp({required bool isHost}) {
    final config = makeConfig()..tickRate = tickRate;
    final app = App()
      ..insertResource(config.fixedTimestep())
      ..insertResource(WallTime()..delta = stepMs / 1000)
      ..addPlugin(
        NetworkPlugin(
          config: config,
          replication: makeRegistry(),
          clock: clock,
          transportFactory: net.createTransport,
        ),
      )
      ..insertResource(Driving())
      ..insertResource(EventLog())
      ..insertResource(HostScene())
      ..addSystem(GlobalPosPropagateSystem(), schedule: Schedules.preUpdate)
      ..addSystem(SubmitInputSystem(), schedule: Schedules.fixedPreUpdate)
      ..addSystem(EventRecorderSystem(), schedule: Schedules.last);
    if (isHost) {
      app
        ..addSystem(HostSceneSystem(), schedule: Schedules.update)
        ..addSystem(VehicleMoveSystem(), schedule: Schedules.fixedUpdate);
    }
    return app;
  }

  /// Start the host and spawn the vehicle.
  Future<App> startHost({bool vehicle = true}) async {
    final app = host = createApp(isHost: true);
    await session(app).host(port: 7777);
    if (vehicle) {
      final v = app.world.spawn()
        ..insert(Replicated(alwaysRelevant: true))
        ..insert(const Pos(0, 0))
        ..insert(const Health(500));
      app.world.getResource<HostScene>()!.vehicle = v.entity;
    }
    await frame();
    return app;
  }

  /// Create a client and join; the connect handshake itself runs on a
  /// loss-free link (connect retries use real-time timers), everything
  /// after it on the configured link.
  Future<App> addClient({
    Duration readyTimeout = const Duration(seconds: 5),
  }) async {
    final app = createApp(isHost: false);
    clients.add(app);
    final loss = net.packetLoss;
    net.packetLoss = 0;
    final ok = await pumpUntil(session(app).join('127.0.0.1', 7777));
    net.packetLoss = loss;
    if (!ok) throw StateError('join failed: ${session(app).lastError}');
    await runUntil(
      () => session(app).isReady,
      maxFrames: readyTimeout.inMilliseconds ~/ stepMs,
      what: 'client ready',
    );
    return app;
  }

  static NetworkSession session(App app) =>
      app.world.getResource<NetworkSession>()!;

  static EventLog log(App app) => app.world.getResource<EventLog>()!;

  Future<void> frame() async {
    await net.advance(Duration(milliseconds: stepMs));
    for (final app in apps) {
      await app.tick();
    }
    frameCount++;
  }

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      await frame();
    }
  }

  Future<T> pumpUntil<T>(Future<T> future, {int maxFrames = 2000}) async {
    var done = false;
    late T result;
    Object? error;
    future.then(
      (v) {
        result = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    for (var i = 0; i < maxFrames && !done; i++) {
      await frame();
      if (!done) await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    if (!done) throw StateError('future did not complete in $maxFrames frames');
    if (error != null) throw error!;
    return result;
  }

  Future<void> runUntil(
    bool Function() condition, {
    int maxFrames = 500,
    String what = 'condition',
  }) async {
    for (var i = 0; i < maxFrames; i++) {
      if (condition()) return;
      await frame();
    }
    if (!condition()) {
      throw StateError('$what not reached within $maxFrames frames');
    }
  }

  Future<void> dispose() async {
    for (final app in apps) {
      await session(app).close();
    }
    net.clearInFlight();
  }
}

/// Entity on [app] with network id [netId], or null.
Entity? entityFor(App app, int netId) =>
    app.world.getResource<NetworkEntityRegistry>()!.getEntity(netId);

/// Network id of [entity] on [app].
int netIdOf(App app, Entity entity) =>
    app.world.getResource<NetworkEntityRegistry>()!.getNetId(entity)!;
