// Peer departure handling (OwnedEntityPolicy) and session teardown.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  for (final policy in OwnedEntityPolicy.values) {
    test('leaving peer: host event + owned entities ${policy.name}', () async {
      final bed = NetTestbed(
        latency: const Duration(milliseconds: 30),
        packetLoss: 0.05,
        seed: 4,
        config: () => NetworkConfig(disconnectPolicy: policy),
      );
      final host = await bed.startHost();
      final leaver = await bed.addClient();
      final stayer = await bed.addClient();
      await bed.frames(30);

      final scene = host.world.getResource<HostScene>()!;
      final leaverId = NetTestbed.session(leaver).localPeerId!;
      final avatar = scene.avatars[leaverId]!;
      final avatarNetId = netIdOf(host, avatar);
      expect(entityFor(stayer, avatarNetId), isNotNull);

      await NetTestbed.session(leaver).close();
      await bed.frames(40);

      final events = NetTestbed.log(host).peerDisconnected;
      expect(events, hasLength(1));
      expect(events.single.peerId, leaverId);
      expect(events.single.ownedNetIds, [avatarNetId]);
      expect(events.single.policy, policy);
      expect(NetTestbed.session(host).peerIds, isNot(contains(leaverId)));

      switch (policy) {
        case OwnedEntityPolicy.despawn:
          expect(host.world.isAlive(avatar), isFalse);
          expect(entityFor(stayer, avatarNetId), isNull);
          expect(
            NetTestbed.log(stayer).despawned.map((e) => e.netId),
            contains(avatarNetId),
          );
        case OwnedEntityPolicy.releaseToHost:
          expect(host.world.get<NetworkIdentity>(avatar)!.ownerId, 0);
          final mirror = entityFor(stayer, avatarNetId)!;
          expect(stayer.world.get<NetworkIdentity>(mirror)!.ownerId, 0);
      }
      // The leaver tore down its replicated world locally.
      expect(NetTestbed.log(leaver).disconnected, hasLength(1));
      expect(leaver.world.getResource<NetworkEntityRegistry>()!.count, 0);
      await bed.dispose();
    });
  }

  // The leaving client's disconnect notice is sent redundantly, so a lost
  // copy does not leave its entities lingering until connectionTimeout.
  // Seeds are chosen so the first copy is lost on the 50% lossy link.
  for (final seed in [2, 5]) {
    test('leaving peer on a 50% lossy link is noticed within a few frames '
        '(seed $seed)', () async {
      final bed = NetTestbed(
        latency: const Duration(milliseconds: 20),
        seed: seed,
      );
      final host = await bed.startHost();
      final leaver = await bed.addClient();
      await bed.frames(20);
      final leaverId = NetTestbed.session(leaver).localPeerId!;
      final avatar = host.world.getResource<HostScene>()!.avatars[leaverId]!;

      // Observe (not drop) every disconnect copy; the network drops half
      // of all datagrams after the filter, so the change in stats.dropped
      // between copies tells which ones were lost.
      bed.net.packetLoss = 0.5;
      final droppedBefore = <int>[];
      var otherSent = 0;
      bed.net.filter = (d) {
        if (d.data.length > 5 && d.data[5] == PacketType.disconnect.value) {
          droppedBefore.add(bed.net.stats.dropped);
        } else {
          otherSent++;
        }
        return true;
      };
      await NetTestbed.session(leaver).close();
      final droppedAfter = bed.net.stats.dropped;
      bed.net.filter = null;

      expect(otherSent, 0, reason: 'only disconnect copies sent on close');
      final lost = [
        for (var i = 0; i < droppedBefore.length; i++)
          (i + 1 < droppedBefore.length ? droppedBefore[i + 1] : droppedAfter) >
              droppedBefore[i],
      ];
      expect(lost, hasLength(greaterThan(1)));
      expect(lost.first, isTrue, reason: 'seed loses the first copy');
      expect(lost, contains(false), reason: 'at least one copy arrives');

      // One-way latency is one frame; allow a couple more for the event
      // to pass through the session inbox.
      final log = NetTestbed.log(host);
      for (var i = 0; i < 3 && log.peerDisconnected.isEmpty; i++) {
        await bed.frame();
      }
      expect(log.peerDisconnected, hasLength(1));
      expect(log.peerDisconnected.single.peerId, leaverId);
      await bed.frames(5);
      expect(log.peerDisconnected, hasLength(1), reason: 'duplicates ignored');
      expect(host.world.isAlive(avatar), isFalse);
      await bed.dispose();
    });
  }

  test('host shutdown: clients get NetDisconnected and drop replicated '
      'entities', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 20));
    final host = await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(20);
    expect(
      client.world.getResource<NetworkEntityRegistry>()!.count,
      greaterThan(0),
    );

    await NetTestbed.session(host).close();
    await bed.frames(20);

    final session = NetTestbed.session(client);
    expect(session.isActive, isFalse);
    expect(NetTestbed.log(client).disconnected, hasLength(1));
    expect(
      NetTestbed.log(client).disconnected.single.reason,
      'Host shutting down',
    );
    expect(client.world.getResource<NetworkEntityRegistry>()!.count, 0);
    expect(client.world.query1<Pos>().iter(), isEmpty);
    await bed.dispose();
  });
}
