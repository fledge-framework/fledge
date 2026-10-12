// Inputs flow client -> host, are applied by the host, and are rejected
// when they target an entity the sender does not own (authority check).
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net/src/replication/wire.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  Future<(NetTestbed, App, App, App)> twoClients() async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 40),
      jitter: const Duration(milliseconds: 20),
      packetLoss: 0.05,
      seed: 3,
    );
    final host = await bed.startHost();
    final a = await bed.addClient();
    final b = await bed.addClient();
    await bed.frames(30);
    return (bed, host, a, b);
  }

  test('host applies each client input to that client avatar only', () async {
    final (bed, host, a, b) = await twoClients();
    final scene = host.world.getResource<HostScene>()!;
    final aId = NetTestbed.session(a).localPeerId!;
    final bId = NetTestbed.session(b).localPeerId!;
    final aStart = host.world.get<Pos>(scene.avatars[aId]!)!;
    final bStart = host.world.get<Pos>(scene.avatars[bId]!)!;

    a.world.getResource<Driving>()!.move = const Move(1, 0);
    await bed.frames(100);
    a.world.getResource<Driving>()!.move = null;
    await bed.frames(60);

    final aEnd = host.world.get<Pos>(scene.avatars[aId]!)!;
    final bEnd = host.world.get<Pos>(scene.avatars[bId]!)!;
    // ~100 ticks at 50 Hz = 2 s at 50 u/s, plus up to 8 repeated ticks
    // after release and a few ticks of time dilation while the lead
    // settles.
    expect(aEnd.x - aStart.x, inInclusiveRange(95, 130));
    expect(aEnd.y, aStart.y);
    expect(bEnd.x, bStart.x);
    expect(bEnd.y, bStart.y);
    expect(NetTestbed.session(host).stats.rejectedInputs, 0);
    await bed.dispose();
  });

  test('input for another peer avatar is rejected and has no effect', () async {
    final (bed, host, attacker, victim) = await twoClients();
    final scene = host.world.getResource<HostScene>()!;
    final attackerId = NetTestbed.session(attacker).localPeerId!;
    final victimId = NetTestbed.session(victim).localPeerId!;
    final victimHost = scene.avatars[victimId]!;
    final victimNetId = netIdOf(host, victimHost);
    final before = host.world.get<Pos>(victimHost)!;

    // A modified client forges an input stream for the victim avatar,
    // covering the ticks around the current host tick.
    final hostTick = host.world.getResource<NetworkTick>()!.serverTick;
    final input =
        (PacketBuilder()
              ..writeFloat32(1)
              ..writeFloat32(1))
            .build();
    for (var i = 0; i < 20; i++) {
      final forged = InputPacket(
        clientTick: hostTick + i,
        reliableAck: 0,
        lastSnapshotTick: 0,
        streams: [
          InputStream(victimNetId, hostTick + i, List.filled(10, input)),
        ],
      ).encode();
      await NetTestbed.session(
        attacker,
      ).networkClient!.send(PacketType.input, forged);
      await bed.frame();
    }
    await bed.frames(30);

    final after = host.world.get<Pos>(victimHost)!;
    expect(after.x, before.x, reason: 'forged input must have no effect');
    expect(after.y, before.y);

    final hostSession = NetTestbed.session(host);
    expect(hostSession.stats.rejectedInputs, greaterThan(0));
    final rejected = NetTestbed.log(host).rejected;
    expect(rejected, isNotEmpty);
    expect(rejected.every((r) => r.peerId == attackerId), isTrue);
    expect(rejected.first.kind, NetRejectionKind.input);
    expect(rejected.first.netId, victimNetId);
    // The event carries only ids and a fixed reason: no payload, no secrets.
    expect(rejected.first.reason, 'input for an entity the peer does not own');
    await bed.dispose();
  });

  test('RPCs: owned target delivered, foreign target rejected, host->client '
      'broadcast delivered', () async {
    final (bed, host, a, b) = await twoClients();
    final scene = host.world.getResource<HostScene>()!;
    final aId = NetTestbed.session(a).localPeerId!;
    final bId = NetTestbed.session(b).localPeerId!;
    final aAvatarOnA = entityFor(a, netIdOf(host, scene.avatars[aId]!))!;
    final bAvatarOnA = entityFor(a, netIdOf(host, scene.avatars[bId]!))!;

    NetTestbed.session(a).sendRpc(const Emote('wave'), target: aAvatarOnA);
    NetTestbed.session(a).sendRpc(const Emote('steal'), target: bAvatarOnA);
    NetTestbed.session(a).sendRpc(const Emote('hello'));
    NetTestbed.session(host).sendRpc(const Emote('welcome-all'));
    NetTestbed.session(host).sendRpcTo(bId, const Emote('just-b'));
    await bed.frames(60);

    final hostEmotes = NetTestbed.log(host).emotes;
    expect(hostEmotes.map((e) => e.value.name), ['wave', 'hello']);
    expect(hostEmotes.first.sender, aId);
    expect(hostEmotes.first.target, scene.avatars[aId]);
    expect(hostEmotes.last.target, isNull);

    final rejected = NetTestbed.log(host).rejected;
    expect(rejected, hasLength(1));
    expect(rejected.single.kind, NetRejectionKind.rpc);
    expect(rejected.single.peerId, aId);
    expect(NetTestbed.session(host).stats.rejectedRpcs, 1);

    expect(NetTestbed.log(a).emotes.map((e) => e.value.name), ['welcome-all']);
    expect(NetTestbed.log(b).emotes.map((e) => e.value.name), [
      'welcome-all',
      'just-b',
    ]);
    expect(NetTestbed.log(b).emotes.first.sender, 0);
    await bed.dispose();
  });
}
