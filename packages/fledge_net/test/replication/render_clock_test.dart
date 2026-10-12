// The render clock for interpolated entities stays smooth while the
// client simulation clock is corrected: time dilation, lead changes
// (RTT, late-input buffer), hard tick resets, and frames that run 0 or 2
// fixed steps.
import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

import '../support/replication_harness.dart';

/// Minimal FixedTimestep accumulator model (in steps) driving a
/// ClientTickSync the way NetworkSession does.
class _SimClock {
  final ClientTickSync sync;
  double acc = 0;
  int stepsLastFrame = 0;

  _SimClock(this.sync);

  void frame(double dtSteps) {
    acc += dtSteps;
    stepsLastFrame = 0;
    while (acc >= 1) {
      acc -= 1;
      acc += sync.step(); // nudge
      stepsLastFrame++;
    }
  }

  double get timeline => sync.timeline(acc);
}

void main() {
  setUp(ComponentId.resetRegistry);

  group('ClientTickSync.timeline', () {
    test('advances by exactly the frame time through dilation, lead '
        'changes and resets', () {
      final sync = ClientTickSync(stepMs: 20)
        ..initialSync(serverTick: 1000, rttSampleMs: 100);
      final sim = _SimClock(sync);
      const frames = [0.35, 1.0, 1.7, 0.6, 2.2, 0.9]; // 0, 1 and 2 steps
      var hostTick = 1000.0;
      var last = sim.timeline;
      var dilated = 0;
      var oldRenderSteps = 0;
      var lastOldRender = sync.renderTick(alpha: sim.acc, delayTicks: 5);
      for (var i = 0; i < 600; i++) {
        final dt = frames[i % frames.length];
        sim.frame(dt);
        hostTick += dt;
        if (i % 3 == 0) sync.observe(serverTick: hostTick.floor());
        if (i == 100) sync.rttMs = 220; // lead + 6 ticks
        if (i == 200) sync.reportLateInputs(1); // lead + 1 tick
        if (i == 300) sync.observe(serverTick: hostTick.floor() + 40);
        if (sync.error.abs() > sync.deadbandTicks) dilated++;

        // Timeline: exactly the frame time, every frame.
        expect(sim.timeline - last, closeTo(dt, 1e-9), reason: 'frame $i');
        last = sim.timeline;

        // The old sim-clock-based render tick (kept for compatibility)
        // steps whenever the lead or the tick is corrected.
        final oldRender = sync.renderTick(alpha: sim.acc, delayTicks: 5);
        if ((oldRender - lastOldRender - dt).abs() > 0.05) oldRenderSteps++;
        lastOldRender = oldRender;
      }
      // The forced +40 jump, then the reset back to the real host tick.
      expect(sync.resets, 2);
      expect(dilated, greaterThan(10));
      expect(oldRenderSteps, greaterThan(10));
    });
  });

  group('InterpolationClock', () {
    test('converges on the delayed target and never steps', () {
      final sync = ClientTickSync(stepMs: 20)
        ..initialSync(serverTick: 0, rttSampleMs: 60);
      final sim = _SimClock(sync);
      final clock = InterpolationClock();
      const frames = [0.4, 1.3, 0.7, 2.1, 1.0]; // 0, 1 and 2 steps
      var hostTick = 0.0;
      var nextSnapshot = 3;
      double? lastRender;
      var lastTimeline = sim.timeline;
      for (var i = 0; i < 1500; i++) {
        final dt = frames[i % frames.length];
        sim.frame(dt);
        hostTick += dt;
        // Snapshots every 3 ticks, arriving 3 ticks later +-0.75.
        while (nextSnapshot + 3 + (nextSnapshot % 7 - 3) * 0.25 <= hostTick) {
          clock.observe(serverTick: nextSnapshot, timeline: sim.timeline);
          nextSnapshot += 3;
        }
        // Simulation-clock corrections must not reach the render clock.
        if (i == 400) sync.rttMs = 200;
        if (i == 600) sync.reportLateInputs(3);
        if (i == 800) sync.observe(serverTick: hostTick.floor() + 50);
        if (i % 20 == 0) sync.observe(serverTick: hostTick.floor() - 3);
        if (!clock.hasOffset) continue;
        final render = clock.advance(timeline: sim.timeline, delayTicks: 6);
        final elapsed = sim.timeline - lastTimeline;
        lastTimeline = sim.timeline;
        if (lastRender != null) {
          final step = render - lastRender;
          expect(
            step,
            inInclusiveRange(elapsed * 0.9 - 1e-9, elapsed * 1.1 + 1e-9),
            reason: 'frame $i',
          );
        }
        lastRender = render;
      }
      // Newest snapshot ~ hostTick - 3 (arrivals are seen at frame
      // boundaries, on average ~half a frame later); rendered 6 behind.
      expect(lastRender, closeTo(hostTick - 3 - 6, 1.0));
    });

    test('snaps only on a large discontinuity', () {
      final clock = InterpolationClock()..observe(serverTick: 100, timeline: 0);
      expect(clock.advance(timeline: 0, delayTicks: 5), 95);
      expect(clock.advance(timeline: 1, delayTicks: 5), closeTo(96, 1e-9));
      // Offset moves by 3 ticks: slewed (<= 10 % per tick), no jump.
      clock
        ..resetOffset()
        ..observe(serverTick: 104, timeline: 1);
      final r = clock.advance(timeline: 2, delayTicks: 5);
      expect(r - 96, inInclusiveRange(0.9, 1.1));
      // Host clock moved by 50 ticks: snap.
      clock
        ..resetOffset()
        ..observe(serverTick: 160, timeline: 2);
      expect(clock.advance(timeline: 3, delayTicks: 5), closeTo(156, 1e-9));
    });
  });

  test('end to end: render motion follows frame time while RTT, lead and '
      'fixed steps per frame vary', () async {
    final bed = NetTestbed(latency: const Duration(milliseconds: 30));
    final host = await bed.startHost();
    final client = await bed.addClient();
    final scene = host.world.getResource<HostScene>()!;
    final vehicle = entityFor(client, netIdOf(host, scene.vehicle!))!;
    final tick = client.world.getResource<NetworkTick>()!;
    final ts = client.world.getResource<FixedTimestep>()!;
    scene.vehicleVx = 10;
    await bed.frames(100);
    final leadBefore = tick.lead;

    Future<void> frame(int ms) async {
      await bed.net.advance(Duration(milliseconds: ms));
      for (final app in bed.apps) {
        app.world.getResource<WallTime>()!.delta = ms / 1000;
        await app.tick();
      }
    }

    // Frame times that make the client run 0, 1 or 2 fixed steps.
    const frameMs = [13, 27, 20, 33, 7, 31, 9];
    final stepCounts = <int>{};
    var last = client.world.get<Pos>(vehicle)!.x;
    var prevMs = 20;
    for (var i = 0; i < 300; i++) {
      if (i == 60) bed.net.latency = const Duration(milliseconds: 90);
      final ms = frameMs[i % frameMs.length];
      await frame(ms);
      stepCounts.add(ts.stepsThisFrame);
      final x = client.world.get<Pos>(vehicle)!.x;
      // Interpolation runs in Schedules.first, so a frame shows the
      // time the previous frame's fixed pass consumed.
      final expected = 10 * prevMs / 1000;
      expect(
        x - last,
        inInclusiveRange(expected * 0.9 - 1e-6, expected * 1.1 + 1e-6),
        reason: 'frame $i (${ms}ms, prev ${prevMs}ms)',
      );
      last = x;
      prevMs = ms;
    }
    // The simulation clock really was corrected meanwhile.
    expect(stepCounts, containsAll([0, 1, 2]));
    expect(tick.lead - leadBefore, greaterThanOrEqualTo(2));
    await bed.dispose();
  });
}
