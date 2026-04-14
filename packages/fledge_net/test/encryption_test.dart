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

Uint8List _samplePacket() => Uint8List.fromList([
      0x46, 0x4C, 0x45, 0x47, // magic
      0x01, // version
      0x01, // type
      // encrypted region
      10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
    ]);

const _addr = NetAddress('10.0.0.1', 8080);

void main() {
  group('EncryptedTransport', () {
    test('generateKey returns 32 random bytes', () {
      final a = EncryptedTransport.generateKey();
      final b = EncryptedTransport.generateKey();
      expect(a.length, 32);
      expect(b.length, 32);
      expect(a, isNot(equals(b)),
          reason: 'two random keys should essentially never collide');
    });

    test('encrypt → decrypt round-trip returns original data', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      final original = _samplePacket();
      await transport.send(_addr, original);

      inner.enqueueReceive(Uint8List.fromList(inner.lastSentData!));
      final received = transport.receive();

      expect(received.length, 1);
      expect(received[0].data, equals(original));
    });

    test('wire format: header stays plaintext, payload grows by nonce+tag',
        () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      final original = _samplePacket();
      await transport.send(_addr, original);

      final wire = inner.lastSentData!;
      expect(
        wire.sublist(0, EncryptedTransport.plaintextHeaderBytes),
        equals(original.sublist(0, EncryptedTransport.plaintextHeaderBytes)),
        reason: 'plaintext header must be preserved for routing',
      );
      expect(
        wire.length,
        original.length + EncryptedTransport.overheadBytes,
        reason: 'wire packet = original + 12B nonce + 16B tag',
      );
    });

    test('nonce is unique across sends with the same key', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      final nonces = <String>{};
      for (var i = 0; i < 32; i++) {
        await transport.send(_addr, _samplePacket());
        final wire = inner.lastSentData!;
        final nonce = wire.sublist(
          EncryptedTransport.plaintextHeaderBytes,
          EncryptedTransport.plaintextHeaderBytes +
              EncryptedTransport.nonceBytes,
        );
        nonces.add(String.fromCharCodes(nonce));
      }
      expect(nonces.length, 32, reason: 'every packet must use a fresh nonce');
    });

    test('tampered ciphertext fails auth and is dropped', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      await transport.send(_addr, _samplePacket());
      final wire = Uint8List.fromList(inner.lastSentData!);

      // Flip a bit in the ciphertext region (after header + nonce).
      final ciphertextStart = EncryptedTransport.plaintextHeaderBytes +
          EncryptedTransport.nonceBytes;
      wire[ciphertextStart] ^= 0x01;

      inner.enqueueReceive(wire);
      final received = transport.receive();
      expect(received, isEmpty,
          reason: 'GCM auth tag mismatch must cause the packet to be dropped');
    });

    test('tampered header fails auth (header is AAD)', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      await transport.send(_addr, _samplePacket());
      final wire = Uint8List.fromList(inner.lastSentData!);

      // Flip a bit in the plaintext header — even though it's "plaintext", it's
      // bound into the auth tag as AAD, so tampering must be detected.
      wire[0] ^= 0x01;

      inner.enqueueReceive(wire);
      expect(transport.receive(), isEmpty);
    });

    test('truncated packet (missing tag bytes) is dropped', () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      await transport.send(_addr, _samplePacket());
      final wire = inner.lastSentData!;

      // Drop the last 4 bytes of the auth tag.
      inner
          .enqueueReceive(Uint8List.fromList(wire.sublist(0, wire.length - 4)));
      expect(transport.receive(), isEmpty);
    });

    test('packets encrypted under a different key cannot be decrypted',
        () async {
      final sender = EncryptedTransport(
        inner: _MockTransport(),
        sharedKey: EncryptedTransport.generateKey(),
      );

      final receiverInner = _MockTransport();
      final receiver = EncryptedTransport(
        inner: receiverInner,
        sharedKey: EncryptedTransport.generateKey(),
      );

      // Encrypt with sender's key, try to decrypt with receiver's key.
      final senderInner = sender.inner as _MockTransport;
      await sender.send(_addr, _samplePacket());
      receiverInner.enqueueReceive(senderInner.lastSentData!);

      expect(receiver.receive(), isEmpty);
    });

    test('without a key, data passes through unchanged', () async {
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: null);

      final original = _samplePacket();
      await transport.send(_addr, original);
      expect(inner.lastSentData, equals(original));

      inner.enqueueReceive(original);
      final received = transport.receive();
      expect(received.length, 1);
      expect(received[0].data, equals(original));
    });

    test('data with only a header (no payload) passes through unchanged',
        () async {
      final key = EncryptedTransport.generateKey();
      final inner = _MockTransport();
      final transport = EncryptedTransport(inner: inner, sharedKey: key);

      // Exactly 6 bytes — no payload to encrypt.
      final headerOnly =
          Uint8List.fromList([0x46, 0x4C, 0x45, 0x47, 0x01, 0x01]);
      await transport.send(_addr, headerOnly);
      expect(inner.lastSentData, equals(headerOnly));
    });

    test('setting a non-32-byte key throws', () {
      final transport =
          EncryptedTransport(inner: _MockTransport(), sharedKey: null);
      expect(
        () => transport.sharedKey = Uint8List(16),
        throwsArgumentError,
      );
    });
  });
}
