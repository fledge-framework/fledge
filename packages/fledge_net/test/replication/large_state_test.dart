// Entity state too large for one snapshot datagram still replicates: a
// spawn goes in fragments on the reliable channel, a large delta as a
// reliable `state` message, in tick order with the snapshots around it.
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// A component of adjustable size whose bytes all carry its revision, so
/// a client can tell which copy it has and that it arrived whole.
class Ledger {
  final int rev;
  final int size;

  const Ledger(this.rev, this.size);
}

final ledgerCodec = NetCodec<Ledger>.of(
  encode: (l, out) => out
    ..writeVarUint(l.rev)
    ..writeVarBytes(Uint8List(l.size)..fillRange(0, l.size, l.rev & 0xff)),
  decode: (r) {
    final rev = r.readVarUint();
    final bytes = r.readVarBytes();
    if (bytes.any((b) => b != rev & 0xff)) {
      throw const FormatException('a ledger arrived mixed up');
    }
    return Ledger(rev, bytes.length);
  },
);

/// Larger than any snapshot may carry.
const int big = NetworkSession.maxSnapshotEntityBytes * 3;

ReplicationRegistry Function() _registry({required bool ownerOnly}) =>
    () =>
        buildRegistry(predict: false)
          ..component<Ledger>('ledger', ledgerCodec, ownerOnly: ownerOnly);

