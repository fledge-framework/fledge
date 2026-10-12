import 'dart:convert';
import 'dart:typed_data';

import 'net_clock.dart';

/// Packet type identifiers.
enum PacketType {
  /// Connection request from client to host.
  connect(0x01),

  /// Connection accepted response.
  connectAccepted(0x02),

  /// Connection rejected response.
  connectRejected(0x03),

  /// Disconnect notification.
  disconnect(0x04),

  /// Ping for latency measurement.
  ping(0x05),

  /// Pong response to ping.
  pong(0x06),

  /// Entity state update.
  stateUpdate(0x10),

  /// Input data from client.
  input(0x11),

  /// Entity spawn notification.
  entitySpawn(0x12),

  /// Entity despawn notification.
  entityDespawn(0x13),

  /// Ordered reliable replication channel (both directions).
  ///
  /// Carries the replication layer's ordered reliable messages (welcome,
  /// spawn, despawn, re-parent, ownership, RPC). Reliability, ordering
  /// and de-duplication are implemented by `ReliableChannel` with
  /// cumulative acks, so this type is *unreliable* at the `Peer` level
  /// (see [isReliable]).
  replication(0x14),

  /// Tick synchronisation handshake (unreliable request/response).
  tickSync(0x15),

  /// RPC (remote procedure call).
  rpc(0x20),

  /// Custom game message.
  custom(0xFF);

  final int value;
  const PacketType(this.value);

  /// Whether this packet type requires reliable delivery.
  ///
  /// Reliable packets are retransmitted until acknowledged.
  /// State updates and input are unreliable (sent frequently, latest-wins).
  bool get isReliable => switch (this) {
    connect || connectAccepted || connectRejected || disconnect => true,
    entitySpawn || entityDespawn || rpc => true,
    _ => false,
  };

