// Host and clients as separate machines: their own frame rates, clocks
// that drift, and links whose latency spikes.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  Future<(NetTestbed, App, App, Entity, Entity, Entity)> setup({
    int tickRate = 60,
    Duration latency = const Duration(milliseconds: 40),
    Duration jitter = Duration.zero,
  }) async {
    final bed = NetTestbed(
      tickRate: tickRate,
      latency: latency,
      jitter: jitter,
    );
    final host = await bed.startHost();
    final client = await bed.addClient();
    await bed.frames(30);
    final peerId = NetTestbed.session(client).localPeerId!;
    final scene = host.world.getResource<HostScene>()!;
    final hostAvatar = scene.avatars[peerId]!;
    final clientAvatar = entityFor(client, netIdOf(host, hostAvatar))!;
    final vehicle = entityFor(client, netIdOf(host, scene.vehicle!))!;
    return (bed, host, client, hostAvatar, clientAvatar, vehicle);
  }

  test('a 144 Hz client with a 60 Hz host: exact prediction, smooth remote '
      'motion', () async {
    final (bed, host, client, hostAvatar, clientAvatar, vehicle) = await setup(
      jitter: const Duration(milliseconds: 10),
    );
    host.world.getResource<HostScene>()!.vehicleVx = 10;
    final fps = {client: 144.0};
    await bed.runRealtime(const Duration(seconds: 2), fps: fps);

    final driving = client.world.getResource<Driving>()!;
    driving.move = const Move(1, 0.5);
    var lastX = client.world.get<Pos>(vehicle)!.x;
    final ratios = <double>[];
    await bed.runRealtime(
      const Duration(seconds: 4),
      fps: fps,
      afterFrame: (app, frameMs) {
        if (app != client) return;
        final x = client.world.get<Pos>(vehicle)!.x;
        ratios.add((x - lastX) / (10 * frameMs / 1000));
        lastX = x;
      },
    );
    driving.move = null;
    await bed.runRealtime(const Duration(seconds: 2), fps: fps);

    // Every client frame moves the remote vehicle by about its own frame
    // time of motion, although the host only ticks every 2.4 frames.
    expect(ratios.length, greaterThan(500));
    for (final r in ratios) {
      expect(r, inInclusiveRange(0.85, 1.15));
    }
    expect(NetTestbed.session(client).stats.corrections, 0);
    expect(
      posError(
        host.world.get<Pos>(hostAvatar)!,
        client.world.get<Pos>(clientAvatar)!,
      ),
      lessThan(0.01),
    );
    await bed.dispose();
  });

  test('clocks running 1 % fast and slow stay in step', () async {
    final bed = NetTestbed(
      tickRate: 60,
      latency: const Duration(milliseconds: 40),
    );
    final host = await bed.startHost(vehicle: false);
    final fast = await bed.addClient();
    final slow = await bed.addClient();
    await bed.frames(30);
    final rates = {fast: 1.01, slow: 0.99};
    await bed.runRealtime(const Duration(seconds: 5), clockRate: rates);
    final resetsBefore = [
      for (final c in [fast, slow]) NetTestbed.session(c).stats.tickResets,
    ];
    final lateBefore = NetTestbed.session(host).stats.lateInputs;
    for (final c in [fast, slow]) {
      c.world.getResource<Driving>()!.move = const Move(1, 0);
    }
    await bed.runRealtime(const Duration(seconds: 30), clockRate: rates);

    // Time dilation absorbs the drift: no resets, no late inputs, no
    // mispredictions.
    for (final (i, c) in [fast, slow].indexed) {
      final session = NetTestbed.session(c);
      expect(session.stats.tickResets, resetsBefore[i], reason: 'client $i');
      expect(session.stats.corrections, 0, reason: 'client $i');
    }
    expect(NetTestbed.session(host).stats.lateInputs - lateBefore, 0);
    await bed.dispose();
  });

  test('a latency spike: late inputs widen the buffer, prediction recovers, '
      'and the extra buffer is given back later', () async {
    final (bed, host, client, hostAvatar, clientAvatar, _) = await setup(
      latency: const Duration(milliseconds: 30),
    );
    final driving = client.world.getResource<Driving>()!;
    final session = NetTestbed.session(client);
    final tick = client.world.getResource<NetworkTick>()!;
    driving.move = const Move(1, 0);
    await bed.runRealtime(const Duration(seconds: 2));
    final leadBefore = tick.lead;
    bed.net.latency = const Duration(milliseconds: 250);
    await bed.runRealtime(const Duration(milliseconds: 1500));
    bed.net.latency = const Duration(milliseconds: 30);
    await bed.runRealtime(const Duration(seconds: 2));
    final leadAfterSpike = tick.lead;
    final correctionsAfterSpike = session.stats.corrections;
    await bed.runRealtime(const Duration(seconds: 3));
    driving.move = null;
    await bed.runRealtime(const Duration(seconds: 2));

    expect(NetTestbed.log(client).disconnected, isEmpty);
    // Once the link is back, prediction is exact again.
    expect(session.stats.corrections, correctionsAfterSpike);
    expect(
      posError(
        host.world.get<Pos>(hostAvatar)!,
        client.world.get<Pos>(clientAvatar)!,
      ),
      lessThan(0.01),
    );
    // Quiet for well over bufferDecaySeconds: the lead shrinks back to
    // what the RTT needs.
    await bed.runRealtime(const Duration(seconds: 40));
    expect(leadAfterSpike, greaterThan(leadBefore));
    expect(tick.lead, closeTo(leadBefore, 1));
    await bed.dispose();
  });
}