void main() {
  setUp(ComponentId.resetRegistry);

  test('a large private component reaches its owner, and its changes keep '
      'arriving in order; everyone else gets the shared state', () async {
    final bed = NetTestbed(registry: _registry(ownerOnly: true));
    final host = await bed.startHost();
    final a = await bed.addClient();
    final aId = NetTestbed.session(a).localPeerId!;
    final stats = NetTestbed.session(host).stats;

    // Spawned large: the spawn itself goes in fragments.
    final pack = host.world.spawn()
      ..insert(Replicated(owner: aId))
      ..insert(const Pos(3, 3))
      ..insert(const Ledger(1, big));
    await bed.frame(); // registers it
    final packId = netIdOf(host, pack.entity);
    Ledger? ledgerOn(App app) {
      final e = entityFor(app, packId);
      return e == null ? null : app.world.get<Ledger>(e);
    }

    await bed.runUntil(
      () => ledgerOn(a)?.rev == 1,
      what: 'the owner gets the large spawn',
    );
    expect(ledgerOn(a)!.size, big);
    expect(
      a.world.get<NetworkIdentity>(entityFor(a, packId)!)!.ownerId,
      aId,
      reason: 'theirs: owned on their machine',
    );

    // Someone else joins: the entity's shared state, never the ledger.
    final b = await bed.addClient();
    await bed.runUntil(() => entityFor(b, packId) != null, what: 'b sees it');
    expect(b.world.has<Ledger>(entityFor(b, packId)!), isFalse);

    // The ledger changes, growing, while the entity moves: every copy the
    // owner sees is newer than the one before, and the last one arrives.
    var seen = 1;
    for (var rev = 2; rev <= 12; rev++) {
      host.world
        ..insert(pack.entity, Ledger(rev, big + rev * 100))
        ..insert(pack.entity, Pos(3.0 + rev, 3));
      for (var i = 0; i < 4; i++) {
        await bed.frame();
        final now = ledgerOn(a)!.rev;
        expect(now, greaterThanOrEqualTo(seen), reason: 'never rolls back');
        seen = now;
      }
    }
    await bed.runUntil(() => ledgerOn(a)?.rev == 12, what: 'the last copy');
    expect(ledgerOn(a)!.size, big + 1200);
    // Pos is interpolated, so it shows a little behind.
    double xOn(App app) => app.world.get<Pos>(entityFor(app, packId)!)!.x;
    await bed.runUntil(
      () => (xOn(a) - 15).abs() < 1e-6 && (xOn(b) - 15).abs() < 1e-6,
      what: 'the moves arrive too',
    );
    expect(stats.reliableEntityUpdates, greaterThan(0));
    expect(stats.oversizedEntities, 0);

    // While only small things change, it travels in snapshots again.
    await bed.frames(20);
    final reliable = stats.reliableEntityUpdates;
    final chunks = stats.snapshotChunksSent;
    for (var i = 1; i <= 30; i++) {
      host.world.insert(pack.entity, Pos(20.0 + i, 3));
      await bed.frame();
    }
    await bed.runUntil(
      () => (xOn(a) - 50).abs() < 1e-6,
      what: 'the moves arrive',
    );
    expect(stats.reliableEntityUpdates, reliable);
    expect(stats.snapshotChunksSent, greaterThan(chunks));

    await bed.dispose();
  });

  test('a large update held up on the wire is not overtaken by the '
      "entity's later snapshots", () async {
    final bed = NetTestbed(
      registry: _registry(ownerOnly: false),
      latency: const Duration(milliseconds: 20),
    );
    final host = await bed.startHost(vehicle: false);
    final client = await bed.addClient();
    final thing = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Health(0))
      ..insert(const Ledger(1, 16));
    await bed.frame(); // registers it
    final id = netIdOf(host, thing.entity);
    await bed.runUntil(() => entityFor(client, id) != null);
    await bed.frames(10);

    // The large change's reliable packets are lost for a while; snapshots
    // (and the small changes they would carry) get through.
    var holding = true;
    bed.net.filter = (d) =>
        !holding ||
        d.source.port != 7777 ||
        d.data[5] != PacketType.replication.value;
    host.world.insert(thing.entity, const Ledger(2, big));
    for (var hp = 1; hp <= 15; hp++) {
      host.world.insert(thing.entity, Health(hp));
      await bed.frame();
    }
    holding = false;
    final mirror = entityFor(client, id)!;
    expect(
      client.world.get<Health>(mirror)!.hp,
      0,
      reason: 'the small changes wait behind the large one',
    );
    await bed.runUntil(
      () =>
          client.world.get<Ledger>(mirror)!.rev == 2 &&
          client.world.get<Health>(mirror)!.hp == 15,
      what: 'the large update, then the rest',
    );
    expect(client.world.get<Ledger>(mirror)!.size, big);
    await bed.dispose();
  });

  test('small entities use snapshots only', () async {
    final bed = NetTestbed(registry: _registry(ownerOnly: false));
    final host = await bed.startHost();
    final client = await bed.addClient();
    final stats = NetTestbed.session(host).stats;
    final scene = host.world.getResource<HostScene>()!..vehicleVx = 10;
    final crate = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(1, 1))
      ..insert(const Ledger(1, 200));
    for (var i = 2; i <= 40; i++) {
      host.world
        ..insert(crate.entity, Ledger(i, 200))
        ..insert(scene.vehicle!, Health(i));
      await bed.frame();
    }
    await bed.frames(10);
    final mirror = entityFor(client, netIdOf(host, crate.entity))!;
    expect(client.world.get<Ledger>(mirror)!.rev, 40);
    expect(stats.snapshotChunksSent, greaterThan(0));
    expect(stats.reliableEntityUpdates, 0);
    await bed.dispose();
  });

  for (final seed in [1, 2, 3, 4]) {
    test(
      'under loss and jitter, large and small changes interleave in tick '
      'order: no snapshot rolls back or drops a reliable update (seed $seed)',
      () async {
        final bed = NetTestbed(
          registry: _registry(ownerOnly: false),
          latency: const Duration(milliseconds: 40),
          jitter: const Duration(milliseconds: 30),
          packetLoss: 0.15,
          seed: seed,
        );
        final host = await bed.startHost(vehicle: false);
        final client = await bed.addClient();
        final stats = NetTestbed.session(host).stats;
        final thing = host.world.spawn()
          ..insert(Replicated())
          ..insert(const Pos(0, 0))
          ..insert(const Health(0))
          ..insert(const Ledger(0, big));
        await bed.frame(); // registers it
        final id = netIdOf(host, thing.entity);
        await bed.runUntil(() => entityFor(client, id) != null);

        var hp = 0;
        var seenHp = 0;
        var seenRev = 0;
        // Health changes every frame (small, so in snapshots when it can).
        // The ledger changes between large and small, so the entity goes
        // back and forth between reliable updates and snapshots. Each
        // ledger copy must arrive while the small changes keep flowing (a
        // large update overtaken by a snapshot would be dropped as stale
        // and never arrive), and nothing on the client ever rolls back.
        Future<void> step() async {
          host.world.insert(thing.entity, Health(++hp));
          await bed.frame();
          final mirror = entityFor(client, id)!;
          final h = client.world.get<Health>(mirror)!.hp;
          final l = client.world.get<Ledger>(mirror)!;
          expect(h, greaterThanOrEqualTo(seenHp), reason: 'health rolled back');
          expect(
            l.rev,
            greaterThanOrEqualTo(seenRev),
            reason: 'ledger rolled back',
          );
          expect(l.size, l.rev.isEven ? big : 16, reason: 'a whole copy');
          seenHp = h;
          seenRev = l.rev;
        }

        for (var rev = 1; rev <= 12; rev++) {
          host.world.insert(thing.entity, Ledger(rev, rev.isEven ? big : 16));
          for (var waited = 0; seenRev < rev; waited++) {
            if (waited > 400) fail('ledger $rev never arrived');
            await step();
          }
          for (var i = 0; i < 3; i++) {
            await step();
          }
        }
        await bed.runUntil(() {
          final mirror = entityFor(client, id)!;
          return client.world.get<Health>(mirror)!.hp == hp;
        }, what: 'the newest state');
        expect(stats.reliableEntityUpdates, greaterThan(0));
        await bed.dispose();
      },
    );
  }

  test('a returning player gets their large private state back, and its '
      'changes keep arriving', () async {
    final bed = NetTestbed(
      registry: _registry(ownerOnly: true),
      config: () =>
          NetworkConfig(disconnectPolicy: OwnedEntityPolicy.holdForReturn),
    );
    final host = await bed.startHost();
    final scene = host.world.getResource<HostScene>()!..spawnAvatars = false;
    final first = await bed.addClient(identity: DevIdentityProvider('ann'));
    final firstId = NetTestbed.session(first).localPeerId!;
    final pack = host.world.spawn()
      ..insert(Replicated(owner: firstId))
      ..insert(const Pos(1, 1))
      ..insert(const Ledger(7, big));
    await bed.frame(); // registers it
    final packId = netIdOf(host, pack.entity);
    await bed.runUntil(() {
      final e = entityFor(first, packId);
      return e != null && first.world.get<Ledger>(e)?.rev == 7;
    }, what: 'the first visit gets it');

    await NetTestbed.session(first).close();
    await bed.frames(20);
    expect(host.world.get<NetworkIdentity>(pack.entity)!.ownerId, 0);
    // Changed while they're away.
    host.world.insert(pack.entity, const Ledger(8, big + 500));
    await bed.frames(10);

    expect(scene.avatars, isEmpty);
    final again = await bed.addClient(identity: DevIdentityProvider('ann'));
    final againId = NetTestbed.session(again).localPeerId!;
    Ledger? ledger() {
      final e = entityFor(again, packId);
      return e == null ? null : again.world.get<Ledger>(e);
    }

    await bed.runUntil(() => ledger()?.rev == 8, what: 'theirs again');
    expect(ledger()!.size, big + 500);
    expect(
      again.world.get<NetworkIdentity>(entityFor(again, packId)!)!.ownerId,
      againId,
    );
    host.world.insert(pack.entity, const Ledger(9, big * 2));
    await bed.runUntil(() => ledger()?.rev == 9, what: 'and it keeps coming');
    expect(ledger()!.size, big * 2);
    await bed.dispose();
  });

  test('an entity over the hard cap is held back without delaying a large '
      'one under it', () async {
    final bed = NetTestbed(registry: _registry(ownerOnly: false));
    final host = await bed.startHost();
    final client = await bed.addClient();
    final stats = NetTestbed.session(host).stats;
    final huge = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Ledger(1, NetworkSession.maxEntityStateBytes + 1));
    final large = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Ledger(1, big));
    await bed.frame(); // registers it
    final hugeId = netIdOf(host, huge.entity);
    final largeId = netIdOf(host, large.entity);
    await bed.runUntil(
      () => entityFor(client, largeId) != null,
      what: 'the large one arrives',
    );
    host.world.insert(large.entity, const Ledger(2, big + 1));
    await bed.runUntil(
      () => client.world.get<Ledger>(entityFor(client, largeId)!)?.rev == 2,
      what: 'and updates',
    );
    expect(entityFor(client, hugeId), isNull);
    expect(stats.oversizedEntities, 1);
    await bed.dispose();
  });
}
