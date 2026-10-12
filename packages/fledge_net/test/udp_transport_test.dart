import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Real-socket tests for [UdpTransport], bound to 127.0.0.1 only.
void main() {
  group('UdpTransport delivery contract', () {
    late UdpTransport sender;
    late UdpTransport receiver;

    setUp(() async {
      sender = UdpTransport(bindAddress: InternetAddress.loopbackIPv4);
      receiver = UdpTransport(
        bindAddress: InternetAddress.loopbackIPv4,
        maxBufferedPackets: 3,
      );
      await sender.bind(0);
      await receiver.bind(0);
    });

    tearDown(() async {
      await sender.close();
      await receiver.close();
    });

    NetAddress receiverAddress() =>
        NetAddress('127.0.0.1', receiver.localAddress!.port);

    test('stream listeners consume packets; receive() stays empty', () async {
      final got = <ReceivedPacket>[];
      final done = Completer<void>();
      receiver.onReceive.listen((p) {
        got.add(p);
        if (got.length == 5 && !done.isCompleted) done.complete();
      });

      for (var i = 0; i < 5; i++) {
        await sender.send(receiverAddress(), Uint8List.fromList([i]));
      }
      await done.future.timeout(const Duration(seconds: 5));

      expect(got, hasLength(5));
      expect(receiver.receive(), isEmpty, reason: 'no double delivery');
    });

    test('without a listener, receive() buffer is bounded', () async {
      for (var i = 0; i < 6; i++) {
        await sender.send(receiverAddress(), Uint8List.fromList([i]));
      }
      // Wait until all 6 datagrams have been read off the socket.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (receiver.stats.packetsReceived < 6 &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final drained = receiver.receive();
      expect(drained.map((p) => p.data.single), [3, 4, 5]);
      expect(receiver.bufferOverflowCount, 3);
      expect(receiver.receive(), isEmpty);
    });

    test(
      'bursts are not silently dropped when the socket would block',
      () async {
        const count = 300;
        final seen = <int>{};
        final done = Completer<void>();
        receiver.onReceive.listen((p) {
          seen.add(p.data[0] | (p.data[1] << 8));
          if (seen.length == count && !done.isCompleted) done.complete();
        });

        for (var i = 0; i < count; i++) {
          await sender.send(
            receiverAddress(),
            Uint8List.fromList([i & 0xFF, i >> 8]),
          );
        }
        await done.future.timeout(const Duration(seconds: 5));
        expect(seen, hasLength(count));
      },
    );
  });
}
