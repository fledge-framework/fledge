// Client prediction + reconciliation for the locally owned avatar.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
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
      final yBefore = p.y;
      host.world.insert(hostAvatar, Pos(p.x, p.y + 5));
      final drawnY = <double>[];
      for (var i = 0; i < 60; i++) {
        await bed.frame();
        final smoothed = client.world.get<NetSmoothed<Pos>>(clientAvatar);
        if (smoothed != null) drawnY.add(smoothed.value.y);
      }

      final corrections = NetTestbed.log(client).corrected;
      // The simulation snaps: the history is rewritten in one correction
      // and the predicted y already includes the teleport (the client
      // leads the host while driving, so compare y only).
      expect(corrections, hasLength(1));
      expect(corrections.first.entity, clientAvatar);
      expect(corrections.first.error, greaterThan(4));
      expect(
        client.world.get<Pos>(clientAvatar)!.y,
        closeTo(host.world.get<Pos>(hostAvatar)!.y, 1e-3),
      );
      if (blend == 1) {
        expect(drawnY, isEmpty, reason: 'nothing to smooth');
      } else {
        // Drawn: from the old prediction up to the new one, a step at a
        // time, then the smoothing ends.
        expect(drawnY.length, greaterThan(3));
        expect(drawnY.first, lessThan(yBefore + 5 * 0.6));
        for (var i = 1; i < drawnY.length; i++) {
          expect(drawnY[i], greaterThanOrEqualTo(drawnY[i - 1]));
        }
        expect(client.world.has<NetSmoothed<Pos>>(clientAvatar), isFalse);
      }

      driving.move = null;
      await bed.frames(60);
      final hp = host.world.get<Pos>(hostAvatar)!;
      final cp = client.world.get<Pos>(clientAvatar)!;
      expect(posError(hp, cp), lessThan(0.01));
      await bed.dispose();
    });
  }

  test('a stalled client keeps the inputs it made around the stall', () async {
    final (bed, host, client, hostAvatar, clientAvatar) = await setup();
    final peerId = NetTestbed.session(client).localPeerId!;
    var hostReal = 0;
    var clientMade = 0;
    final driving = client.world.getResource<Driving>()!;
    driving.move = const Move(1, 0);
    Future<void> frame() async {
      await bed.frame();
      final inputs = host.world.getResource<NetInputs<Move>>()!;
      hostReal += inputs.forPeer(peerId).where((e) => !e.repeated).length;
      if (bed.paused.contains(client)) return;
      final own = client.world.getResource<NetInputs<Move>>()!.entries;
      clientMade += own.where((e) => !e.repeated).length;
    }

    for (var i = 0; i < 40; i++) {
      await frame();
    }
    // The client's process stalls for half a second (no frames), then
    // resumes behind the host and must reset its tick.
    bed.paused.add(client);
    for (var i = 0; i < 25; i++) {
      await frame();
    }
    bed.paused.remove(client);
    final resetsBefore = NetTestbed.session(client).stats.tickResets;
    var lastX = client.world.get<Pos>(clientAvatar)!.x;
    for (var i = 0; i < 40; i++) {
      await frame();
      // Driving +x: the predicted avatar never snaps back to a server
      // state from before the stall.
      final x = client.world.get<Pos>(clientAvatar)!.x;
      expect(x, greaterThanOrEqualTo(lastX - 1e-9), reason: 'frame $i');
      lastX = x;
    }
    expect(
      NetTestbed.session(client).stats.tickResets,
      greaterThan(resetsBefore),
    );
    driving.move = null;
    for (var i = 0; i < 60; i++) {
      await frame();
    }
    // Every input the client made reached the host.
    expect(hostReal, greaterThanOrEqualTo(clientMade - 2));
    // The client kept its prediction through the reset: no snap back to a
    // pre-stall server state, so at most one correction (the host's
    // repeated inputs during the stall).
    expect(NetTestbed.log(client).corrected.length, lessThanOrEqualTo(1));
    final hp = host.world.get<Pos>(hostAvatar)!;
    final cp = client.world.get<Pos>(clientAvatar)!;
    expect(posError(hp, cp), lessThan(0.01));
    await bed.dispose();
  });

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
