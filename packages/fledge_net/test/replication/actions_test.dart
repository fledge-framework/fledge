// Sequenced player actions: exactly once, in order, on the tick sent;
// resolved by the host; pending on the sender until the host's state
// shows them.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net/testing.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// Plant something in [spot].
class Plant {
  final int spot;
  const Plant(this.spot);
}

final plantCodec = NetCodec<Plant>.of(
  encode: (p, out) => out.writeInt32(p.spot),
  decode: (r) => Plant(r.readInt32()),
);

/// Shared, replicated: which spots are planted.
class Garden {
  final Set<int> planted = {};
  int version = 0;
}

final gardenCodec = ResourceCodec<Garden>.whole(
  encode: (g, out) {
    final spots = g.planted.toList()..sort();
    out.writeVarUint(spots.length);
    for (final s in spots) {
      out.writeInt32(s);
    }
  },
  decode: (g, input) {
    g.planted.clear();
    for (var n = input.readVarUint(); n > 0; n--) {
      g.planted.add(input.readInt32());
    }
  },
  version: (g) => g.version,
);

/// What the host was handed, and what each instance heard back.
class ActionLog {
  /// Host: (action, NetActions.tick) in delivery order.
  final delivered = <(NetAction<Plant>, int)>[];
  final resolved = <NetActionResolved<Plant>>[];
}

/// Host, fixedUpdate: plants free spots, rejects taken ones, leaves
/// negative spots unresolved (accepted by default).
class GardenSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
    name: 'test_garden',
    resourceReads: {NetActions<Plant>},
    resourceWrites: {Garden, ActionLog, NetworkSession},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    final session = world.getResource<NetworkSession>()!;
    if (!session.isHost) return Future.value();
    final actions = world.getResource<NetActions<Plant>>()!;
    final garden = world.getResource<Garden>()!;
    final log = world.getResource<ActionLog>()!;
    for (final a in actions.entries) {
      log.delivered.add((a, actions.tick));
      final spot = a.value.spot;
      if (spot < 0) continue;
      if (garden.planted.contains(spot)) {
        session.resolveAction(a, accepted: false, reason: 'taken');
        continue;
      }
      garden
        ..planted.add(spot)
        ..version += 1;
      session.resolveAction(a, accepted: true);
    }
    return Future.value();
  }
}

class ResolvedRecorderSystem implements System {
  @override
  SystemMeta get meta => const SystemMeta(
    name: 'test_resolved_recorder',
    resourceWrites: {ActionLog},
  );

  @override
  RunCondition? get runCondition => null;

  @override
  bool shouldRun(World world) => true;

  @override
  Future<void> run(World world) {
    world.getResource<ActionLog>()!.resolved.addAll(
      world.eventReader<NetActionResolved<Plant>>().read(),
    );
    return Future.value();
  }
}

ReplicationRegistry gardenRegistry() => buildRegistry()
  ..action<Plant>('plant', plantCodec)
  ..resource<Garden>('garden', gardenCodec, create: Garden.new);

NetTestbed gardenBed({
  Duration latency = Duration.zero,
  Duration jitter = Duration.zero,
  double packetLoss = 0,
  int seed = 1,
}) => NetTestbed(
  latency: latency,
  jitter: jitter,
  packetLoss: packetLoss,
  seed: seed,
  registry: gardenRegistry,
);

void addGarden(App app, {required bool host}) {
  app
    ..insertResource(ActionLog())
    ..addSystem(GardenSystem(), schedule: Schedules.fixedUpdate)
    ..addSystem(ResolvedRecorderSystem(), schedule: Schedules.last);
  if (host) app.insertResource(Garden());
}

Future<(App, App)> startGarden(NetTestbed bed) async {
  final host = await bed.startHost(vehicle: false);
  addGarden(host, host: true);
  final client = await bed.addClient();
  addGarden(client, host: false);
  return (host, client);
}

