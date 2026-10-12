// Client prediction + reconciliation for the locally owned avatar.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  Future<(NetTestbed, App, App, Entity, Entity)> setup({
    double blend = 1,
    double jitterMs = 0,
    double loss = 0,
  }) async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 100),
      jitter: Duration(milliseconds: jitterMs.round()),
      packetLoss: loss,
      seed: 5,
      registry: () => buildRegistry(blend: blend),
    );
    final host = await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(30);
    final peerId = NetTestbed.session(client).localPeerId!;
    final hostAvatar = host.world.getResource<HostScene>()!.avatars[peerId]!;
    final clientAvatar = entityFor(client, netIdOf(host, hostAvatar))!;
    return (bed, host, client, hostAvatar, clientAvatar);
  }

  test('owned avatar responds immediately under 100 ms latency', () async {
    final (bed, host, client, hostAvatar, clientAvatar) = await setup();
    final clientBefore = client.world.get<Pos>(clientAvatar)!;
    final hostBefore = host.world.get<Pos>(hostAvatar)!;

    client.world.getResource<Driving>()!.move = const Move(1, 0);
    await bed.frame();

    final clientAfter = client.world.get<Pos>(clientAvatar)!;
    // One 20 ms tick at 50 u/s = 1 unit, applied locally right away.
    expect(clientAfter.x - clientBefore.x, closeTo(1, 1e-9));
    // The host has not even received the input yet.
    expect(host.world.get<Pos>(hostAvatar)!.x, hostBefore.x);
    await bed.dispose();
  });

  test('deterministic step: no corrections, client and host agree', () async {
    final (bed, host, client, hostAvatar, clientAvatar) = await setup();
    final driving = client.world.getResource<Driving>()!;
    driving.move = const Move(1, 0.5);
    await bed.frames(80);
    driving.move = const Move(-0.25, 1);
    await bed.frames(80);
    driving.move = null;
    await bed.frames(40);

    expect(NetTestbed.session(client).stats.corrections, 0);
    expect(NetTestbed.log(client).corrected, isEmpty);
    final hp = host.world.get<Pos>(hostAvatar)!;
    final cp = client.world.get<Pos>(clientAvatar)!;
    expect(posError(hp, cp), lessThan(1e-3));
    expect(hp.x, greaterThan(50));
    await bed.dispose();
  });

  for (final blend in [1.0, 0.5]) {
    test('injected server correction reconciles and converges '
        '(correctionBlend $blend)', () async {
      final (bed, host, client, hostAvatar, clientAvatar) = await setup(
        blend: blend,
      );
      final driving = client.world.getResource<Driving>()!;
      driving.move = const Move(1, 0);
      await bed.frames(40);

      // Authoritative intervention the client cannot predict: the host
      // teleports the avatar 5 units up.
      final p = host.world.get<Pos>(hostAvatar)!;
      host.world.insert(hostAvatar, Pos(p.x, p.y + 5));
      await bed.frames(60);

      final corrections = NetTestbed.log(client).corrected;
      expect(corrections, isNotEmpty);
      expect(corrections.first.entity, clientAvatar);
      expect(corrections.first.error, greaterThan(4));
      if (blend == 1) {
        // A full snap rewrites the history: exactly one correction, and
        // the predicted y already includes the teleport (the client leads
        // the host while driving, so compare y only).
        expect(corrections, hasLength(1));
        expect(
          client.world.get<Pos>(clientAvatar)!.y,
          closeTo(host.world.get<Pos>(hostAvatar)!.y, 1e-3),
        );
      } else {
        // Partial corrections: each later snapshot removes part of the
        // remaining error, one round trip at a time.
        expect(corrections.length, greaterThan(1));
        expect(corrections.last.error, lessThan(corrections.first.error));
      }

      driving.move = null;
      await bed.frames(blend == 1 ? 60 : 200);
      final hp = host.world.get<Pos>(hostAvatar)!;
      final cp = client.world.get<Pos>(clientAvatar)!;
      expect(posError(hp, cp), lessThan(0.01));
      await bed.dispose();
    });
  }

  test(
    'prediction survives jitter and loss, converging after release',
    () async {
      final (bed, host, client, hostAvatar, clientAvatar) = await setup(
        jitterMs: 40,
        loss: 0.08,
      );
      final driving = client.world.getResource<Driving>()!;
      driving.move = const Move(0.7, -0.7);
      await bed.frames(150);
      driving.move = null;
      await bed.frames(100);
      final hp = host.world.get<Pos>(hostAvatar)!;
      final cp = client.world.get<Pos>(clientAvatar)!;
      expect(posError(hp, cp), lessThan(0.01));
      expect(hp.x, greaterThan(80));
      await bed.dispose();
    },
  );
}
