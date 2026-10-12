// Interest management (spawn on enter, despawn on exit) and snapshot
// chunking across packets.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  test('interest radius: far entity not spawned; entering spawns, '
      'leaving despawns', () async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 30),
      jitter: const Duration(milliseconds: 20),
      packetLoss: 0.05,
      seed: 21,
      config: () => NetworkConfig(interestRadius: 50),
    );
    final host = await bed.startHost();
    final client = await bed.addClient();

    // Root entities: one far away, one parent far away with a child that
    // is near the client avatar (ancestors of relevant entities are sent).
    final far = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(500, 0))
      ..insert(const Health(1));
    final farParent = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(-400, 0));
    final nearChild = host.world.spawn()
      ..insert(Replicated())
      ..insert(const Pos(405, 3)); // global (5, 3)
    host.world.setParent(nearChild.entity, farParent.entity);
    await bed.frames(40);

    final farId = netIdOf(host, far.entity);
    expect(entityFor(client, farId), isNull, reason: 'outside radius');
    // Vehicle is always relevant, own avatar is owned.
    final scene = host.world.getResource<HostScene>()!;
    expect(entityFor(client, netIdOf(host, scene.vehicle!)), isNotNull);
    final childOnClient = entityFor(client, netIdOf(host, nearChild.entity));
    final parentOnClient = entityFor(client, netIdOf(host, farParent.entity));
    expect(childOnClient, isNotNull);
    expect(parentOnClient, isNotNull, reason: 'ancestor of a relevant entity');
    expect(client.world.getParent(childOnClient!), parentOnClient);

    // Move the far entity into range.
    host.world.insert(far.entity, const Pos(10, 0));
    await bed.frames(30);
    final spawned = entityFor(client, farId);
    expect(spawned, isNotNull);
    expect(client.world.get<Pos>(spawned!)!.x, closeTo(10, 1e-6));
    expect(client.world.get<Health>(spawned)!.hp, 1);
    expect(NetTestbed.log(client).spawned.map((e) => e.netId), contains(farId));

    // And out again.
    host.world.insert(far.entity, const Pos(300, 0));
    await bed.frames(30);
    expect(entityFor(client, farId), isNull);
    expect(client.world.isAlive(spawned), isFalse);
    expect(
      NetTestbed.log(client).despawned.map((e) => e.netId),
      contains(farId),
    );
    await bed.dispose();
  });

  test(
    'snapshots larger than one packet are chunked and arrive intact',
    () async {
      final bed = NetTestbed(
        latency: const Duration(milliseconds: 30),
        jitter: const Duration(milliseconds: 30),
        packetLoss: 0.05,
        seed: 99,
      );
      final host = await bed.startHost();
      final client = await bed.addClient();

      const count = 400;
      final entities = [
        for (var i = 0; i < count; i++)
          (host.world.spawn()
                ..insert(Replicated())
                ..insert(Pos(i.toDouble(), i * 0.5))
                ..insert(Health(i)))
              .entity,
      ];
      await bed.frames(60);
      // Change every entity so the next snapshots carry new values.
      for (var i = 0; i < count; i++) {
        host.world.insert(entities[i], Pos(-i.toDouble(), i * 0.25));
        host.world.insert(entities[i], Health(i + 1000));
      }
      final hostSession = NetTestbed.session(host);
      final before = hostSession.stats.snapshotChunksSent;
      final interval = host.world.getResource<NetworkConfig>()!.syncInterval;
      await bed.frames(interval * 20);
      final perSnapshot = (hostSession.stats.snapshotChunksSent - before) / 20;
      expect(perSnapshot, greaterThanOrEqualTo(4), reason: 'multi-chunk');

      for (var i = 0; i < count; i++) {
        final mirror = entityFor(client, netIdOf(host, entities[i]));
        expect(mirror, isNotNull, reason: 'entity $i');
        final p = client.world.get<Pos>(mirror!)!;
        expect(p.x, -i.toDouble());
        expect(p.y, i * 0.25);
        expect(client.world.get<Health>(mirror)!.hp, i + 1000);
      }
      await bed.dispose();
    },
  );
}
