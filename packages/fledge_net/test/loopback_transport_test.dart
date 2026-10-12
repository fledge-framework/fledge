import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('LoopbackNetwork basics', () {
    test('delivers datagrams between bound transports', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1000);
      await b.bind(2000);

      final got = <ReceivedPacket>[];
      b.onReceive.listen(got.add);

      await a.send(const NetAddress('127.0.0.1', 2000), _bytes([1, 2, 3]));
      await _settle();

      expect(got, hasLength(1));
      expect(got.single.source, const NetAddress('127.0.0.1', 1000));
      expect(got.single.data, [1, 2, 3]);
      expect(net.stats.sent, 1);
      expect(net.stats.delivered, 1);
    });

    test('port 0 assigns distinct ephemeral ports', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(0);
      await b.bind(0);
      expect(a.localAddress, isNot(b.localAddress));
    });

    test('binding an address twice throws', () async {
      final net = LoopbackNetwork();
      await net.createTransport().bind(7777);
      expect(() => net.createTransport().bind(7777), throwsStateError);
    });

    test('distinct hosts can share a port', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport(host: '10.0.0.2');
      final b = net.createTransport(host: '10.0.0.3');
      await a.bind(5000);
      await b.bind(5000);
      expect(a.localAddress, const NetAddress('10.0.0.2', 5000));
      expect(b.localAddress, const NetAddress('10.0.0.3', 5000));
    });

    test('datagrams to unbound addresses are counted undeliverable', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport();
      await a.bind(0);
      await a.send(const NetAddress('127.0.0.1', 1), _bytes([1]));
      expect(net.stats.undeliverable, 1);
    });

    test('send before bind throws', () {
      final net = LoopbackNetwork();
      expect(
        () => net.createTransport().send(
          const NetAddress('127.0.0.1', 1),
          _bytes([1]),
        ),
        throwsStateError,
      );
    });

    test('closing unbinds the address', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport();
      await a.bind(7777);
      await a.close();
      await net.createTransport().bind(7777); // no throw
    });

    test('rejects out-of-range probabilities', () {
      expect(() => LoopbackNetwork(packetLoss: 1.5), throwsArgumentError);
      expect(() => LoopbackNetwork(duplication: -0.1), throwsArgumentError);
    });
  });

  group('LoopbackNetwork impairments', () {
    test('packetLoss 1.0 drops everything', () async {
      final net = LoopbackNetwork(packetLoss: 1);
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      for (var i = 0; i < 10; i++) {
        await a.send(b.localAddress!, _bytes([i]));
      }
      expect(net.stats.dropped, 10);
      expect(b.receive(), isEmpty);
    });

    test('seeded loss pattern is reproducible', () async {
      Future<List<int>> run(int seed) async {
        final net = LoopbackNetwork(packetLoss: 0.5, random: Random(seed));
        final a = net.createTransport();
        final b = net.createTransport();
        await a.bind(1);
        await b.bind(2);
        for (var i = 0; i < 50; i++) {
          await a.send(b.localAddress!, _bytes([i]));
        }
        return b.receive().map((p) => p.data.single).toList();
      }

      final first = await run(7);
      final second = await run(7);
      expect(first, second);
      expect(first.length, inExclusiveRange(5, 45));
    });

    test('duplication 1.0 delivers every datagram twice', () async {
      final net = LoopbackNetwork(duplication: 1);
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      await a.send(b.localAddress!, _bytes([9]));
      expect(b.receive().map((p) => p.data.single), [9, 9]);
      expect(net.stats.duplicated, 1);
    });

    test('filter can drop specific datagrams deterministically', () async {
      var seen = 0;
      final net = LoopbackNetwork(filter: (_) => seen++ != 0);
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      await a.send(b.localAddress!, _bytes([1]));
      await a.send(b.localAddress!, _bytes([2]));
      expect(b.receive().map((p) => p.data.single), [2]);
    });

    test('real-time latency delays delivery', () async {
      final net = LoopbackNetwork(latency: const Duration(milliseconds: 30));
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      final got = Completer<Duration>();
      final sw = Stopwatch()..start();
      b.onReceive.listen((_) => got.complete(sw.elapsed));
      await a.send(b.localAddress!, _bytes([1]));
      expect(net.inFlight, 1);
      expect(
        await got.future,
        greaterThanOrEqualTo(const Duration(milliseconds: 25)),
      );
    });
  });

  group('LoopbackNetwork manual mode', () {
    test('delivers only when the clock reaches the delivery time', () async {
      final clock = ManualNetClock();
      final net = LoopbackNetwork(
        latency: const Duration(milliseconds: 50),
        clock: clock,
      );
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      final got = <ReceivedPacket>[];
      b.onReceive.listen(got.add);

      await a.send(b.localAddress!, _bytes([1]));
      await net.advance(const Duration(milliseconds: 49));
      expect(got, isEmpty);
      expect(clock.nowMs, 49);

      await net.advance(const Duration(milliseconds: 1));
      expect(got, hasLength(1));
      expect(clock.nowMs, 50);
    });

    test('replies sent during advance arrive in the same window', () async {
      final clock = ManualNetClock();
      final net = LoopbackNetwork(
        latency: const Duration(milliseconds: 10),
        clock: clock,
      );
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      b.onReceive.listen((p) => b.send(p.source, p.data));
      final echoTimes = <int>[];
      a.onReceive.listen((_) => echoTimes.add(clock.nowMs));

      await a.send(b.localAddress!, _bytes([1]));
      await net.advance(const Duration(milliseconds: 100));
      expect(echoTimes, [20]);
    });

    test('seeded jitter yields the same delivery order every run', () async {
      Future<List<int>> run() async {
        final net = LoopbackNetwork(
          latency: const Duration(milliseconds: 5),
          jitter: const Duration(milliseconds: 20),
          random: Random(3),
          clock: ManualNetClock(),
        );
        final a = net.createTransport();
        final b = net.createTransport();
        await a.bind(1);
        await b.bind(2);
        final order = <int>[];
        b.onReceive.listen((p) => order.add(p.data.single));
        for (var i = 0; i < 20; i++) {
          await a.send(b.localAddress!, _bytes([i]));
        }
        await net.flush();
        return order;
      }

      final first = await run();
      expect(first, hasLength(20));
      expect(await run(), first);
      // Jitter should have reordered at least something.
      expect(first, isNot(List.generate(20, (i) => i)));
    });

    test('advance on a real-time network throws', () {
      expect(() => LoopbackNetwork().advance(Duration.zero), throwsStateError);
    });
  });

  group('Transport delivery contract (LoopbackTransport)', () {
    test('with an onReceive listener, receive() stays empty', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport();
      final b = net.createTransport();
      await a.bind(1);
      await b.bind(2);
      final got = <ReceivedPacket>[];
      b.onReceive.listen(got.add);
      for (var i = 0; i < 5; i++) {
        await a.send(b.localAddress!, _bytes([i]));
      }
      await _settle();
      expect(got, hasLength(5));
      expect(b.receive(), isEmpty);
    });

    test('without a listener, the receive() buffer is bounded', () async {
      final net = LoopbackNetwork();
      final a = net.createTransport();
      final b = net.createTransport(maxBufferedPackets: 3);
      await a.bind(1);
      await b.bind(2);
      for (var i = 0; i < 5; i++) {
        await a.send(b.localAddress!, _bytes([i]));
      }
      expect(b.receive().map((p) => p.data.single), [2, 3, 4]);
      expect(b.bufferOverflowCount, 2);
      expect(b.receive(), isEmpty);
    });

    test('EncryptedTransport over loopback honours the contract', () async {
      final key = EncryptedTransport.generateKey();
      final net = LoopbackNetwork();
      final a = EncryptedTransport(
        inner: net.createTransport(),
        sharedKey: key,
      );
      final b = EncryptedTransport(
        inner: net.createTransport(),
        sharedKey: key,
      );
      await a.bind(1);
      await b.bind(2);
      final got = <ReceivedPacket>[];
      b.onReceive.listen(got.add);
      final packet = Packet(
        header: PacketHeader(type: PacketType.custom, sequence: 1),
        payload: _bytes([1, 2, 3]),
      ).toBytes();
      await a.send(b.localAddress!, packet);
      await _settle();
      expect(got.single.data, packet);
      expect(b.receive(), isEmpty);
    });
  });

  group('NetClock', () {
    test('elapsed32 is correct across the 32-bit wrap', () {
      final clock = ManualNetClock(0xFFFFFFF0);
      final sent = clock.nowMs32;
      clock.advance(const Duration(milliseconds: 32));
      expect(clock.nowMs32, lessThan(sent)); // wrapped
      expect(NetClock.elapsed32(clock.nowMs32, sent), 32);
    });

    test('elapsed32 is negative for timestamps in the future', () {
      expect(NetClock.elapsed32(100, 150), -50);
      expect(NetClock.elapsed32(5, 0xFFFFFFFB), 10);
    });

    test('system clock is monotonic and 32-bit on the wire', () {
      final a = NetClock.system.nowMs;
      final b = NetClock.system.nowMs;
      expect(b, greaterThanOrEqualTo(a));
      expect(NetClock.system.nowMs32, inInclusiveRange(0, 0xFFFFFFFF));
    });

    test('manual clock refuses to run backwards', () {
      final clock = ManualNetClock(10);
      expect(() => clock.nowMs = 5, throwsArgumentError);
    });
  });
}
