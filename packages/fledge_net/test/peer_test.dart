import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('Peer', () {
    late Peer peer;

    setUp(() {
      peer = Peer(id: 1, address: const NetAddress('10.0.0.1', 8080));
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

    test('initial rtt is zero', () {
      expect(peer.rtt, 0);
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

    group('RTT', () {
      test('updateRtt sets initial rtt from sample', () {
        expect(peer.updateRtt(1000, nowTimestamp: 1050), isTrue);
        expect(peer.rtt, 50);
      });

      test('updateRtt with the default system clock', () {
        final sent = NetClock.system.nowMs32;
        expect(peer.updateRtt(sent), isTrue);
        expect(peer.rtt, inInclusiveRange(1, 50));
      });

      test('updateRtt uses exponential moving average after first', () {
        peer.rtt = 100;
        peer.updateRtt(1000, nowTimestamp: 1050);
        // 0.9 * 100 + 0.1 * 50 = 95
        expect(peer.rtt, closeTo(95, 1e-9));
      });

      test('updateRtt is wrap-safe across the 32-bit boundary', () {
        expect(peer.updateRtt(0xFFFFFFF6, nowTimestamp: 30), isTrue);
        expect(peer.rtt, 40);
      });

      test('updateRtt ignores future and absurd samples', () {
        peer.rtt = 80;
        expect(peer.updateRtt(2000, nowTimestamp: 1000), isFalse);
        expect(
          peer.updateRtt(0, nowTimestamp: Peer.maxRttSampleMs + 1),
          isFalse,
        );
        expect(peer.rtt, 80);
      });
    });
  });
}
