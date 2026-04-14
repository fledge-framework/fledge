import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

/// Minimal in-memory transport for testing EncryptedTransport.
class _MockTransport implements Transport {
  Uint8List? lastSentData;
  final List<ReceivedPacket> _pendingReceive = [];

  @override
  ConnectionState get state => ConnectionState.connected;

  @override
  NetAddress? get localAddress => const NetAddress('127.0.0.1', 9999);

  @override
  Future<void> bind(int port) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> send(NetAddress address, Uint8List data) async {
    lastSentData = data;
  }

  @override
  Future<void> sendMultiple(List<NetAddress> addresses, Uint8List data) async {
    lastSentData = data;
  }

  @override
  List<ReceivedPacket> receive() {
    final result = List<ReceivedPacket>.from(_pendingReceive);
    _pendingReceive.clear();
    return result;
  }

  @override
  Stream<ReceivedPacket> get onReceive => const Stream.empty();

  @override
  Stream<ConnectionState> get onStateChange => const Stream.empty();

  void enqueueReceive(Uint8List data) {
    _pendingReceive.add(ReceivedPacket(
      source: const NetAddress('10.0.0.1', 8080),
      data: data,
    ));
  }
}

void main() {
  group('EncryptedTransport', () {
    test('generateKey returns 32 bytes', () {
      final key = EncryptedTransport.generateKey();
      expect(key.length, 32);
    });

    test('encrypt then decrypt returns original data', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      // Build a realistic packet: 6+ bytes so encryption kicks in.
      // First 6 bytes are plaintext header, rest is encrypted.
      final original = Uint8List.fromList([
        0x46, 0x4C, 0x45, 0x47, // magic
        0x01, // version
        0x01, // type
        // payload bytes (encrypted region)
        10, 20, 30, 40, 50, 60, 70, 80,
      ]);

      const addr = NetAddress('10.0.0.1', 8080);
      await transport.send(addr, original);

      // The inner transport received encrypted data.
      final encrypted = inner.lastSentData!;

      // Now simulate receiving that encrypted data back.
      inner.enqueueReceive(Uint8List.fromList(encrypted));
      final received = transport.receive();

      expect(received.length, 1);
      expect(received[0].data, equals(original));
    });

    test('encrypted data differs from original', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      final original = Uint8List.fromList([
        0x46, 0x4C, 0x45, 0x47, 0x01, 0x01, // header
        10, 20, 30, 40, 50, 60, 70, 80, // payload
      ]);

      const addr = NetAddress('10.0.0.1', 8080);
      await transport.send(addr, original);

      final encrypted = inner.lastSentData!;

      // The first 6 bytes (plaintext header) should be the same.
      expect(encrypted.sublist(0, 6), equals(original.sublist(0, 6)));

      // The encrypted region should differ from the original
      // (unless the key happens to be all zeros, which is astronomically unlikely).
      final encryptedPayload = encrypted.sublist(6);
      final originalPayload = original.sublist(6);
      expect(encryptedPayload, isNot(equals(originalPayload)));
    });

    test('without a key, data passes through unchanged', () async {
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: null);

      final original = Uint8List.fromList([
        0x46,
        0x4C,
        0x45,
        0x47,
        0x01,
        0x01,
        10,
        20,
        30,
        40,
      ]);

      const addr = NetAddress('10.0.0.1', 8080);
      await transport.send(addr, original);

      expect(inner.lastSentData, equals(original));
    });

    test('data shorter than header bytes passes through unchanged', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      // Only 4 bytes — shorter than the 6-byte plaintext header threshold.
      final shortData = Uint8List.fromList([1, 2, 3, 4]);

      const addr = NetAddress('10.0.0.1', 8080);
      await transport.send(addr, shortData);

      expect(inner.lastSentData, equals(shortData));
    });
  });
}
