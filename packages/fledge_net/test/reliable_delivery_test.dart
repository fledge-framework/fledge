import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('PacketType.isReliable', () {
    test('returns true for reliable packet types', () {
      expect(PacketType.connect.isReliable, true);
      expect(PacketType.connectAccepted.isReliable, true);
      expect(PacketType.connectRejected.isReliable, true);
      expect(PacketType.disconnect.isReliable, true);
      expect(PacketType.entitySpawn.isReliable, true);
      expect(PacketType.entityDespawn.isReliable, true);
      expect(PacketType.rpc.isReliable, true);
    });

    test('returns false for unreliable packet types', () {
      expect(PacketType.stateUpdate.isReliable, false);
      expect(PacketType.input.isReliable, false);
      expect(PacketType.ping.isReliable, false);
      expect(PacketType.pong.isReliable, false);
      expect(PacketType.custom.isReliable, false);
    });
  });

  group('Peer reliable delivery', () {
    late Peer peer;

    setUp(() {
      peer = Peer(
        id: 1,
        address: const NetAddress('10.0.0.1', 8080),
      );
    });

    test('maxRetransmits is 10', () {
      expect(Peer.maxRetransmits, 10);
    });

    test('getPacketsToRetransmit drops packets after max retransmits', () {
      peer.addPendingReliable(1, Uint8List.fromList([1, 2, 3]));

      // Use a 1ms timeout and add a tiny delay between calls to ensure
      // the elapsed time exceeds the timeout threshold.
      for (var i = 0; i < Peer.maxRetransmits + 2; i++) {
        // Busy-wait to ensure time advances at least 1ms
        final start = DateTime.now();
        while (DateTime.now().difference(start).inMicroseconds < 1100) {
          // spin
        }
        peer.getPacketsToRetransmit(const Duration(milliseconds: 1));
      }

      expect(peer.droppedReliableCount, greaterThanOrEqualTo(1));
    });

    test('processAck removes acknowledged packets', () {
      peer.addPendingReliable(1, Uint8List.fromList([10]));
      peer.addPendingReliable(2, Uint8List.fromList([20]));
      peer.addPendingReliable(3, Uint8List.fromList([30]));

      // Ack sequence 2 directly.
      peer.processAck(2, 0);

      // Ack sequence 1 via ack bits: ack=3, diff for seq 1 = 2,
      // bit = 1 << (2-1) = 0x02.
      // Also directly acks sequence 3.
      peer.processAck(3, 0x02);

      // All packets should be removed. Verify by checking that
      // no retransmits are needed even with a zero timeout.
      // First we need to wait so they'd be eligible, but since they
      // were removed, we get nothing.
      final retransmits = peer.getPacketsToRetransmit(Duration.zero);
      expect(retransmits, isEmpty);
    });
  });
}
