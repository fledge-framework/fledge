// Interpolation of non-owned entities: keyed by server tick, rendered
// interpolationDelay behind, smooth despite jitter and loss.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

void main() {
  setUp(ComponentId.resetRegistry);

  test('vehicle moves smoothly on the client, a fixed delay behind', () async {
    final bed = NetTestbed(
      latency: const Duration(milliseconds: 50),
      jitter: const Duration(milliseconds: 30),
      packetLoss: 0.05,
      seed: 17,
    );
    final host = await bed.startHost();
    final client = await bed.addClient();
    final scene = host.world.getResource<HostScene>()!;
    final vehicleOnClient = entityFor(client, netIdOf(host, scene.vehicle!))!;

    scene.vehicleVx = 10; // 0.2 units per 20 ms tick
    await bed.frames(60);

    final deltas = <double>[];
    final lags = <double>[];
    var last = client.world.get<Pos>(vehicleOnClient)!.x;
    for (var i = 0; i < 150; i++) {
      await bed.frame();
      final x = client.world.get<Pos>(vehicleOnClient)!.x;
      deltas.add(x - last);
      lags.add(host.world.get<Pos>(scene.vehicle!)!.x - x);
      last = x;
    }

    // Smooth: every frame advances by roughly one tick of motion (never
    // stalls, never jumps by a whole snapshot interval, never goes back),
    // even though snapshots arrive only every 3 ticks with jitter/loss.
    for (final d in deltas) {
      expect(d, inInclusiveRange(0.14, 0.26));
    }
    // Rendered interpolationDelay (100 ms) + mean one-way latency
    // (~65 ms) behind: 10 u/s * ~0.17 s, and steady.
    for (final lag in lags) {
      expect(lag, inInclusiveRange(1.4, 2.2));
    }

    // Once the vehicle stops, the client settles on the exact position.
    scene.vehicleVx = 0;
    await bed.frames(40);
    expect(
      client.world.get<Pos>(vehicleOnClient)!.x,
      closeTo(host.world.get<Pos>(scene.vehicle!)!.x, 1e-4),
    );
    await bed.dispose();
  });
}
