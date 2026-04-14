import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'transport.dart';

/// Authenticated-encryption transport wrapper for packet payloads.
///
/// Wraps an inner [Transport] and encrypts the non-routing portion of every
/// outgoing packet with AES-256-GCM. Incoming packets whose authentication
/// tag fails verification are silently dropped.
///
/// The first 6 bytes of each packet (magic + version + type) remain in
/// plaintext so the receiver can route/drop without attempting decryption.
/// The encrypted region covers sequence/ack/ackBits/timestamp/payload.
///
/// ## Wire format
///
/// ```
/// [ 6 bytes  ] plaintext header (magic + version + type)
/// [ 12 bytes ] random GCM nonce
/// [ N bytes  ] ciphertext (sequence, ack, ackBits, timestamp, payload)
/// [ 16 bytes ] GCM authentication tag
/// ```
///
/// Each encrypted packet grows by 28 bytes over the plaintext payload
/// (`nonceBytes + tagBytes`).
///
/// ## Key distribution
///
/// This wrapper operates on a **pre-shared 256-bit key**. Both host and
/// client must be configured with the same key before any encrypted traffic
/// flows. Key negotiation (e.g. a Diffie–Hellman handshake) is out of scope
/// and must be handled at a higher layer.
///
/// ## Usage
///
/// ```dart
/// final key = EncryptedTransport.generateKey(); // 32 random bytes
/// final transport = EncryptedTransport(
///   inner: UdpTransport(),
///   sharedKey: key,
/// );
/// ```
class EncryptedTransport implements Transport {
  /// The inner transport to wrap.
  final Transport inner;

  /// Number of plaintext header bytes left unencrypted (magic + version + type).
  static const int plaintextHeaderBytes = 6;

  /// GCM nonce length in bytes (standard for AES-GCM).
  static const int nonceBytes = 12;

  /// GCM authentication tag length in bytes.
  static const int tagBytes = 16;

  /// Per-encrypted-packet overhead (nonce + tag) in bytes.
  static const int overheadBytes = nonceBytes + tagBytes;

  /// Minimum viable encrypted packet size: header + nonce + tag (ciphertext
  /// may be zero bytes, though our framer never emits that).
  static const int _minEncryptedSize =
      plaintextHeaderBytes + nonceBytes + tagBytes;

  Uint8List? _sharedKey;
  final Random _random;

  EncryptedTransport({
    required this.inner,
    Uint8List? sharedKey,
    Random? random,
  }) : _random = random ?? Random.secure() {
    this.sharedKey = sharedKey;
  }

  /// Shared 256-bit encryption key.
  ///
  /// Setting to `null` disables encryption (packets pass through unchanged).
  /// Setting to a non-null value must be exactly 32 bytes.
  Uint8List? get sharedKey => _sharedKey;
  set sharedKey(Uint8List? value) {
    if (value != null && value.length != 32) {
      throw ArgumentError(
          'sharedKey must be exactly 32 bytes (AES-256); got ${value.length}');
    }
    _sharedKey = value;
  }

  /// Generate a cryptographically random 32-byte key suitable for AES-256.
  static Uint8List generateKey([Random? random]) {
    final rng = random ?? Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  @override
  ConnectionState get state => inner.state;

  @override
  NetAddress? get localAddress => inner.localAddress;

  @override
  Stream<ReceivedPacket> get onReceive =>
      inner.onReceive.map(_decryptReceived).where((p) => p != null).cast();

  @override
  Stream<ConnectionState> get onStateChange => inner.onStateChange;

  @override
  Future<void> bind(int port) => inner.bind(port);

  @override
  Future<void> close() => inner.close();

  @override
  Future<void> send(NetAddress address, Uint8List data) {
    final payload = _encryptIfPossible(data);
    return inner.send(address, payload);
  }

  @override
  Future<void> sendMultiple(List<NetAddress> addresses, Uint8List data) {
    final payload = _encryptIfPossible(data);
    return inner.sendMultiple(addresses, payload);
  }

  @override
  List<ReceivedPacket> receive() {
    final out = <ReceivedPacket>[];
    for (final packet in inner.receive()) {
      final decrypted = _decryptReceived(packet);
      if (decrypted != null) out.add(decrypted);
    }
    return out;
  }

  // ─── Internals ───────────────────────────────────────────────────────────

  Uint8List _encryptIfPossible(Uint8List data) {
    final key = _sharedKey;
    if (key == null || data.length <= plaintextHeaderBytes) return data;

    final header = Uint8List.sublistView(data, 0, plaintextHeaderBytes);
    final plaintext = Uint8List.sublistView(data, plaintextHeaderBytes);
    final nonce = _randomNonce();

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), tagBytes * 8, nonce, header),
      );
    final ciphertextWithTag = cipher.process(plaintext);

    final out =
        Uint8List(header.length + nonce.length + ciphertextWithTag.length);
    out.setRange(0, header.length, header);
    out.setRange(header.length, header.length + nonce.length, nonce);
    out.setRange(header.length + nonce.length, out.length, ciphertextWithTag);
    return out;
  }

  ReceivedPacket? _decryptReceived(ReceivedPacket packet) {
    final key = _sharedKey;
    if (key == null) return packet;
    if (packet.data.length < _minEncryptedSize) return null;

    final header = Uint8List.sublistView(packet.data, 0, plaintextHeaderBytes);
    final nonce = Uint8List.sublistView(
        packet.data, plaintextHeaderBytes, plaintextHeaderBytes + nonceBytes);
    final ciphertextWithTag =
        Uint8List.sublistView(packet.data, plaintextHeaderBytes + nonceBytes);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), tagBytes * 8, nonce, header),
      );

    final Uint8List plaintext;
    try {
      plaintext = cipher.process(ciphertextWithTag);
    } on InvalidCipherTextException {
      // Authentication tag check failed — packet was tampered with, truncated,
      // or encrypted under a different key. Drop silently.
      return null;
    }

    final combined = Uint8List(header.length + plaintext.length);
    combined.setRange(0, header.length, header);
    combined.setRange(header.length, combined.length, plaintext);

    return ReceivedPacket(
      data: combined,
      source: packet.source,
      receivedAt: packet.receivedAt,
    );
  }

  Uint8List _randomNonce() {
    final out = Uint8List(nonceBytes);
    for (var i = 0; i < nonceBytes; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }
}
