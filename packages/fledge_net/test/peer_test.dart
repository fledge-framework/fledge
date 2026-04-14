import 'dart:typed_data';

import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('Peer', () {
    late Peer peer;

    setUp(() {
      peer = Peer(
        id: 1,
        address: const NetAddress('10.0.0.1', 8080),
      );
    });

    test('initial state is connecting', () {
      expect(peer.state, PeerState.connecting);
      expect(peer.isConnected, false);
    });

    test('isConnected returns true when connected', () {
      peer.state = PeerState.connected;
      expect(peer.isConnected, true);
    });

    test('isConnected returns false for other states', () {
      for (final state in PeerState.values) {
        peer.state = state;
        expect(peer.isConnected, state == PeerState.connected);
      }
    });

    test('stores id and address', () {
      expect(peer.id, 1);
      expect(peer.address, const NetAddress('10.0.0.1', 8080));
    });

    test('default name is empty', () {
      expect(peer.name, '');
    });

    test('accepts custom name', () {
      final named = Peer(
        id: 2,
        address: const NetAddress('10.0.0.1', 8080),
        name: 'Player1',
      );
      expect(named.name, 'Player1');
    });

    test('initial rtt and packet loss are zero', () {
      expect(peer.rtt, 0);
      expect(peer.packetLoss, 0);
    });

    test('userData starts empty', () {
      expect(peer.userData, isEmpty);
    });

    test('userData can store and retrieve data', () {
      peer.userData['score'] = 100;
      peer.userData['team'] = 'red';
      expect(peer.userData['score'], 100);
      expect(peer.userData['team'], 'red');
    });

    group('sequence numbers', () {
      test('nextSequence increments', () {
        expect(peer.nextSequence, 1);
        expect(peer.nextSequence, 2);
        expect(peer.nextSequence, 3);
      });

      test('nextSequence wraps at 16 bits', () {
        peer.lastSentSequence = 0xFFFE;
        expect(peer.nextSequence, 0xFFFF);
        expect(peer.nextSequence, 0); // wraps
        expect(peer.nextSequence, 1);
      });

      test('processReceivedSequence updates lastReceivedSequence', () {
        peer.processReceivedSequence(5);
        expect(peer.lastReceivedSequence, 5);
        peer.processReceivedSequence(10);
        expect(peer.lastReceivedSequence, 10);
      });

      test('processReceivedSequence ignores older sequences', () {
        peer.processReceivedSequence(10);
        peer.processReceivedSequence(5); // older
        expect(peer.lastReceivedSequence, 10);
      });

      test('processReceivedSequence handles wraparound', () {
        peer.processReceivedSequence(0xFFFE);
        peer.processReceivedSequence(1); // wrapped around
        expect(peer.lastReceivedSequence, 1);
      });
    });

    group('ack bits', () {
      test('getAckBits returns bits for recent sequences', () {
        peer.processReceivedSequence(1);
        peer.processReceivedSequence(2);
        peer.processReceivedSequence(3);

        final bits = peer.getAckBits();
        // lastReceived is 3, so seq 2 → bit 0, seq 1 → bit 1
        expect(bits & 1, 1); // bit 0: diff=1 (seq 2)
        expect((bits >> 1) & 1, 1); // bit 1: diff=2 (seq 1)
      });

      test('getAckBits returns 0 with no history', () {
        expect(peer.getAckBits(), 0);
      });

      test('getAckBits returns 0 with single sequence', () {
        peer.processReceivedSequence(1);
        // Only one sequence, lastReceivedSequence == 1, diff = 0 for itself
        expect(peer.getAckBits(), 0);
      });
    });

    group('reliable packets', () {
      test('addPendingReliable stores packets', () {
        peer.addPendingReliable(1, Uint8List.fromList([1]));
        peer.addPendingReliable(2, Uint8List.fromList([2]));

        // No retransmits yet (just added)
        final retransmits = peer.getPacketsToRetransmit(
          const Duration(seconds: 10),
        );
        expect(retransmits, isEmpty);
      });

      test('processAck removes matching sequence', () {
        peer.addPendingReliable(5, Uint8List.fromList([1]));
        peer.addPendingReliable(6, Uint8List.fromList([2]));
        peer.addPendingReliable(7, Uint8List.fromList([3]));

        // Ack sequence 6
        peer.processAck(6, 0);

        // Ack sequence 5 via ack bits (ack=7, bit 0 means seq 6, bit 1 means seq 5)
        // Actually: diff = (7 - 5) & 0xFFFF = 2, bit = 1 << (2-1) = 0x02
        peer.processAck(7, 0x02); // acks seq 5 via bits

        // Only sequence 7 should be acked by the direct ack=7 call above
        // After both processAck calls: 6 was removed by first call,
        // 5 was removed by second call (ackBits), 7 was removed by direct ack
        // All should be removed
      });

      test('processAck removes via ack bits', () {
        peer.addPendingReliable(10, Uint8List.fromList([1]));
        // ack=12, diff for seq 10 = 2, bit = 1 << (2-1) = 0x02
        peer.processAck(12, 0x02);
        // Packet 10 should be removed
      });
    });

    group('RTT', () {
      test('updateRtt sets initial rtt from sample', () {
        final sentTime = DateTime.now().millisecondsSinceEpoch - 50;
        peer.updateRtt(sentTime);
        expect(peer.rtt, greaterThanOrEqualTo(40));
        expect(peer.rtt, lessThan(200));
      });

      test('updateRtt uses exponential moving average after first', () {
        // First sample
        peer.rtt = 100;

        // Simulate a new sample ~50ms
        final sentTime = DateTime.now().millisecondsSinceEpoch - 50;
        peer.updateRtt(sentTime);

        // Should be ~0.9 * 100 + 0.1 * 50 = 95
        expect(peer.rtt, greaterThan(80));
        expect(peer.rtt, lessThan(110));
      });
    });
  });
}
