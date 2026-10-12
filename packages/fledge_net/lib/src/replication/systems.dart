import 'package:fledge_ecs/fledge_ecs.dart';

import '../plugin.dart';
import '../sync/network_identity.dart';
import 'components.dart';
import 'events.dart';
import 'registry.dart';
import 'session.dart';

/// System set names exposed by the network plugin.
abstract final class NetSets {
  /// Join this set (in `Schedules.fixedPreUpdate`) with the system that
  /// calls `NetLocalInputs.submit`; the plugin orders it before
  /// `NetInputSystem`.
  static const String localInput = 'net.localInput';
}

bool _sessionHasWork(World world) =>
    world.getResource<NetworkSession>()?.hasWork ?? false;

abstract class _NetSystem implements System {
  @override
  RunCondition? get runCondition => _sessionHasWork;

  @override
  bool shouldRun(World world) => _sessionHasWork(world);

  void runNet(NetworkSession session, World world);

  @override
  Future<void> run(World world) {
    final session = world.getResource<NetworkSession>();
    if (session != null) runNet(session, world);
    return Future.value();
  }
}

/// `Schedules.first`, `FirstSets.platform`: drives the host/client
/// (`update()`: pings, timeouts, retransmits), answers tick sync, turns
/// connection changes into ECS events and resends reliable messages.
class NetPumpSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_pump';

  @override
  final SystemMeta meta = const SystemMeta(
    name: systemName,
    sets: [FirstSets.platform],
    resourceWrites: {NetworkSession, NetworkTick},
    eventWrites: {NetPeerConnected, NetConnected, NetProtocolMismatch},
  );

  @override
  void runNet(NetworkSession session, World world) => session.pump(world);
}

/// `Schedules.first`, after every `FirstSets` phase: applies received
/// packets to the world (client: spawns, despawns, hierarchy, ownership,
/// snapshots, RPC events; host: validated inputs and RPCs, disconnect
/// policy).
class NetReceiveSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_receive';

  @override
  final SystemMeta meta;

  NetReceiveSystem(ReplicationRegistry registry)
    : meta = SystemMeta(
        name: systemName,
        after: [NetPumpSystem.systemName, ...FirstSets.chain],
        writes: {
          ComponentId.of<NetworkIdentity>(),
          ComponentId.of<Parent>(),
          ComponentId.of<Children>(),
          for (final c in registry.components) c.componentId,
        },
        resourceReads: {FixedTimestep},
        resourceWrites: {NetworkSession, NetworkEntityRegistry, NetworkTick},
        eventWrites: {
          NetPeerDisconnected,
          NetDisconnected,
          NetRejected,
          NetEntitySpawned,
          NetEntityDespawned,
          for (final r in registry.rpcs) r.eventType,
        },
      );

  @override
  void runNet(NetworkSession session, World world) => session.receive(world);
}

/// `Schedules.first`, after `NetReceiveSystem`: writes interpolated
/// component values for entities this client does not predict.
class NetInterpolationSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_interpolation';

  @override
  final SystemMeta meta;

  NetInterpolationSystem(ReplicationRegistry registry)
    : meta = SystemMeta(
        name: systemName,
        after: [NetReceiveSystem.systemName],
        writes: {
          for (final c in registry.components)
            if (c.interpolated) c.componentId,
        },
        resourceReads: {FixedTimestep},
        resourceWrites: {NetworkSession},
      );

  @override
  void runNet(NetworkSession session, World world) =>
      session.interpolate(world);
}

/// `Schedules.fixedFirst`: advances `NetworkTick` (host: authoritative
/// tick; client: leading local tick with time dilation).
class NetTickSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_tick';

  @override
  final SystemMeta meta = const SystemMeta(
    name: systemName,
    resourceWrites: {NetworkTick, FixedTimestep, NetworkSession},
  );

  @override
  void runNet(NetworkSession session, World world) => session.fixedTick(world);
}

/// `Schedules.fixedPreUpdate`, after `NetSets.localInput`: builds
/// `NetInputs<I>` for this tick (host: validated client inputs + local;
/// client: own inputs, recorded for sending and replay).
class NetInputSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_input';

  @override
  final SystemMeta meta;

  NetInputSystem(ReplicationRegistry registry)
    : meta = SystemMeta(
        name: systemName,
        after: const [NetSets.localInput],
        reads: {ComponentId.of<NetworkIdentity>()},
        resourceReads: {NetworkTick, NetworkEntityRegistry},
        resourceWrites: {
          NetworkSession,
          if (registry.inputReplicator != null) ...[
            registry.inputReplicator!.inputsType,
            registry.inputReplicator!.localInputsType,
          ],
        },
      );

  @override
  void runNet(NetworkSession session, World world) =>
      session.gatherInputs(world);
}

/// `Schedules.fixedPreUpdate`, after `NetInputSystem`: the host applies
/// registered prediction steps to every entity with an input; a client
/// reconciles against the newest server state and predicts its own
/// entities.
class NetPredictSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_predict';

  @override
  final SystemMeta meta;

  NetPredictSystem(ReplicationRegistry registry)
    : meta = SystemMeta(
        name: systemName,
        after: const [NetInputSystem.systemName],
        writes: {for (final p in registry.predictions) p.component.componentId},
        resourceReads: {
          FixedTimestep,
          if (registry.inputReplicator != null)
            registry.inputReplicator!.inputsType,
        },
        resourceWrites: {NetworkSession},
        eventWrites: {NetPredictionCorrected},
      );

  @override
  void runNet(NetworkSession session, World world) => session.predict(world);
}

/// `Schedules.fixedLast`: host assigns network ids, computes interest,
/// sends spawns/despawns/hierarchy/ownership reliably and snapshots every
/// `syncInterval` ticks; client records predictions and sends its inputs.
class NetSendSystem extends _NetSystem {
  /// Name for `before:` / `after:`.
  static const String systemName = 'net_send';

  @override
  final SystemMeta meta;

  NetSendSystem(ReplicationRegistry registry)
    : meta = SystemMeta(
        name: systemName,
        reads: {
          ComponentId.of<Replicated>(),
          ComponentId.of<Parent>(),
          for (final c in registry.components) c.componentId,
        },
        writes: {ComponentId.of<NetworkIdentity>()},
        resourceReads: {NetworkTick},
        resourceWrites: {NetworkSession, NetworkEntityRegistry},
      );

  @override
  void runNet(NetworkSession session, World world) => session.send(world);
}

/// The plugin systems for one registry.
class NetworkSystems {
  final NetPumpSystem pump;
  final NetReceiveSystem receive;
  final NetInterpolationSystem interpolation;
  final NetTickSystem tick;
  final NetInputSystem input;
  final NetPredictSystem predict;
  final NetSendSystem send;

  NetworkSystems(ReplicationRegistry registry)
    : pump = NetPumpSystem(),
      receive = NetReceiveSystem(registry),
      interpolation = NetInterpolationSystem(registry),
      tick = NetTickSystem(),
      input = NetInputSystem(registry),
      predict = NetPredictSystem(registry),
      send = NetSendSystem(registry);
}