  static PacketType? fromValue(int value) {
    for (final type in PacketType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Reliability level for packets.
enum Reliability {
  /// Best effort, may be lost (default for state updates).
  unreliable,

  /// Guaranteed delivery but unordered.
  reliable,

  /// Guaranteed delivery and ordering.
  reliableOrdered,
}

/// Network packet header.
class PacketHeader {
  /// Protocol magic number.
  static const int magic = 0x464C4547; // "FLEG"

  /// Protocol version.
  ///
  /// History:
  /// - **2**: 2D transform state wire format (see `Transform2DNetworkState`).
  /// - **3**: header [timestamp] became an unsigned 32-bit wrapping
  ///   monotonic clock value (was a truncated signed epoch-ms value);
  ///   ping/pong payloads carry a uint32 [NetClock] timestamp that the pong
  ///   echoes back; strings are UTF-8 with a uint16 byte-length prefix
  ///   (were UTF-16 code units truncated to bytes). The replication layer
  ///   (unreleased alongside the above, so it shares version 3) adds
  ///   [PacketType.replication] (0x14) and [PacketType.tickSync] (0x15)
  ///   and defines payload formats for [PacketType.stateUpdate] (snapshot
  ///   chunks) and [PacketType.input] (redundant per-tick inputs); see
  ///   `lib/src/replication/wire.dart`.
  ///
  /// Peers running another version cannot parse each other's packets;
  /// [deserialize] returns `null` on a version mismatch. [peekVersion] lets
  /// the receiver still recognise a protocol-shaped packet (magic match,
  /// version mismatch) so it can surface a clear "protocol version
  /// mismatch" error. `NetworkHost` answers a mismatched `connect` with a
  /// `connectRejected` and `NetworkClient` fails its connect with the same
  /// reason; both also emit a `ProtocolMismatchEvent`.
  static const int version = 3;

  /// Packet type.
  final PacketType type;

  /// Sequence number for ordering/acknowledgment.
  final int sequence;

  /// Acknowledgment of received sequence.
  final int ack;

  /// Bit field of recently acked sequences.
  final int ackBits;

  /// Sender-local send time: a 32-bit wrapping [NetClock] value in ms.
  ///
  /// Only meaningful to the sender's own clock — never compare it against
  /// the receiver's clock. RTT is measured with ping/pong echoes instead.
  final int timestamp;

  PacketHeader({
    required this.type,
    required this.sequence,
    this.ack = 0,
    this.ackBits = 0,
    int? timestamp,
  }) : timestamp = NetClock.wrap32(timestamp ?? NetClock.system.nowMs32);

  /// Header size in bytes.
  static const int size = 20;

  /// Serialize header to bytes.
  Uint8List serialize() {
    final buffer = ByteData(size);
    buffer.setUint32(0, magic, Endian.little);
    buffer.setUint8(4, version);
    buffer.setUint8(5, type.value);
    buffer.setUint16(6, sequence, Endian.little);
    buffer.setUint16(8, ack, Endian.little);
    buffer.setUint32(10, ackBits, Endian.little);
    buffer.setUint32(14, timestamp, Endian.little);
    // 2 bytes reserved at offset 18
    return buffer.buffer.asUint8List();
  }

  /// Returns the protocol version byte in [data] if it starts with the
  /// protocol [magic] number, or `null` otherwise.
  ///
  /// Callers use this after [deserialize] returns `null` to distinguish
  /// "not our protocol at all" from "our protocol, wrong version" so the
  /// latter can be surfaced as a clean version-mismatch error rather than
  /// a silent drop-and-timeout.
  static int? peekVersion(Uint8List data) {
    if (data.length < 5) return null;
    final buffer = ByteData.sublistView(data);
    if (buffer.getUint32(0, Endian.little) != magic) return null;
    return buffer.getUint8(4);
  }

  /// Deserialize header from bytes.
  static PacketHeader? deserialize(Uint8List data) {
    if (data.length < size) return null;

    final buffer = ByteData.sublistView(data);

    // Verify magic number
    if (buffer.getUint32(0, Endian.little) != magic) return null;

    // Verify version
    if (buffer.getUint8(4) != version) return null;

    final typeValue = buffer.getUint8(5);
    final type = PacketType.fromValue(typeValue);
    if (type == null) return null;

    return PacketHeader(
      type: type,
      sequence: buffer.getUint16(6, Endian.little),
      ack: buffer.getUint16(8, Endian.little),
      ackBits: buffer.getUint32(10, Endian.little),
      timestamp: buffer.getUint32(14, Endian.little),
    );
  }
}

/// Complete network packet.
class Packet {
  /// Packet header.
  final PacketHeader header;

  /// Packet payload.
  final Uint8List payload;

  Packet({required this.header, required this.payload});

  /// Create a packet from raw bytes.
  static Packet? fromBytes(Uint8List data) {
    final header = PacketHeader.deserialize(data);
    if (header == null) return null;

    final payload = data.sublist(PacketHeader.size);
    return Packet(header: header, payload: payload);
  }

  /// Serialize packet to bytes.
  Uint8List toBytes() {
    final headerBytes = header.serialize();
    final result = Uint8List(headerBytes.length + payload.length);
    result.setRange(0, headerBytes.length, headerBytes);
    result.setRange(headerBytes.length, result.length, payload);
    return result;
  }

  /// Total size in bytes.
  int get size => PacketHeader.size + payload.length;

  /// Largest datagram fledge_net will put on the wire, in bytes.
  ///
  /// 1200 bytes stays under the minimum IPv6 MTU (1280) and common
  /// tunnel/VPN MTUs once IP/UDP headers are added, so packets are never
  /// fragmented by the IP layer (a fragmented datagram is lost if any
  /// fragment is lost).
  static const int maxDatagramBytes = 1200;

  /// Bytes reserved for `EncryptedTransport` (12-byte nonce + 16-byte tag).
  ///
  /// Reserved whether or not encryption is enabled, so a payload that fits
  /// unencrypted also fits encrypted.
  static const int encryptionOverheadBytes = 28;

  /// Largest application payload accepted by `NetworkHost` /
  /// `NetworkClient` send methods: [maxDatagramBytes] minus the
  /// [PacketHeader.size] header and [encryptionOverheadBytes]
  /// (currently 1152 bytes). Larger sends throw [ArgumentError]; split
  /// the data yourself until fragmentation support lands.
  static const int maxPayloadBytes =
      maxDatagramBytes - PacketHeader.size - encryptionOverheadBytes;

  /// Throws [ArgumentError] if [payload] exceeds [maxPayloadBytes].
  static void checkPayloadSize(Uint8List payload) {
    if (payload.length > maxPayloadBytes) {
      throw ArgumentError.value(
        payload.length,
        'payload.length',
        'Payload is ${payload.length} bytes; the maximum is $maxPayloadBytes '
            'bytes ($maxDatagramBytes-byte datagram minus '
            '${PacketHeader.size}-byte header and $encryptionOverheadBytes '
            'bytes of encryption overhead). Split the data across several '
            'packets',
      );
    }
  }
}

/// Packet builder for constructing payloads.
class PacketBuilder {
  final BytesBuilder _builder = BytesBuilder();

  /// Current size of the payload.
  int get size => _builder.length;

  /// Write a boolean.
  void writeBool(bool value) {
    _builder.addByte(value ? 1 : 0);
  }

  /// Write a single byte.
  void writeByte(int value) {
    _builder.addByte(value);
  }

  /// Write a 16-bit integer.
  void writeInt16(int value) {
    final buffer = ByteData(2)..setInt16(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Write an unsigned 16-bit integer (`0..65535`).
  void writeUint16(int value) {
    final buffer = ByteData(2)..setUint16(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Write a 32-bit integer.
  void writeInt32(int value) {
    final buffer = ByteData(4)..setInt32(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Write an unsigned 32-bit integer (`0..0xFFFFFFFF`).
  void writeUint32(int value) {
    final buffer = ByteData(4)..setUint32(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Write a 64-bit integer.
  void writeInt64(int value) {
    final buffer = ByteData(8)..setInt64(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Write a 32-bit float.
  void writeFloat32(double value) {
    final buffer = ByteData(4)..setFloat32(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Write a 64-bit float.
  void writeFloat64(double value) {
    final buffer = ByteData(8)..setFloat64(0, value, Endian.little);
    _builder.add(buffer.buffer.asUint8List());
  }

  /// Maximum encoded length of [writeString] / [writeBytes] data in bytes.
  static const int maxLengthPrefixed = 0xFFFF;

  /// Write a string as UTF-8, prefixed with its byte length (uint16).
  ///
  /// Throws [ArgumentError] if the UTF-8 encoding exceeds
  /// [maxLengthPrefixed] bytes.
  void writeString(String value) {
    final bytes = utf8.encode(value);
    _writeLengthPrefixed(bytes, 'value');
  }

  /// Write raw bytes, prefixed with their length (uint16).
  ///
  /// Throws [ArgumentError] if [value] exceeds [maxLengthPrefixed] bytes.
  void writeBytes(Uint8List value) {
    _writeLengthPrefixed(value, 'value');
  }

  void _writeLengthPrefixed(List<int> bytes, String name) {
    if (bytes.length > maxLengthPrefixed) {
      throw ArgumentError.value(
        bytes.length,
        name,
        'encoded length exceeds $maxLengthPrefixed bytes',
      );
    }
    writeUint16(bytes.length);
    _builder.add(bytes);
  }

  /// Write a non-negative integer as an unsigned LEB128 varint
  /// (1 byte for values below 128, 2 below 16384, ...).
  ///
  /// Throws [ArgumentError] for negative values.
  void writeVarUint(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'must not be negative');
    }
    var v = value;
    while (v >= 0x80) {
      _builder.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    _builder.addByte(v);
  }

  /// Write raw bytes with no length prefix.
  void writeRawBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  /// Write bytes prefixed with their length as a varint (see
  /// [writeVarUint]). Unlike [writeBytes] there is no 64 KiB limit.
  void writeVarBytes(List<int> bytes) {
    writeVarUint(bytes.length);
    _builder.add(bytes);
  }

  /// Write a 3D vector (3 floats).
  void writeVector3(double x, double y, double z) {
    writeFloat32(x);
    writeFloat32(y);
    writeFloat32(z);
  }

  /// Write a quaternion (4 floats).
  void writeQuaternion(double x, double y, double z, double w) {
    writeFloat32(x);
    writeFloat32(y);
    writeFloat32(z);
    writeFloat32(w);
  }

  /// Build the payload.
  Uint8List build() {
    return _builder.toBytes();
  }

  /// Clear the builder.
  void clear() {
    _builder.clear();
  }
}

/// Packet reader for parsing payloads.
class PacketReader {
  final ByteData _data;
  int _offset = 0;

  PacketReader(Uint8List data) : _data = ByteData.sublistView(data);

  /// Remaining bytes to read.
  int get remaining => _data.lengthInBytes - _offset;

  /// Whether there are more bytes to read.
  bool get hasMore => _offset < _data.lengthInBytes;

  /// Read a boolean.
  bool readBool() {
    return readByte() != 0;
  }

  /// Read a single byte.
  int readByte() {
    final value = _data.getUint8(_offset);
    _offset += 1;
    return value;
  }

  /// Read a 16-bit integer.
  int readInt16() {
    final value = _data.getInt16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  /// Read an unsigned 16-bit integer.
  int readUint16() {
    final value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  /// Read a 32-bit integer.
  int readInt32() {
    final value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  /// Read an unsigned 32-bit integer.
  int readUint32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  /// Read a 64-bit integer.
  int readInt64() {
    final value = _data.getInt64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  /// Read a 32-bit float.
  double readFloat32() {
    final value = _data.getFloat32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  /// Read a 64-bit float.
  double readFloat64() {
    final value = _data.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  /// Read a UTF-8 string written by [PacketBuilder.writeString].
  ///
  /// Throws [FormatException] on malformed UTF-8 and [RangeError] if the
  /// declared length runs past the end of the data.
  String readString() => utf8.decode(_readLengthPrefixed());

  /// Read raw bytes written by [PacketBuilder.writeBytes].
  ///
  /// Throws [RangeError] if the declared length runs past the end of the
  /// data.
  Uint8List readBytes() => Uint8List.fromList(_readLengthPrefixed());

  Uint8List _readLengthPrefixed() {
    final length = readUint16();
    if (length > remaining) {
      throw RangeError(
        'Length prefix $length exceeds remaining $remaining bytes',
      );
    }
    final bytes = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return bytes;
  }

  /// Read an unsigned LEB128 varint written by
  /// [PacketBuilder.writeVarUint].
  ///
  /// Throws [FormatException] if the varint is longer than 9 bytes and
  /// [RangeError] if it runs past the end of the data.
  int readVarUint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (shift > 56) throw const FormatException('varint too long');
      final byte = readByte();
      result |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return result;
      shift += 7;
    }
  }

  /// Read [length] raw bytes (a view; copy it if you keep it).
  ///
  /// Throws [RangeError] if fewer than [length] bytes remain.
  Uint8List readRawBytes(int length) {
    if (length < 0 || length > remaining) {
      throw RangeError(
        'Requested $length bytes but only $remaining bytes remain',
      );
    }
    final bytes = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return bytes;
  }

  /// Read bytes written by [PacketBuilder.writeVarBytes] (a copy).
  Uint8List readVarBytes() => Uint8List.fromList(readRawBytes(readVarUint()));

  /// Read a 3D vector (3 floats).
  (double, double, double) readVector3() {
    return (readFloat32(), readFloat32(), readFloat32());
  }

  /// Read a quaternion (4 floats).
  (double, double, double, double) readQuaternion() {
    return (readFloat32(), readFloat32(), readFloat32(), readFloat32());
  }

  /// Skip a number of bytes.
  void skip(int bytes) {
    _offset += bytes;
  }
}
