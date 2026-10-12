// package:fledge_net/testing.dart lets a test act like a modified client;
// the host must reject forged inputs and RPCs for entities the sender
// does not own.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net/src/replication/wire.dart';
import 'package:fledge_net/testing.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  Future<(NetTestbed, App, App, App)> twoClients() async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 30),
      packetLoss: 0.05,
      seed: 7,
    );
    final host = await bed.startHost();
    final a = await bed.addClient();
    final b = await bed.addClient();
    await bed.frames(30);
    return (bed, host, a, b);
  }

  test('encodeRawInputPacket matches the session wire format', () {
    final one = encodeWithCodec(moveCodec, const Move(1, -1));
    final payload = encodeRawInputPacket(
      clientTick: 42,
      reliableAck: 3,
      lastSnapshotTick: 40,
      streams: [
        RawInputStream(netId: 7, firstTick: 41, inputs: [one, one]),
      ],
    );
    final decoded = InputPacket.decode(payload);
    expect(decoded.clientTick, 42);
    expect(decoded.reliableAck, 3);
    expect(decoded.lastSnapshotTick, 40);
    expect(decoded.streams.single.netId, 7);
    expect(decoded.streams.single.firstTick, 41);
    expect(decoded.streams.single.inputs, [one, one]);
    final move = moveCodec.decode(PacketReader(one));
    expect((move.dx, move.dy), (1.0, -1.0));
  });

  test('forged input for another peer avatar is rejected', () async {
    final (bed, host, attacker, victim) = await twoClients();
    final scene = host.world.getResource<HostScene>()!;
    final attackerId = NetTestbed.session(attacker).localPeerId!;
    final victimAvatar = scene.avatars[NetTestbed.session(victim).localPeerId]!;
    final victimNetId = netIdOf(host, victimAvatar);
    final before = host.world.get<Pos>(victimAvatar)!;

    final push = encodeWithCodec(moveCodec, const Move(1, 1));
    final hostTick = host.world.getResource<NetworkTick>()!.serverTick;
    for (var i = 0; i < 20; i++) {
      await NetTestbed.session(attacker).sendRawInput(
        netId: victimNetId,
        firstTick: hostTick + i,
        inputs: List.filled(10, push),
      );
      await bed.frame();
    }
    await bed.frames(30);

    final after = host.world.get<Pos>(victimAvatar)!;
    expect((after.x, after.y), (before.x, before.y));
    expect(NetTestbed.session(host).stats.rejectedInputs, greaterThan(0));
    final rejected = NetTestbed.log(host).rejected;
    expect(rejected, isNotEmpty);
    expect(rejected.every((r) => r.peerId == attackerId), isTrue);
    expect(rejected.every((r) => r.kind == NetRejectionKind.input), isTrue);
    expect(rejected.every((r) => r.netId == victimNetId), isTrue);
    await bed.dispose();
  });

  test('raw RPC naming another peer avatar is rejected, own avatar '
      'accepted', () async {
    final (bed, host, attacker, victim) = await twoClients();
    final scene = host.world.getResource<HostScene>()!;
    final attackerId = NetTestbed.session(attacker).localPeerId!;
    final ownNetId = netIdOf(host, scene.avatars[attackerId]!);
    final victimNetId = netIdOf(
      host,
      scene.avatars[NetTestbed.session(victim).localPeerId]!,
    );

    NetTestbed.session(
      attacker,
    ).sendRawRpc(const Emote('steal'), targetNetId: victimNetId);
    NetTestbed.session(
      attacker,
    ).sendRawRpc(const Emote('mine'), targetNetId: ownNetId);
    await bed.frames(40);

    expect(NetTestbed.log(host).emotes.map((e) => e.value.name), ['mine']);
    final rejected = NetTestbed.log(host).rejected;
    expect(rejected, hasLength(1));
    expect(rejected.single.kind, NetRejectionKind.rpc);
    expect(rejected.single.peerId, attackerId);
    expect(rejected.single.netId, victimNetId);
    expect(NetTestbed.session(host).stats.rejectedRpcs, 1);
    await bed.dispose();
  });

  test('raw helpers require a joined client', () async {
    final bed = NetTestbed();
    final host = await bed.startHost();
    expect(
      () => NetTestbed.session(
        host,
      ).sendRawInput(netId: 1, firstTick: 0, inputs: const []),
      throwsStateError,
    );
    expect(
      () =>
          NetTestbed.session(host).sendRawRpc(const Emote('x'), targetNetId: 1),
      throwsStateError,
    );
    await bed.dispose();
  });
}