ActionLog logOf(App app) => app.world.getResource<ActionLog>()!;

void main() {
  setUp(ComponentId.resetRegistry);

  test(
    'actions arrive exactly once, in order, on their tick, under loss',
    () async {
      final bed = gardenBed(
        latency: const Duration(milliseconds: 40),
        jitter: const Duration(milliseconds: 20),
        packetLoss: 0.2,
        seed: 7,
      );
      final (host, client) = await startGarden(bed);
      final session = NetTestbed.session(client);
      final tickets = <NetActionTicket>[];
      for (var i = 0; i < 40; i++) {
        tickets.add(session.sendAction(Plant(i)));
        await bed.frames(2);
      }
      await bed.runUntil(
        () => logOf(client).resolved.length >= 40,
        maxFrames: 1000,
        what: 'every action resolved',
      );
      await bed.frames(50);

      final delivered = logOf(host).delivered;
      expect(delivered.map((d) => d.$1.seq), [for (var i = 1; i <= 40; i++) i]);
      expect(delivered.map((d) => d.$1.value.spot), [
        for (var i = 0; i < 40; i++) i,
      ]);
      final peer = session.localPeerId!;
      for (final (action, tick) in delivered) {
        expect(action.peerId, peer);
        // Held until the host reached the tick it was sent at (late only
        // if loss delayed it past that tick).
        expect(tick, greaterThanOrEqualTo(action.tick));
      }
      // Resent in every input packet, a lost packet costs a tick or two,
      // not a reliable resend.
      expect(
        delivered.where((d) => d.$2 == d.$1.tick).length,
        greaterThanOrEqualTo(30),
        reason: 'most actions land exactly on their tick',
      );
      expect(delivered.map((d) => d.$2 - d.$1.tick), everyElement(lessThan(5)));
      expect(
        [for (final t in tickets) t.seq],
        [for (var i = 1; i <= 40; i++) i],
      );
      final resolved = logOf(client).resolved;
      expect(resolved.map((r) => r.seq), [for (var i = 1; i <= 40; i++) i]);
      expect(resolved.every((r) => r.accepted), isTrue);
      expect(session.pendingActions<Plant>(), isEmpty);
      expect(client.world.getResource<Garden>()!.planted, hasLength(40));
      await bed.dispose();
    },
  );

  test('an action shows as pending until the host state has it', () async {
    final bed = gardenBed(
      latency: const Duration(milliseconds: 50),
      jitter: const Duration(milliseconds: 20),
      packetLoss: 0.1,
      seed: 11,
    );
    final (_, client) = await startGarden(bed);
    final session = NetTestbed.session(client);
    final sent = <int>[];
    var checks = 0;
    for (var frame = 0; frame < 300; frame++) {
      if (frame % 5 == 0 && sent.length < 30) {
        sent.add(sent.length);
        session.sendAction(Plant(sent.last));
      }
      await bed.frame();
      // Every spot sent is visible somewhere: in the replicated garden or
      // as a pending action. Never neither (no flicker).
      final garden = client.world.getResource<Garden>()?.planted ?? {};
      final pending = {
        for (final p in session.pendingActions<Plant>()) p.value.spot,
      };
      for (final spot in sent) {
        expect(
          garden.contains(spot) || pending.contains(spot),
          isTrue,
          reason: 'spot $spot vanished at frame $frame',
        );
        checks++;
      }
    }
    expect(checks, greaterThan(1000));
    expect(session.pendingActions<Plant>(), isEmpty);
    await bed.dispose();
  });

  test('a rejected action reports its reason and stops pending', () async {
    final bed = gardenBed(latency: const Duration(milliseconds: 20));
    final (host, client) = await startGarden(bed);
    host.world.getResource<Garden>()!
      ..planted.add(5)
      ..version += 1;
    final session = NetTestbed.session(client);
    final ticket = session.sendAction(const Plant(5));
    expect(session.pendingActions<Plant>().single.seq, ticket.seq);
    await bed.runUntil(
      () => logOf(client).resolved.isNotEmpty,
      what: 'resolution',
    );
    final r = logOf(client).resolved.single;
    expect(r.accepted, isFalse);
    expect(r.reason, 'taken');
    expect(r.value.spot, 5);
    expect(session.pendingActions<Plant>(), isEmpty);
    await bed.dispose();
  });

  test('an unresolved action counts as accepted', () async {
    final bed = gardenBed();
    final (_, client) = await startGarden(bed);
    NetTestbed.session(client).sendAction(const Plant(-1));
    await bed.runUntil(
      () => logOf(client).resolved.isNotEmpty,
      what: 'resolution',
    );
    expect(logOf(client).resolved.single.accepted, isTrue);
    expect(logOf(client).resolved.single.reason, isNull);
    await bed.dispose();
  });

  test('the host\'s own actions go through the same path', () async {
    final bed = gardenBed();
    final (host, _) = await startGarden(bed);
    final session = NetTestbed.session(host);
    final ticket = session.sendAction(const Plant(3));
    expect(session.pendingActions<Plant>(), hasLength(1));
    await bed.frames(3);
    final (action, _) = logOf(host).delivered.single;
    expect(action.peerId, 0);
    expect(action.seq, ticket.seq);
    expect(logOf(host).resolved.single.accepted, isTrue);
    expect(session.pendingActions<Plant>(), isEmpty);
    await bed.dispose();
  });

  test(
    'an action targeting an entity the sender does not own is rejected',
    () async {
      final bed = gardenBed();
      final (host, client) = await startGarden(bed);
      final other =
          (host.world.spawn()
                ..insert(Replicated())
                ..insert(const Health(1)))
              .entity;
      await bed.frames(10);
      final mirror = entityFor(client, netIdOf(host, other))!;
      NetTestbed.session(client).sendAction(const Plant(1), target: mirror);
      await bed.runUntil(
        () => logOf(client).resolved.isNotEmpty,
        what: 'resolution',
      );
      expect(logOf(client).resolved.single.accepted, isFalse);
      expect(logOf(host).delivered, isEmpty);
      expect(
        NetTestbed.log(host).rejected.single.kind,
        NetRejectionKind.action,
      );
      await bed.dispose();
    },
  );

  test(
    'lastSnapshotTick: how far the state from the host has reached',
    () async {
      final bed = gardenBed(latency: const Duration(milliseconds: 40));
      final (host, client) = await startGarden(bed);
      await bed.frames(20);
      final hostTick = NetTestbed.session(host).lastSnapshotTick;
      final seen = NetTestbed.session(client).lastSnapshotTick;
      expect(hostTick, host.world.getResource<NetworkTick>()!.serverTick);
      // Behind the host by about the latency, never ahead of it.
      expect(seen, greaterThan(0));
      expect(seen, lessThan(hostTick));
      expect(hostTick - seen, lessThan(10));
      await bed.dispose();
    },
  );

  test('a replayed or skipped sequence number is dropped', () async {
    final bed = gardenBed();
    final (host, client) = await startGarden(bed);
    final session = NetTestbed.session(client);
    session.sendAction(const Plant(1));
    await bed.frames(5);
    session.sendRawAction(const Plant(2), seq: 1); // replay
    session.sendRawAction(const Plant(3), seq: 7); // skip
    await bed.frames(10);
    expect(logOf(host).delivered.map((d) => d.$1.value.spot), [1]);
    // The replay is a copy (ignored); the gap is a forgery.
    expect(NetTestbed.session(host).stats.rejectedActions, 1);
    // The real sequence carries on.
    session.sendAction(const Plant(4));
    await bed.frames(10);
    expect(logOf(host).delivered.map((d) => d.$1.value.spot), [1, 4]);
    await bed.dispose();
  });
}
