// Ending a session: what `NetworkSession.close` leaves behind, at once,
// and what a later session on the same world starts from.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  test('a client that closes drops the replicated world at once, before '
      'its next frame', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 20));
    await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(20);
    expect(client.world.query1<Pos>().iter(), isNotEmpty);

    await NetTestbed.session(client).close('Left');
    // Nothing ticks between leaving and what the app does next (a menu,
    // loading its own game), so nothing may be left for a later frame.
    expect(client.world.query1<Pos>().iter(), isEmpty);
    expect(client.world.query1<NetworkIdentity>().iter(), isEmpty);
    expect(client.world.getResource<NetworkEntityRegistry>()!.count, 0);

    // The event still arrives, once, on the next frame.
    await client.tick();
    expect(NetTestbed.log(client).disconnected, hasLength(1));
    expect(NetTestbed.log(client).disconnected.single.reason, 'Left');
    await client.tick();
    expect(NetTestbed.log(client).disconnected, hasLength(1));
    await bed.dispose();
  });

  test('a host that closes: every peer leaves as if it had disconnected, '
      'and the session\'s ids and ownership end with it', () async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 20),
      config: () =>
          NetworkConfig(disconnectPolicy: OwnedEntityPolicy.holdForReturn),
    );
    final host = await bed.startHost();
    final a = await bed.addClient();
    final b = await bed.addClient();
    await bed.frames(20);
    final aId = NetTestbed.session(a).localPeerId!;
    final bId = NetTestbed.session(b).localPeerId!;
    final scene = host.world.getResource<HostScene>()!;
    final avatarA = scene.avatars[aId]!;
    final avatarANetId = netIdOf(host, avatarA);
    final vehicle = scene.vehicle!;

    await NetTestbed.session(host).close('Closed');
    // At once: no entity keeps a network id from the ended session, and
    // what a peer owned is the host's again (peer ids are per session).
    expect(host.world.query1<NetworkIdentity>().iter(), isEmpty);
    expect(host.world.getResource<NetworkEntityRegistry>()!.count, 0);
    expect(host.world.isAlive(avatarA), isTrue, reason: 'held, not despawned');
    expect(host.world.get<Replicated>(avatarA)!.owner, 0);
    expect(
      host.world.get<Replicated>(vehicle)!.alwaysRelevant,
      isTrue,
      reason: 'the marker is otherwise kept as it was',
    );

    // Each peer's departure is announced, as a disconnect's would be.
    await host.tick();
    final left = NetTestbed.log(host).peerDisconnected;
    expect(left.map((e) => e.peerId), unorderedEquals([aId, bId]));
    final fromA = left.firstWhere((e) => e.peerId == aId);
    expect(fromA.reason, 'Closed');
    expect(fromA.ownedNetIds, [avatarANetId]);
    expect(fromA.policy, OwnedEntityPolicy.holdForReturn);
    expect(NetTestbed.log(host).disconnected, hasLength(1));
    await bed.dispose();
  });

  test('a host that closes with the despawn policy despawns what its peers '
      'owned, as their disconnects would', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 20));
    final host = await bed.startHost();
    final a = await bed.addClient();
    await bed.frames(20);
    final avatar = host.world
        .getResource<HostScene>()!
        .avatars[NetTestbed.session(a).localPeerId!]!;

    await NetTestbed.session(host).close();
    expect(host.world.isAlive(avatar), isFalse);
    await bed.dispose();
  });

  test('hosting again: whoever gets a peer id from before owns nothing '
      'they didn\'t own in this session', () async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 20),
      config: () =>
          NetworkConfig(disconnectPolicy: OwnedEntityPolicy.holdForReturn),
    );
    final host = await bed.startHost();
    final first = await bed.addClient();
    await bed.frames(20);
    final firstId = NetTestbed.session(first).localPeerId!;
    final scene = host.world.getResource<HostScene>()!;
    final old = scene.avatars[firstId]!;

    await NetTestbed.session(host).close();
    bed.clients.remove(first);
    await NetTestbed.session(first).close();
    await bed.frames(5);
    await NetTestbed.session(host).host(port: 7777);
    final second = await bed.addClient();
    await bed.frames(20);
    final secondId = NetTestbed.session(second).localPeerId!;
    expect(secondId, firstId, reason: 'peer ids start again per session');

    // The old avatar replicates again, the host's; the newcomer owns only
    // the avatar spawned for them.
    expect(host.world.get<NetworkIdentity>(old)!.ownerId, 0);
    final mine = scene.avatars[secondId]!;
    expect(mine, isNot(old));
    expect(host.world.get<NetworkIdentity>(mine)!.ownerId, secondId);
    final owned = [
      for (final (_, id) in second.world.query1<NetworkIdentity>().iter())
        if (id.ownerId == secondId) id.netId,
    ];
    expect(owned, [netIdOf(host, mine)]);
    await bed.dispose();
  });

  test('the same player reconnecting in one frame: their old connection '
      'leaves first, so the new one gets back what it held', () async {
    final bed = NetTestbed(
      config: () =>
          NetworkConfig(disconnectPolicy: OwnedEntityPolicy.holdForReturn),
    );
    final host = await bed.startHost();
    final before = await bed.addClient(identity: DevIdentityProvider('ann'));
    await bed.frames(10);
    final beforeId = NetTestbed.session(before).localPeerId!;
    final scene = host.world.getResource<HostScene>()!;
    final avatar = scene.avatars[beforeId]!;
    final avatarNetId = netIdOf(host, avatar);
    final log = NetTestbed.log(host);

    // A second copy of them connects (a crash and a restart, a new
    // address): it replaces the first connection.
    bed.clients.remove(before);
    final after = await bed.addClient(identity: DevIdentityProvider('ann'));
    await bed.frames(5);
    final afterId = NetTestbed.session(after).localPeerId!;
    expect(log.peerDisconnected.map((e) => e.peerId), [beforeId]);
    final back = log.peerConnected.where((e) => e.peerId == afterId).single;
    expect(back.returned, [avatarNetId]);
    expect(host.world.get<NetworkIdentity>(avatar)!.ownerId, afterId);
    await NetTestbed.session(before).close();
    await bed.dispose();
  });
}
