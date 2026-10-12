import 'dart:math';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('RTT over a real-time loopback link', () {
    test(
      'host and client both measure the round trip, not epoch time',
      () async {
        // 40ms each way => ~80ms round trip.
        final net = LoopbackNetwork(latency: const Duration(milliseconds: 40));
        final host = NetworkHost(transport: net.createTransport());
        final client = NetworkClient(
          transport: net.createTransport(),
          pingInterval: const Duration(milliseconds: 50),
        );
        await host.start(7777);
        expect(await client.connect('127.0.0.1', 7777), isTrue);

        for (var i = 0; i < 40; i++) {
          host.update();
          client.update();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(client.rtt, inInclusiveRange(70, 400));
        expect(host.peers.single.rtt, inInclusiveRange(70, 400));

        await client.disconnect();
        await host.stop();
      },
    );
  });

  group('RTT with a manual clock (deterministic)', () {
    late ManualNetClock clock;
    late LoopbackNetwork net;
    late NetworkHost host;
    late NetworkClient client;

    Future<void> setUpLink({
      required int startMs,
      Duration latency = const Duration(milliseconds: 50),
      Duration jitter = Duration.zero,
    }) async {
      clock = ManualNetClock(startMs);
      net = LoopbackNetwork(
        latency: latency,
        jitter: jitter,
        clock: clock,
        random: Random(11),
      );
      host = NetworkHost(
        transport: net.createTransport(),
        clock: clock,
        pingInterval: const Duration(milliseconds: 200),
      );
      client = NetworkClient(
        transport: net.createTransport(),
        clock: clock,
        pingInterval: const Duration(milliseconds: 200),
      );
      await host.start(7777);
      final connecting = client.connect('127.0.0.1', 7777);
      await net.advance(latency * 2 + jitter * 2);
      expect(await connecting, isTrue);
    }

    Future<void> run(Duration total) async {
      const step = Duration(milliseconds: 10);
      for (var t = Duration.zero; t < total; t += step) {
        host.update();
        client.update();
        await net.advance(step);
      }
    }

    tearDown(() async {
      await client.disconnect();
      await host.stop();
    });

    test('both sides measure exactly 2x one-way latency', () async {
      await setUpLink(startMs: 0);
      expect(client.rtt, 0);
      expect(host.peers.single.rtt, 0);

      await run(const Duration(milliseconds: 1000));

      expect(client.rtt, 100);
      expect(host.peers.single.rtt, 100);
    });

    test('RTT is correct while the 32-bit clock wraps', () async {
      // Start 300ms before the wire timestamp wraps to 0.
      await setUpLink(startMs: 0xFFFFFFFF - 300);
      await run(const Duration(milliseconds: 1000));
      expect(clock.nowMs32, lessThan(1000), reason: 'clock has wrapped');
      expect(client.rtt, 100);
      expect(host.peers.single.rtt, 100);
    });

    test('retransmit timeouts reflect the measured RTT', () async {
      await setUpLink(startMs: 0, latency: const Duration(milliseconds: 150));
      expect(client.retransmitTimeout, const Duration(milliseconds: 100));

      await run(const Duration(milliseconds: 1500));

      expect(client.rtt, 300);
      expect(client.retransmitTimeout, const Duration(milliseconds: 600));
      expect(
        host.peers.single.retransmitTimeout(host.retransmitTimeout),
        const Duration(milliseconds: 600),
      );
    });

    test('RTT stays within the latency envelope under jitter', () async {
      await setUpLink(
        startMs: 0,
        latency: const Duration(milliseconds: 30),
        jitter: const Duration(milliseconds: 20),
      );
      await run(const Duration(milliseconds: 3000));
      expect(client.rtt, inInclusiveRange(60, 100));
      expect(host.peers.single.rtt, inInclusiveRange(60, 100));
    });
  });
}
