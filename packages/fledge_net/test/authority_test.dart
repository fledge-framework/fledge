import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  group('NetworkIdentity authority model', () {
    test('isOwnedBy returns true for matching peerId', () {
      final id = NetworkIdentity(netId: 1, ownerId: 5);
      expect(id.isOwnedBy(5), true);
    });

    test('isOwnedBy returns false for non-matching peerId', () {
      final id = NetworkIdentity(netId: 1, ownerId: 5);
      expect(id.isOwnedBy(3), false);
    });

    test('isOwnedBy returns true for host (ownerId 0)', () {
      final id = NetworkIdentity(netId: 1, ownerId: 0);
      expect(id.isOwnedBy(0), true);
      expect(id.isOwnedBy(1), false);
    });

    test('hasAuthority is ownership by the local peer', () {
      // Host (local peer 0).
      expect(NetworkIdentity(netId: 1).hasAuthority, isTrue);
      expect(NetworkIdentity(netId: 1, ownerId: 3).hasAuthority, isFalse);
      // Client 3.
      expect(
        NetworkIdentity(netId: 1, ownerId: 3, localPeerId: 3).hasAuthority,
        isTrue,
      );
      expect(NetworkIdentity(netId: 1, localPeerId: 3).hasAuthority, isFalse);
    });

    test('hasAuthority follows ownerId changes', () {
      final id = NetworkIdentity(netId: 1, ownerId: 3);
      expect(id.hasAuthority, isFalse);
      id.ownerId = 0;
      expect(id.hasAuthority, isTrue);
      expect(id.isOwnedBy(3), isFalse);
    });
  });
}
