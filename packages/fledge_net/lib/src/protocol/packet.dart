import 'dart:typed_data';

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
  static const int version = 1;

  /// Packet type.
  final PacketType type;

  /// Sequence number for ordering/acknowledgment.
  final int sequence;

  /// Acknowledgment of received sequence.
  final int ack;

  /// Bit field of recently acked sequences.
  final int ackBits;

  /// Timestamp for latency calculation.
  final int timestamp;

  PacketHeader({
    required this.type,
    required this.sequence,
    this.ack = 0,
    this.ackBits = 0,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

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
    buffer.setInt32(14, timestamp, Endian.little);
    // 2 bytes reserved at offset 18
    return buffer.buffer.asUint8List();
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
      timestamp: buffer.getInt32(14, Endian.little),
    );
  }
}

/// Complete network packet.
class Packet {
  /// Packet header.
  final PacketHeader header;

  /// Packet payload.
  final Uint8List payload;

  Packet({
    required this.header,
    required this.payload,
  });

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

  /// Write a 32-bit integer.
  void writeInt32(int value) {
    final buffer = ByteData(4)..setInt32(0, value, Endian.little);
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

  /// Write a length-prefixed string.
  void writeString(String value) {
    final bytes = value.codeUnits;
    writeInt16(bytes.length);
    _builder.add(bytes);
  }

  /// Write raw bytes.
  void writeBytes(Uint8List value) {
    writeInt16(value.length);
    _builder.add(value);
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

  /// Read a 32-bit integer.
  int readInt32() {
    final value = _data.getInt32(_offset, Endian.little);
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

  /// Read a length-prefixed string.
  String readString() {
    final length = readInt16();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _data.getUint8(_offset + i);
    }
    _offset += length;
    return String.fromCharCodes(bytes);
  }

  /// Read raw bytes.
  Uint8List readBytes() {
    final length = readInt16();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _data.getUint8(_offset + i);
    }
    _offset += length;
    return bytes;
  }

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
