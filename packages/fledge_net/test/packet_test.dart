import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('PacketType', () {
    test('fromValue returns correct type', () {
      expect(PacketType.fromValue(0x01), PacketType.connect);
      expect(PacketType.fromValue(0x06), PacketType.pong);
      expect(PacketType.fromValue(0x10), PacketType.stateUpdate);
      expect(PacketType.fromValue(0xFF), PacketType.custom);
    });

    test('fromValue returns null for unknown value', () {
      expect(PacketType.fromValue(0x00), isNull);
      expect(PacketType.fromValue(0x99), isNull);
    });

    test('all types have distinct values', () {
      final values = PacketType.values.map((t) => t.value).toSet();
      expect(values.length, PacketType.values.length);
    });
  });

  group('PacketHeader', () {
    test('serializes and deserializes roundtrip', () {
      final header = PacketHeader(
        type: PacketType.stateUpdate,
        sequence: 42,
        ack: 10,
        ackBits: 0xFF00FF,
        timestamp: 1234567,
      );

      final bytes = header.serialize();
      expect(bytes.length, PacketHeader.size);

      final deserialized = PacketHeader.deserialize(bytes);
      expect(deserialized, isNotNull);
      expect(deserialized!.type, PacketType.stateUpdate);
      expect(deserialized.sequence, 42);
      expect(deserialized.ack, 10);
      expect(deserialized.ackBits, 0xFF00FF);
      expect(deserialized.timestamp, 1234567);
    });

    test('returns null for data too short', () {
      expect(PacketHeader.deserialize(Uint8List(10)), isNull);
      expect(PacketHeader.deserialize(Uint8List(0)), isNull);
    });

    test('returns null for wrong magic number', () {
      final bytes = Uint8List(PacketHeader.size);
      // Write wrong magic
      final bd = ByteData.sublistView(bytes);
      bd.setUint32(0, 0xDEADBEEF, Endian.little);
      expect(PacketHeader.deserialize(bytes), isNull);
    });

    test('returns null for wrong version', () {
      final header = PacketHeader(
        type: PacketType.ping,
        sequence: 0,
        timestamp: 0,
      );
      final bytes = header.serialize();
      // Corrupt version byte
      bytes[4] = 99;
      expect(PacketHeader.deserialize(bytes), isNull);
    });

    test('returns null for unknown packet type', () {
      final header = PacketHeader(
        type: PacketType.ping,
        sequence: 0,
        timestamp: 0,
      );
      final bytes = header.serialize();
      // Set to unknown type value
      bytes[5] = 0x99;
      expect(PacketHeader.deserialize(bytes), isNull);
    });

    test('size constant is 20 bytes', () {
      expect(PacketHeader.size, 20);
    });

    test('magic constant is FLEG', () {
      expect(PacketHeader.magic, 0x464C4547);
    });

    test('preserves max sequence number', () {
      final header = PacketHeader(
        type: PacketType.ping,
        sequence: 0xFFFF,
        ack: 0xFFFF,
        ackBits: 0xFFFFFFFF,
        timestamp: 0,
      );

      final bytes = header.serialize();
      final deserialized = PacketHeader.deserialize(bytes)!;
      expect(deserialized.sequence, 0xFFFF);
      expect(deserialized.ack, 0xFFFF);
      expect(deserialized.ackBits, 0xFFFFFFFF);
    });
  });

  group('Packet', () {
    test('toBytes and fromBytes roundtrip', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final packet = Packet(
        header: PacketHeader(
          type: PacketType.input,
          sequence: 7,
          timestamp: 999,
        ),
        payload: payload,
      );

      final bytes = packet.toBytes();
      final restored = Packet.fromBytes(bytes);
      expect(restored, isNotNull);
      expect(restored!.header.type, PacketType.input);
      expect(restored.header.sequence, 7);
      expect(restored.payload, payload);
    });

    test('fromBytes returns null for invalid data', () {
      expect(Packet.fromBytes(Uint8List(5)), isNull);
    });

    test('handles empty payload', () {
      final packet = Packet(
        header: PacketHeader(
          type: PacketType.ping,
          sequence: 0,
          timestamp: 0,
        ),
        payload: Uint8List(0),
      );

      final bytes = packet.toBytes();
      final restored = Packet.fromBytes(bytes)!;
      expect(restored.payload, isEmpty);
    });

    test('size includes header and payload', () {
      final payload = Uint8List(100);
      final packet = Packet(
        header: PacketHeader(
          type: PacketType.stateUpdate,
          sequence: 0,
          timestamp: 0,
        ),
        payload: payload,
      );
      expect(packet.size, PacketHeader.size + 100);
    });
  });

  group('PacketBuilder and PacketReader', () {
    test('bool roundtrip', () {
      final builder = PacketBuilder()
        ..writeBool(true)
        ..writeBool(false);
      final reader = PacketReader(builder.build());
      expect(reader.readBool(), true);
      expect(reader.readBool(), false);
    });

    test('byte roundtrip', () {
      final builder = PacketBuilder()
        ..writeByte(0)
        ..writeByte(255)
        ..writeByte(128);
      final reader = PacketReader(builder.build());
      expect(reader.readByte(), 0);
      expect(reader.readByte(), 255);
      expect(reader.readByte(), 128);
    });

    test('int16 roundtrip', () {
      final builder = PacketBuilder()
        ..writeInt16(0)
        ..writeInt16(32767)
        ..writeInt16(-32768);
      final reader = PacketReader(builder.build());
      expect(reader.readInt16(), 0);
      expect(reader.readInt16(), 32767);
      expect(reader.readInt16(), -32768);
    });

    test('int32 roundtrip', () {
      final builder = PacketBuilder()
        ..writeInt32(0)
        ..writeInt32(2147483647)
        ..writeInt32(-2147483648);
      final reader = PacketReader(builder.build());
      expect(reader.readInt32(), 0);
      expect(reader.readInt32(), 2147483647);
      expect(reader.readInt32(), -2147483648);
    });

    test('int64 roundtrip', () {
      final builder = PacketBuilder()
        ..writeInt64(0)
        ..writeInt64(9223372036854775807);
      final reader = PacketReader(builder.build());
      expect(reader.readInt64(), 0);
      expect(reader.readInt64(), 9223372036854775807);
    });

    test('float32 roundtrip', () {
      final builder = PacketBuilder()
        ..writeFloat32(0.0)
        ..writeFloat32(1.5)
        ..writeFloat32(-3.14);
      final reader = PacketReader(builder.build());
      expect(reader.readFloat32(), 0.0);
      expect(reader.readFloat32(), closeTo(1.5, 0.001));
      expect(reader.readFloat32(), closeTo(-3.14, 0.01));
    });

    test('float64 roundtrip', () {
      final builder = PacketBuilder()
        ..writeFloat64(3.141592653589793)
        ..writeFloat64(-1e-10);
      final reader = PacketReader(builder.build());
      expect(reader.readFloat64(), 3.141592653589793);
      expect(reader.readFloat64(), -1e-10);
    });

    test('string roundtrip', () {
      final builder = PacketBuilder()
        ..writeString('hello')
        ..writeString('')
        ..writeString('world');
      final reader = PacketReader(builder.build());
      expect(reader.readString(), 'hello');
      expect(reader.readString(), '');
      expect(reader.readString(), 'world');
    });

    test('bytes roundtrip', () {
      final data = Uint8List.fromList([10, 20, 30]);
      final builder = PacketBuilder()
        ..writeBytes(data)
        ..writeBytes(Uint8List(0));
      final reader = PacketReader(builder.build());
      expect(reader.readBytes(), data);
      expect(reader.readBytes(), isEmpty);
    });

    test('vector3 roundtrip', () {
      final builder = PacketBuilder()..writeVector3(1.0, 2.0, 3.0);
      final reader = PacketReader(builder.build());
      final (x, y, z) = reader.readVector3();
      expect(x, closeTo(1.0, 0.001));
      expect(y, closeTo(2.0, 0.001));
      expect(z, closeTo(3.0, 0.001));
    });

    test('quaternion roundtrip', () {
      final builder = PacketBuilder()..writeQuaternion(0.0, 0.0, 0.0, 1.0);
      final reader = PacketReader(builder.build());
      final (x, y, z, w) = reader.readQuaternion();
      expect(x, closeTo(0.0, 0.001));
      expect(y, closeTo(0.0, 0.001));
      expect(z, closeTo(0.0, 0.001));
      expect(w, closeTo(1.0, 0.001));
    });

    test('mixed types roundtrip', () {
      final builder = PacketBuilder()
        ..writeBool(true)
        ..writeInt32(42)
        ..writeString('test')
        ..writeFloat32(1.5)
        ..writeByte(7);
      final reader = PacketReader(builder.build());
      expect(reader.readBool(), true);
      expect(reader.readInt32(), 42);
      expect(reader.readString(), 'test');
      expect(reader.readFloat32(), closeTo(1.5, 0.001));
      expect(reader.readByte(), 7);
      expect(reader.hasMore, false);
    });

    test('remaining tracks bytes left', () {
      final builder = PacketBuilder()
        ..writeInt32(1)
        ..writeInt32(2);
      final reader = PacketReader(builder.build());
      expect(reader.remaining, 8);
      reader.readInt32();
      expect(reader.remaining, 4);
      reader.readInt32();
      expect(reader.remaining, 0);
      expect(reader.hasMore, false);
    });

    test('skip advances offset', () {
      final builder = PacketBuilder()
        ..writeInt32(1)
        ..writeInt32(42)
        ..writeInt32(3);
      final reader = PacketReader(builder.build());
      reader.skip(4); // skip first int32
      expect(reader.readInt32(), 42);
    });

    test('builder size tracks payload size', () {
      final builder = PacketBuilder();
      expect(builder.size, 0);
      builder.writeInt32(1);
      expect(builder.size, 4);
      builder.writeString('hi');
      expect(builder.size, 4 + 2 + 2); // int32 + length prefix + 2 chars
    });

    test('builder clear resets state', () {
      final builder = PacketBuilder()..writeInt32(1);
      expect(builder.size, 4);
      builder.clear();
      expect(builder.size, 0);
    });
  });
}
