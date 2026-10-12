// Unit tests for the replication building blocks.
import 'dart:typed_data';

import 'package:fledge_ecs/fledge_ecs.dart';
import 'package:fledge_net/fledge_net.dart';
import 'package:fledge_net/src/replication/wire.dart';
import 'package:test/test.dart';

Uint8List bytes(List<int> b) => Uint8List.fromList(b);

void main() {
  group('varints', () {
    test('round-trip and sizes', () {
      for (final v in [0, 1, 127, 128, 16383, 16384, 0xFFFFFFFF, 1 << 40]) {
        final b = PacketBuilder()..writeVarUint(v);
        final encoded = b.build();
        expect(PacketReader(encoded).readVarUint(), v);
        if (v < 128) expect(encoded.length, 1);
      }
      expect(() => PacketBuilder().writeVarUint(-1), throwsArgumentError);
      expect(
        () => PacketReader(bytes(List.filled(10, 0xFF))).readVarUint(),
        throwsFormatException,
      );
    });

    test('var bytes', () {
      final b = PacketBuilder()
        ..writeVarBytes(bytes([1, 2, 3]))
        ..writeRawBytes(bytes([9]));
      final r = PacketReader(b.build());
      expect(r.readVarBytes(), [1, 2, 3]);
      expect(r.readRawBytes(1), [9]);
      expect(() => r.readRawBytes(1), throwsRangeError);
    });
  });

  group('ReliableChannel', () {
    test('delivers in order, once, despite reordering and duplicates', () {
      final rx = ReliableChannel();
      final tx = ReliableChannel(maxPacketBytes: 20);
      for (var i = 0; i < 5; i++) {
        tx.enqueue(bytes([i]));
      }
      final parts = tx.takePackets(nowMs: 0, resendAfterMs: 100, ack: 0);
      expect(parts.length, greaterThan(1));
      for (final p in [...parts.reversed, ...parts]) {
        rx.receivePacket(p);
      }
      expect(rx.drain().map((m) => m.single), [0, 1, 2, 3, 4]);
      expect(rx.drain(), isEmpty);
      expect(rx.receivedAck, 5);
    });

    test('resends unacked messages after the timeout only', () {
      final tx = ReliableChannel()..enqueue(bytes([1]));
      expect(
        tx.takePackets(nowMs: 0, resendAfterMs: 100, ack: 0),
        hasLength(1),
      );
      expect(tx.takePackets(nowMs: 50, resendAfterMs: 100, ack: 0), isEmpty);
      expect(
        tx.takePackets(nowMs: 100, resendAfterMs: 100, ack: 0),
        hasLength(1),
      );
      tx.onAck(1);
      expect(tx.unackedCount, 0);
      expect(tx.takePackets(nowMs: 500, resendAfterMs: 100, ack: 0), isEmpty);
    });

    test('piggybacks the cumulative ack', () {
      final tx = ReliableChannel()..enqueue(bytes([1]));
      final p = tx.takePackets(nowMs: 0, resendAfterMs: 1, ack: 42).single;
      expect(ReliableChannel().receivePacket(p), 42);
    });

    test('rejects oversized messages', () {
      final ch = ReliableChannel();
      expect(
        () => ch.enqueue(Uint8List(ch.maxMessageBytes + 1)),
        throwsArgumentError,
      );
    });

    test('packets never exceed the payload cap', () {
      final tx = ReliableChannel();
      for (var i = 0; i < 100; i++) {
        tx.enqueue(Uint8List(100));
      }
      final packets = tx.takePackets(nowMs: 0, resendAfterMs: 1, ack: 0);
      expect(packets.length, greaterThan(5));
      expect(packets.every((p) => p.length <= Packet.maxPayloadBytes), isTrue);
    });
  });

  group('TickInputQueue', () {
    test('one input per tick; repeats missing ticks up to the cap', () {
      final q = TickInputQueue<String>()
        ..add(1, 'a', currentTick: 0)
        ..add(3, 'c', currentTick: 0);
      expect(q.take(1), (input: 'a', repeated: false));
      expect(q.take(2), (input: 'a', repeated: true));
      expect(q.take(3), (input: 'c', repeated: false));
      expect(q.take(4, maxRepeat: 1), (input: 'c', repeated: true));
      expect(q.take(5, maxRepeat: 1), isNull);
      expect(q.lastConsumedTick, 4);
    });

    test('drops duplicates, stale and far-future inputs; counts late ones', () {
      final q = TickInputQueue<String>();
      expect(q.add(1, 'a', currentTick: 0), isTrue);
      expect(q.add(1, 'dup', currentTick: 0), isFalse);
      expect(q.add(500, 'x', currentTick: 0), isFalse);
      q.take(1);
      q.take(2); // repeated
      expect(q.add(2, 'late', currentTick: 2), isFalse);
      expect(q.lateCount, 1);
      expect(q.add(1, 'old', currentTick: 2), isFalse);
      expect(q.lateCount, 1, reason: 'tick 1 was a real input');
    });
  });

  group('ClientTickSync', () {
    test('initial sync leads by RTT + buffer', () {
      final s = ClientTickSync(stepMs: 20, bufferTicks: 2)
        ..initialSync(serverTick: 100, rttSampleMs: 100);
      expect(s.synced, isTrue);
      expect(s.localTick, 107); // 100 + 5 + 2
      expect(s.serverTickEstimate, closeTo(102, 1));
      expect(s.consumeJump(), isTrue);
      expect(s.consumeJump(), isFalse);
    });

    test('time dilation corrects small errors, hard reset fixes large', () {
      final s = ClientTickSync(stepMs: 20, bufferTicks: 2)
        ..initialSync(serverTick: 100, rttSampleMs: 100);
      s.consumeJump();
      // The host is 3 ticks further along than expected: speed up.
      for (var i = 0; i < 5; i++) {
        s.observe(serverTick: 101 + i + 3);
        expect(s.step(), greaterThan(0));
      }
      // Way off: snap.
      s.observe(serverTick: 1000);
      expect(s.localTick, 1007);
      expect(s.resets, 1);
      expect(s.consumeJump(), isTrue);
    });

    test('late input reports widen the buffer', () {
      final s = ClientTickSync(stepMs: 20)..reportLateInputs(0);
      expect(s.extraBufferTicks, 0);
      s.reportLateInputs(3);
      s.reportLateInputs(3);
      expect(s.extraBufferTicks, 1);
    });
  });

  group('wire', () {
    test('input packet round-trips', () {
      final p = InputPacket(
        clientTick: 7,
        reliableAck: 3,
        lastSnapshotTick: 5,
        streams: [
          InputStream(2, 6, [
            bytes([1]),
            bytes([2, 3]),
          ]),
        ],
      );
      final d = InputPacket.decode(p.encode());
      expect(d.clientTick, 7);
      expect(d.reliableAck, 3);
      expect(d.lastSnapshotTick, 5);
      expect(d.streams.single.netId, 2);
      expect(d.streams.single.firstTick, 6);
      expect(d.streams.single.inputs, [
        [1],
        [2, 3],
      ]);
    });

    test('entity state round-trips', () {
      final b = PacketBuilder();
      writeEntityState(b, {
        3: bytes([9, 9]),
        0: bytes([1]),
      });
      final s = readEntityState(PacketReader(b.build()));
      expect(s.mask, 0x9);
      expect(s.components[0], [1]);
      expect(s.components[3], [9, 9]);
    });
  });

  group('ReplicationRegistry', () {
    final codec = NetCodec<int>.of(
      encode: (v, o) => o.writeVarUint(v),
      decode: (r) => r.readVarUint(),
    );

    test('schema hash depends on keys and order', () {
      final a = ReplicationRegistry()..component<int>('a', codec);
      final b = ReplicationRegistry()..component<int>('b', codec);
      final a2 = ReplicationRegistry()..component<int>('a', codec);
      expect(a.schemaHash, a2.schemaHash);
      expect(a.schemaHash, isNot(b.schemaHash));
    });

    test('validates registrations and freezes with the plugin', () {
      final r = ReplicationRegistry()..component<int>('a', codec);
      expect(() => r.component<int>('b', codec), throwsArgumentError);
      expect(
        () => r.predict<int, int>(step: (s, i, dt) => s, error: (a, b) => 0),
        throwsStateError,
      );
      NetworkPlugin(replication: r).build(App());
      expect(r.isFrozen, isTrue);
      expect(() => r.rpc<int>('x', codec), throwsStateError);
    });
  });
}
