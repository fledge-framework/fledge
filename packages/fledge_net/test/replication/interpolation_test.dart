// Interpolation of non-owned entities: keyed by server tick, rendered
// interpolationDelay behind on a smooth render clock, smooth despite
// jitter and loss (bounded extrapolation over loss bursts).
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// Per-frame client-side motion of the host's vehicle (moving 10 u/s,
/// i.e. 0.2 units per 20 ms tick) after a warm-up.
class _Run {
  final List<double> deltas = [];
  final List<double> lags = [];
  late final double settleError;

  /// Frames whose motion is not roughly one tick's worth (a stall or a
  /// jump): the smoothness criterion.
  int get roughFrames => deltas.where((d) => d < 0.14 || d > 0.26).length;
}

Future<_Run> _drive({
  required int seed,
  required int latencyMs,
  required int jitterMs,
  required double loss,
}) async {
  ComponentId.resetRegistry();
  final bed = NetTestbed(
    latency: Duration(milliseconds: latencyMs),
    jitter: Duration(milliseconds: jitterMs),
    packetLoss: loss,
    seed: seed,
  );
  final run = _Run();
  try {
    final host = await bed.startHost();
    final client = await bed.addClient();
    final scene = host.world.getResource<HostScene>()!;
    final vehicle = entityFor(client, netIdOf(host, scene.vehicle!))!;

    scene.vehicleVx = 10; // 0.2 units per 20 ms tick
    await bed.frames(60);

    var last = client.world.get<Pos>(vehicle)!.x;
    for (var i = 0; i < 150; i++) {
      await bed.frame();
      final x = client.world.get<Pos>(vehicle)!.x;
      run.deltas.add(x - last);
      run.lags.add(host.world.get<Pos>(scene.vehicle!)!.x - x);
      last = x;
    }

    scene.vehicleVx = 0;
    await bed.frames(40);
    run.settleError =
        (client.world.get<Pos>(vehicle)!.x -
                host.world.get<Pos>(scene.vehicle!)!.x)
            .abs();
  } finally {
    await bed.dispose();
  }
  return run;
}

void main() {
  setUp(ComponentId.resetRegistry);

  test(
    'default config: smooth for every seed, a steady delay behind',
    () async {
      // 50 ms + 0..30 ms one-way, 5 % loss, default interpolationDelay
      // (2 snapshot intervals + 50 ms = 170 ms at 50 Hz / 20 Hz).
      for (var seed = 1; seed <= 20; seed++) {
        final run = await _drive(
          seed: seed,
          latencyMs: 50,
          jitterMs: 30,
          loss: 0.05,
        );
        // Smooth: every frame advances by roughly one tick of motion
        // (never stalls, never jumps by a snapshot interval, never goes
        // back), although snapshots arrive only every 3 ticks.
        expect(run.roughFrames, 0, reason: 'seed $seed: ${run.deltas}');

        // Lag = (delay + mean snapshot age on arrival) * 0.2 u/tick.
        // Delay: 170 ms = 8.5 ticks. Age: 50..80 ms one-way, delivered
        // on 20 ms frame boundaries = 3 frames (1/3) or 4 frames (2/3),
        // mean 3.67 ticks. (8.5 + 3.67) * 0.2 = 2.43, steady.
        for (final lag in run.lags) {
          expect(lag, inInclusiveRange(2.3, 2.55), reason: 'seed $seed');
        }
        final lagSpread =
            run.lags.reduce((a, b) => a > b ? a : b) -
            run.lags.reduce((a, b) => a < b ? a : b);
        expect(lagSpread, lessThan(0.15), reason: 'seed $seed');

        // Once the vehicle stops, the client settles on the exact
        // position (after extrapolation, too).
        expect(run.settleError, lessThan(1e-4), reason: 'seed $seed');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('harsh link: smooth for nearly all seeds; loss bursts beyond the '
      'buffer extrapolate, then catch up without moving backwards', () async {
    // 80 ms + 0..40 ms one-way, 10 % loss. One lost snapshot is covered
    // by the delay; two or three in a row by extrapolation (100 ms).
    // Four in a row (p = 1e-4 per snapshot) outrun both: the vehicle
    // holds briefly, then catches up faster than real time. Seeds
    // 1..100 measured: 99 smooth; seeds 1..20 all smooth.
    var smooth = 0;
    for (var seed = 1; seed <= 20; seed++) {
      final run = await _drive(
        seed: seed,
        latencyMs: 80,
        jitterMs: 40,
        loss: 0.10,
      );
      if (run.roughFrames == 0) smooth++;
      for (final d in run.deltas) {
        // Never backwards, never a snapshot-interval jump.
        expect(d, inInclusiveRange(0, 0.5), reason: 'seed $seed');
      }
      expect(run.settleError, lessThan(1e-4), reason: 'seed $seed');
    }
    expect(smooth, greaterThanOrEqualTo(19));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
