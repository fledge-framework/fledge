import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('NetAddress', () {
    test('stores host and port', () {
      const addr = NetAddress('192.168.1.1', 7777);
      expect(addr.host, '192.168.1.1');
      expect(addr.port, 7777);
    });

    test('toString returns host:port', () {
      const addr = NetAddress('10.0.0.1', 8080);
      expect(addr.toString(), '10.0.0.1:8080');
    });

    test('equality by host and port', () {
      const a = NetAddress('127.0.0.1', 3000);
      const b = NetAddress('127.0.0.1', 3000);
      const c = NetAddress('127.0.0.1', 3001);
      const d = NetAddress('10.0.0.1', 3000);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('hashCode is consistent with equality', () {
      const a = NetAddress('127.0.0.1', 3000);
      const b = NetAddress('127.0.0.1', 3000);
      expect(a.hashCode, b.hashCode);
    });

    test('works as map key', () {
      final map = <NetAddress, String>{};
      const addr = NetAddress('127.0.0.1', 3000);
      map[addr] = 'test';
      expect(map[const NetAddress('127.0.0.1', 3000)], 'test');
    });
  });

  group('ReceivedPacket', () {
    test('stores source and data', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final packet = ReceivedPacket(
        source: const NetAddress('10.0.0.1', 8080),
        data: data,
      );

      expect(packet.source, const NetAddress('10.0.0.1', 8080));
      expect(packet.data, data);
    });

    test('auto-populates receivedAt', () {
      final before = DateTime.now();
      final packet = ReceivedPacket(
        source: const NetAddress('10.0.0.1', 8080),
        data: Uint8List(0),
      );
      final after = DateTime.now();

      expect(
          packet.receivedAt
              .isAfter(before.subtract(const Duration(milliseconds: 1))),
          true);
      expect(
          packet.receivedAt
              .isBefore(after.add(const Duration(milliseconds: 1))),
          true);
    });

    test('accepts explicit receivedAt', () {
      final time = DateTime(2025, 1, 1);
      final packet = ReceivedPacket(
        source: const NetAddress('10.0.0.1', 8080),
        data: Uint8List(0),
        receivedAt: time,
      );
      expect(packet.receivedAt, time);
    });
  });

  group('TransportStats', () {
    test('starts at zero', () {
      final stats = TransportStats();
      expect(stats.bytesSent, 0);
      expect(stats.bytesReceived, 0);
      expect(stats.packetsSent, 0);
      expect(stats.packetsReceived, 0);
      expect(stats.packetsLost, 0);
    });

    test('reset clears all counters', () {
      final stats = TransportStats()
        ..bytesSent = 100
        ..bytesReceived = 200
        ..packetsSent = 10
        ..packetsReceived = 20
        ..packetsLost = 5;

      stats.reset();
      expect(stats.bytesSent, 0);
      expect(stats.bytesReceived, 0);
      expect(stats.packetsSent, 0);
      expect(stats.packetsReceived, 0);
      expect(stats.packetsLost, 0);
    });
  });
}
