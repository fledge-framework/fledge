import 'dart:math';
import 'dart:typed_data';

import 'transport.dart';

/// A transport wrapper that encrypts/decrypts packet payloads.
///
/// Uses XOR-based encryption with a shared key for lightweight
/// packet obfuscation. For production use, replace the cipher
/// with AES-GCM from `package:cryptography`.
///
/// The first 6 bytes of each packet (magic + version + type) remain
/// in plaintext for routing. The rest of the packet (sequence, ack,
/// ackBits, timestamp, payload) is encrypted.
///
/// ## Usage
///
/// ```dart
/// final inner = UdpTransport();
/// final transport = EncryptedTransport(
///   inner: inner,
///   sharedKey: mySessionKey,
/// );
/// ```
class EncryptedTransport implements Transport {
  /// The inner transport to wrap.
  final Transport inner;

  /// Shared encryption key.
  ///
  /// Both host and client must use the same key. Key exchange
  /// should happen during the connection handshake.
  Uint8List? sharedKey;

  /// Number of plaintext header bytes to skip (magic + version + type).
  static const int _plaintextHeaderBytes = 6;

  EncryptedTransport({
    required this.inner,
    this.sharedKey,
  });

  /// Generate a random 32-byte key.
  static Uint8List generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
  }

  @override
  ConnectionState get state => inner.state;

  @override
  NetAddress? get localAddress => inner.localAddress;

  @override
  Stream<ReceivedPacket> get onReceive => inner.onReceive.map(_decryptReceived);

  @override
  Stream<ConnectionState> get onStateChange => inner.onStateChange;

  @override
  Future<void> bind(int port) => inner.bind(port);

  @override
  Future<void> close() => inner.close();

  @override
  Future<void> send(NetAddress address, Uint8List data) {
    if (sharedKey == null || data.length <= _plaintextHeaderBytes) {
      return inner.send(address, data);
    }
    return inner.send(address, _encrypt(data));
  }

  @override
  Future<void> sendMultiple(List<NetAddress> addresses, Uint8List data) {
    if (sharedKey == null || data.length <= _plaintextHeaderBytes) {
      return inner.sendMultiple(addresses, data);
    }
    return inner.sendMultiple(addresses, _encrypt(data));
  }

  @override
  List<ReceivedPacket> receive() {
    return inner.receive().map(_decryptReceived).toList();
  }

  Uint8List _encrypt(Uint8List data) {
    final key = sharedKey!;
    final result = Uint8List.fromList(data);
    for (var i = _plaintextHeaderBytes; i < result.length; i++) {
      result[i] = result[i] ^ key[(i - _plaintextHeaderBytes) % key.length];
    }
    return result;
  }

  Uint8List _decrypt(Uint8List data) {
    // XOR is symmetric — encrypt and decrypt are the same operation
    return _encrypt(data);
  }

  ReceivedPacket _decryptReceived(ReceivedPacket packet) {
    if (sharedKey == null || packet.data.length <= _plaintextHeaderBytes) {
      return packet;
    }
    return ReceivedPacket(
      data: _decrypt(packet.data),
      source: packet.source,
      receivedAt: packet.receivedAt,
    );
  }
}
